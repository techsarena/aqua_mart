# Wiring the app to the ERPNext backend

The Flutter client and the Frappe app in
`frappe-bench-v16/apps/aqua_mart` implement the same `API_SPEC.md`. This
documents what connects them and the handful of places where the running
backend, not the spec, is authoritative.

## Running against the live API

```bash
flutter run \
  --dart-define=AQUA_API_BASE_URL=http://localhost:8001/v1 \
  --dart-define=AQUA_SOCKET_URL=http://localhost:9001 \
  --dart-define=AQUA_SITE_NAME=aqua.mart
```

Defaults live in [api_environment.dart](../lib/core/network/api_environment.dart)
and match a local bench (`webserver_port` 8001, `socketio_port` 9001, site
`aqua.mart` — all from `sites/common_site_config.json`). Point them at the
real host for staging or production.

The app is **API-only** — there are no mock data sources and no
`USE_MOCK_DATA` switch. Every screen talks to the backend, so a reachable API
is required to run it at all.

`/v1/*` is served from a `before_request` hook straight off the site root, so
**the nginx rewrite in §1.1 is optional** and `AQUA_API_BASE_URL` carries the
`/v1` prefix directly. There is no `/api/method/...` in any client path.

## The response envelope

Success is `{"data": ...}`, errors are `{"message": ..., "code": ..., "errors": ...}`
(§1.2/1.3). Unwrapping happens once, in `ApiClient` — `getObject`, `getList`,
`postObject`, `putObject`, `patchObject` — rather than in each data source.

Two deliberate exceptions, both in auth (§4.2), where the keys sit at the
**top level** and are read directly:

| Endpoint | Top-level keys |
| --- | --- |
| `POST /auth/otp/verify` | `access_token`, `refresh_token`, `user` |
| `POST /auth/refresh` | `access_token`, `refresh_token` |

Many endpoints answer `204` with an empty body. `ApiClient` treats a null body
as success when the requested type is nullable, and only as a `ParseFailure`
when it is not.

`GET /rider/seller-codes/{code}` answers `data: null` for a code that matches
nothing — a miss, not an error, so it maps to a null result rather than a throw.

## Sockets

The transport is Frappe's own Socket.IO server. Its auth middleware
(`frappe/realtime/middlewares/authenticate.js`) is stricter than §8.2 implies,
and all three of these are hard rejections:

1. **The namespace is the site name.** Connect to `/{siteName}`, not `/`.
   A mismatch fails with `Invalid namespace`.
2. **The token goes in the `Authorization` header**, *not* in `auth: {token}`
   as §8.2 shows. The middleware forwards that header to
   `frappe.realtime.get_user_info` to resolve the user; a token supplied only
   in the auth payload never reaches it and the socket resolves to Guest.
3. **`Origin` must be an origin that serves the site.** This is not a CORS
   formality: the middleware builds the callback URL out of this exact
   header, so if it points somewhere that does not serve the site, that
   request 404s and the handshake dies with
   `Unauthorized: ... "<!doctype "... is not valid JSON`.
   It defaults to the REST origin (correct when the API host resolves to the
   site) and is overridable with `AQUA_SOCKET_ORIGIN` for the cases where it
   does not — hitting the API by IP, or an emulator's `10.0.2.2`.

   Note `X-Frappe-Site-Name` is *not* sufficient on its own: it decides the
   namespace check, but the callback URL still comes from `Origin`.

The app's Bearer JWT resolves to a real session because the backend's
`tokens.resolve_request` hook runs on that callback like any other request.

Rooms are joined **server-side** from the authenticated identity (§8.3);
`user:{id}` is auto-joined by Frappe itself. The only client-initiated join is
`subscribe:order`, whose ownership the server re-checks on every call.

| Event | Consumed by |
| --- | --- |
| `order:status` | order tracking, seller queue |
| `order:new` | seller queue (+ dashboard refresh) |
| `order:rider_assigned` | order tracking |
| `rider:location` | order tracking |
| `run:updated` | rider run |
| `notification:new` | notifications feed |
| `seller:dashboard` | seller dashboard |

Sockets are an **accelerator, not a source of truth** (§8.6): every screen
still loads over REST. The connection is opened on sign-in/restore and
dropped on sign-out, so a signed-out app holds no socket.

`subscribe:order` is re-sent on reconnect, because the server does not
remember subscriptions across connections.

## Idempotency

`POST /orders` sends an `Idempotency-Key` header (§10.4). The key is generated
once per `PlaceOrderRequest`, so retrying the *same* request returns the
original order instead of placing a second one, while a genuinely new order
gets a new key.

## Field-name notes

Worth knowing, because they are easy to "fix" wrongly:

- **Rider fields on an order are flat** (`rider_id`, `rider_name`,
  `rider_rating`, `stops_before`), not nested.
- **Money is an integer number of rupees** everywhere — never a string or a
  decimal.
- **Orders carry no `subtotal`/`total`.** The client computes them from the
  lines; a server total that disagreed would show the customer a different
  number from the seller's books.
- **The order's address is a snapshot**, not a live join — editing an address
  must not rewrite where a past order went.
- `verification_status` and `business_type` are camelCase strings that match
  the Dart enum names exactly (`detailsReceived`, `roPlant`, …).

## What each feature talks to

| Feature | Backend module |
| --- | --- |
| auth | `api/auth.py` (§4) |
| catalog | `api/catalog.py` (§5.1) |
| orders | `api/orders.py` (§5.2) |
| addresses | `api/addresses.py` (§5.3) |
| payments | `api/wallet.py` (§5.4) |
| empties | `api/empties.py` (§5.5) |
| notifications | `api/notifications.py` (§5.6, §9.1) |
| seller, seller_onboarding | `api/seller.py` (§6) |
| rider | `api/rider.py` (§7) |

## Live tests

`test/live/` drives the data sources against a running bench. Excluded from
the default run so `flutter test` still passes with no backend:

```bash
flutter test                                       # 38 unit/widget, no backend
flutter test test/live --run-skipped --tags live   # against a live bench
```

The 38 offline tests cover routing, typography and widgets that need no data.
Tests that drove whole flows through seeded data were removed along with the
mocks — flow cover now belongs in `test/live/`.

`--run-skipped` is what re-enables them — the tag alone will not, because
`dart_test.yaml` marks the tag skipped.

They need the fixed dev OTP code turned on, or every verify fails with
"That code is not right":

```python
s = frappe.get_single('Aqua Settings')
s.provider = 'console'          # NB: `provider`, not `otp_provider`
s.use_fixed_dev_code = 1
s.fixed_dev_code = '472901'
s.save(ignore_permissions=True); frappe.db.commit()
```

Each test uses a **fresh phone number**: codes are single-use and re-requesting
one for the same number inside the resend window is throttled (correctly).
Numbers must be `+92` + 10 digits starting with `3` — anything else is a 422.

## Verified against a live bench

Checked on a running site (`aqua.mart`, web 8001, socketio 9001), not just by
reading code:

- All 72 client paths resolve on the backend router with matching verbs, and
  all 64 endpoints declared in `api_endpoints.dart` exist server-side.
- The `{"data": ...}` envelope, and the top-level tokens from
  `otp/verify` + `refresh`, match what the DTOs parse.
- `PATCH`, `PUT` and `DELETE` all work — the reason the custom router exists.
- `204` responses come back empty (e.g. `DELETE /notifications/devices`),
  which is why `ApiClient` treats a null body as success.
- **Idempotency works**: replaying an `Idempotency-Key` returned the original
  order; a fresh key created a new one.
- Refresh rotates, and a replayed refresh token is rejected with
  `token_revoked` — a sign-out, not a retry loop.
- **The socket handshake authenticates and delivers.** A client using the
  exact headers from `socket_client.dart` connected, was auto-joined to
  `user:{id}`, and received a `notification:new` payload end to end.

To run a bench without the `bench` CLI:

```bash
cd frappe-bench-v16/sites
../env/bin/python -c "import frappe.app; frappe.app.serve(port=8001, site='aqua.mart', sites_path='.', no_reload=True)"
cd .. && node apps/frappe/socketio.js
```

Binding the site explicitly is what makes `localhost` serve it, which in turn
is what lets the socket's `Origin` callback resolve.

## Still open

- **Push (§9) is registration-only.** `POST/DELETE /notifications/devices` are
  wired, but no FCM SDK is installed, so nothing produces a device token yet.
  Adding `firebase_messaging` and calling `registerDevice` on sign-in
  completes it.
- **KYC uploads need a file picker.** `uploadDocuments` takes `File`s and
  posts them as multipart; the KYC screen still only toggles a checklist, so
  no real photo reaches it.
- **`rider:ping` has no location source.** `pushLocation` is wired to the
  socket, but nothing calls it — that needs a geolocator on the rider's run
  screen.
