# Aqua Mart — Backend API Specification

**Target stack:** ERPNext v16 + a custom Frappe app (`aqua_mart`)
**Client:** Flutter app (customer / seller / rider in one binary)
**Status of this document:** authoritative. The Flutter client is already
written against this contract — field names, enum spellings and envelope shapes
below are **transcribed from the shipped Dart DTOs**, not invented. Changing a
key here means changing Dart code.

---

## 0. How to read this document

Every endpoint section gives you:

| Part | Meaning |
| --- | --- |
| **Path** | appended to the base URL |
| **Called by** | which role's app calls it (auth is enforced on this) |
| **Client** | the Dart file that consumes it — grep it if a shape is unclear |
| **Request / Response** | exact JSON. Keys are `snake_case`, always. |

> **Rule 0 — do not rename fields.**
> The client parses these keys literally. `refill_price` is not `refillPrice`
> and not `price_refill`. If a name looks wrong to you, flag it before
> shipping; do not silently "fix" it.

> **Rule 1 — enum values are lowerCamelCase strings.**
> This is the one deliberate exception to snake_case, because Dart enum `.name`
> is used on both sides. `onTheWay`, `cancelledByCustomer`, `buyNew`,
> `jazzCash`, `roPlant`, `detailsReceived`. Getting the case wrong makes the
> client silently fall back to a default value — the worst kind of bug, because
> nothing errors.

---

## 1. Conventions

### 1.1 Base URL & versioning

```
https://api.aquamart.pk/v1
```

The client reads this from a compile-time constant
(`ApiEndpoints.baseUrl`). Keep `/v1` in the path — it is not negotiable later
without shipping a new app build.

Because Frappe serves whitelisted methods at `/api/method/<dotted.path>`, put a
rewrite in front of the app so the clean REST paths in this document resolve.
Nginx:

```nginx
location /v1/ {
    rewrite ^/v1/(.*)$ /api/method/aqua_mart.api.$1 break;
    proxy_pass http://frappe-bench;
}
```

Alternatively, route through a single dispatcher. Either is fine — **the app
must see the paths in this document**, exactly as written.

### 1.2 Response envelope

Every successful response is JSON with the payload under `data`:

```json
{ "data": { ... } }
```

Collections:

```json
{ "data": [ ... ] }
```

The client is tolerant here — it accepts `data`, and for a few endpoints also
accepts a named key (`sellers`, `orders`, `bottles`, `addresses`,
`notifications`, `riders`, `payouts`, `invitations`). **Use `data` everywhere.**
The named keys exist only as a fallback and should be considered deprecated.

> Frappe wraps whitelisted method returns in `{"message": ...}` by default.
> You must strip or bypass that — return `data` at the top level. If you use
> `frappe.response["data"] = ...` and clear `message`, that works.

### 1.3 Error envelope

Non-2xx responses carry a human-readable message. **The client shows
`message` to the user verbatim, in English.** Write these as sentences a
Pakistani customer would understand, not as developer strings.

```json
{
  "message": "This seller has stopped taking orders for today.",
  "code": "seller_closed"
}
```

| Status | Client behaviour | When to use |
| --- | --- | --- |
| `400` | shows `message` | malformed request |
| `401` | **triggers token refresh, then retry once** | expired access token |
| `403` | signs the user out | wrong role, or banned |
| `404` | shows `message` | unknown id |
| `409` | shows `message` | state conflict (order already accepted) |
| `422` | shows **per-field** errors under the inputs | validation |
| `429` | shows `message` | OTP throttle |
| `5xx` | shows `message` | server fault |

`422` has a stricter shape — the client reads `errors` as a field→message map
and paints them on the form:

```json
{
  "message": "Please check the details you entered.",
  "errors": {
    "phone": "Enter a valid Pakistani mobile number.",
    "cnic": "CNIC must be 13 digits."
  }
}
```

A value may be a string or a list of strings (the client takes the first).

> **401 vs 403 matters.** A `401` makes the client attempt a silent refresh and
> replay the request. A `403` logs the user out. Never return `403` for an
> expired token, or users get kicked out mid-order.

### 1.4 Auth header

```
Authorization: Bearer <access_token>
```

Sent on every request except `/auth/otp/request`, `/auth/otp/verify` and
`/auth/refresh`. The client attaches this automatically
([auth_interceptor.dart](../lib/core/network/interceptors/auth_interceptor.dart)).

**Refresh flow, exactly as the client implements it:**

1. Request returns `401`.
2. Client `POST`s `/auth/refresh` with `{"refresh_token": "..."}`.
3. On success it stores the new tokens and **replays the original request once**.
4. If refresh fails, tokens are wiped and the user is bounced to sign-in.

The client will not retry a second time and will not refresh for paths starting
`/auth`. So: `/auth/*` must never answer `401` for an expired-token reason.

### 1.5 Money

**All money is an integer number of rupees.** No decimals, no paisa, no
strings, no currency symbol. `110` means Rs 110.

The client formats display itself (`Formatters.rupees`). Never send
`"Rs 110"` or `110.00`.

### 1.6 Dates & times

ISO-8601 with timezone, e.g. `2026-08-17T14:32:00+05:00`.

- The client parses with `DateTime.tryParse` — a malformed string silently
  becomes "now", so validate on your side.
- Pakistan is `Asia/Karachi` (UTC+5, no DST). Send offsets, not bare
  local strings.
- Date-only fields (`date_of_birth`) may be `YYYY-MM-DD`.
- **Nullable timestamps must be `null`, never `""`.**

### 1.7 IDs

Strings. Always. The client coerces with `'${json['id']}'`, so an integer will
technically work, but send strings so nothing surprises you later.

ERPNext `name` values are natural fits. Suggested prefixes so logs stay
readable: `CUST-`, `SELL-`, `RIDR-`, `ORD-`, `ADDR-`, `BOTL-`, `STOP-`.

The customer-facing order number is a **separate** field, `reference`, e.g.
`SO-2418` — short, speakable over the phone, and what appears in disputes.

### 1.8 Pagination

List endpoints take `?limit=` and `?offset=`. Defaults: `limit=20`,
`offset=0`, max `limit=100`.

The current client does not paginate — it renders whatever it gets. Sensible
server-side defaults therefore matter: never return an unbounded order history.

### 1.9 Localisation

The app ships English, Urdu (`ur`, RTL) and Roman Urdu. Server-generated
user-facing strings (notification titles/bodies, error messages, dispute
reasons) should honour an optional header:

```
Accept-Language: en | ur | ur-Latn
```

Fall back to English when a translation is missing. This is a **nice-to-have
for v1** — ship English first, but design the tables with a locale column so it
isn't a rewrite later.

---

## 2. Roles & authorisation

Three roles. A phone number maps to exactly **one** account with **one** role;
the role is chosen at sign-up and is not switchable server-side in v1.

| Role | Enum value | ERPNext role | Sees |
| --- | --- | --- | --- |
| Customer | `customer` | `Aqua Customer` | own orders, addresses, wallet |
| Seller | `seller` | `Aqua Seller` | own store, queue, riders, payouts |
| Rider | `rider` | `Aqua Rider` | own run, own earnings |

**Enforcement rules — every one of these is a real attack, not a hypothetical:**

- A customer may read an order **only** if `order.customer == session.user`.
- A seller may act on an order **only** if `order.seller == session.seller`.
- A rider may complete a stop **only** if that stop is on **today's own run**.
- `/seller/*` requires an **approved** seller
  (`verification_status == "approved"`). A seller in review gets `403` with a
  message pointing at the waiting screen.
- `/rider/*` (except `invitations`, `seller-codes`, `application`) requires an
  **approved** rider attached to a seller.

Never trust a `seller_id` or `customer_id` from the request body for
authorisation. Derive the actor from the token, always.

---

## 3. ERPNext data model

Map onto stock ERPNext where the semantics genuinely match, and use custom
DocTypes where they don't. Forcing water bottles into the full Item/Stock
machinery costs more than it returns.

### 3.1 Reuse from stock ERPNext

| Concept | ERPNext DocType | Notes |
| --- | --- | --- |
| Login identity | `User` | one per phone; `username` = phone |
| Seller business | `Supplier` **or** custom | see below |
| Customer | `Customer` | link to `User` |
| Bottle SKU | `Item` | one Item per (seller, size) |
| Stock on hand | `Bin` / `Stock Ledger Entry` | optional in v1 |
| Order | `Sales Order` + custom fields | **recommended** |
| Delivery | `Delivery Note` | on stop completion |
| Payment | `Payment Entry` | wallet + cash reconciliation |
| Payout | `Journal Entry` | weekly seller settlement |

> **Recommendation:** back `Order` with `Sales Order` and add the custom fields
> below. You get ERPNext's accounting, reporting and stock hooks for free, and
> the seller's books reconcile without a separate integration. The cost is that
> the app's status names differ from ERPNext's `docstatus` — keep the app's
> `status` in a custom field and treat it as the source of truth for the API.

### 3.2 Custom DocTypes

These have no honest ERPNext equivalent:

| DocType | Purpose | Key fields |
| --- | --- | --- |
| `Aqua Seller Profile` | the store as the app shows it | rating, eta, purification, is_open, service_area, hours, verification_status |
| `Aqua Rider Profile` | rider identity & assignment | seller (Link), cnic, vehicle, registration_number, status, approval state |
| `Aqua Address` | customer address book | label, title, area, house_number, rider_note, lat, lng, is_default |
| `Aqua Order Status Log` | timeline with timestamps | order, status, at, actor |
| `Aqua Run` | a rider's shift | rider, seller, label, date, finished_at |
| `Aqua Run Stop` | one delivery on a run | run, order, sequence, status, amount_to_collect, empties_to_collect |
| `Aqua Wallet` | customer balance | customer, balance, pending_deposits |
| `Aqua Wallet Transaction` | ledger line | wallet, label, amount, is_credit, at |
| `Aqua Top Up` | mobile-money top-up | amount, provider, status, reference |
| `Aqua Empty Holding` | bottles the customer holds | customer, seller, litres, count, deposit |
| `Aqua Dispute` | complaint on an order | order, reason, note, amount, resolution |
| `Aqua Payout` | weekly seller statement | seller, week, gross, commission, net_paid |
| `Aqua Notification` | in-app feed | user, kind, title, body, deep_link, is_read |
| `Aqua OTP` | code issue & verify | phone, code_hash, expires_at, attempts |
| `Aqua Rider Invite Code` | seller's 6-char join code | seller, code, active |

### 3.3 Custom fields on `Sales Order`

| Field | Type | Notes |
| --- | --- | --- |
| `aqua_reference` | Data | `SO-2418`, shown to users |
| `aqua_status` | Select | the app's status enum (§5.2) |
| `aqua_seller` | Link → Aqua Seller Profile | |
| `aqua_address` | Link → Aqua Address | snapshot copied onto the order |
| `aqua_payment_method` | Select | `cash`/`wallet`/`jazzCash`/`card`/`khata` |
| `aqua_delivery_fee` | Int | rupees |
| `aqua_eta_minutes` | Int | |
| `aqua_rider` | Link → Aqua Rider Profile | null until assigned |
| `aqua_rating` | Int | 1–5, null until rated |
| `aqua_cancellation_reason` | Small Text | |
| `aqua_rejection_reason` | Small Text | |

Each `Sales Order Item` needs `aqua_kind` (`refill` / `buyNew`) — refill and
buy-new of the same bottle are **separate lines at different prices**, and only
refills generate empties to collect.

---

## 4. Authentication

Phone + 6-digit SMS OTP. No passwords anywhere in the app.

### 4.1 `POST /auth/otp/request`

**Called by:** all roles, signed out.
**Client:** [auth_remote_data_source.dart](../lib/features/auth/data/datasources/auth_remote_data_source.dart)

```json
{ "phone": "+92 300 4412987" }
```

**Response `200`**

```json
{ "data": { "resend_after_seconds": 30 } }
```

The client reads `resend_after_seconds` (default `30` if absent) and runs a
countdown before re-enabling "Resend code".

**Requirements**

- Accept Pakistani numbers in the forms users actually type: `03004412987`,
  `+923004412987`, `+92 300 4412987`. **Normalise to E.164** (`+923004412987`)
  and store that.
- Rate limit: 3 requests per number per 15 min → `429`.
- Code TTL 5 minutes; max 5 verify attempts, then invalidate.
- **Never return the code in the response.** Not even in staging — someone will
  ship it.
- Do not reveal whether the number is registered. Same response either way.

### 4.2 `POST /auth/otp/verify`

This is the **account-creating** call. It handles both sign-in and sign-up.

```json
{
  "phone": "+92 300 4412987",
  "code": "482913",
  "full_name": "Ayesha Khan",
  "role": "customer"
}
```

`full_name` and `role` come from the sign-up draft and are **only** used when
the account does not exist yet. For an existing account, **ignore them** — a
returning seller must not be downgraded to customer because the app sent a
default.

**Response `200`**

```json
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "def50200a1b2...",
  "is_new_user": false,
  "user": {
    "id": "CUST-0001",
    "full_name": "Ayesha Khan",
    "phone": "+92 300 4412987",
    "role": "customer",
    "gender": "female",
    "date_of_birth": "1996-04-12",
    "avatar_url": null,
    "wallet_balance": 340,
    "khata_due": 1180,
    "khata_seller_name": "Chashma Pure Water",
    "khata_due_date": "2026-08-30T00:00:00+05:00",
    "is_verified": false
  }
}
```

`is_new_user` is required. Return `true` when this verification created the
provisional account or when an existing profile is still incomplete; return
`false` only for a completed registered user. The client uses it to choose
registration versus the user's home screen. Do not infer this from
`full_name`, because backends may generate a name as part of account creation.

> **Note the envelope.** This endpoint returns these keys at the **top level**,
> not under `data`. The client throws a parse error if any of `access_token`,
> `refresh_token`, or `user` is missing. This is deliberate — do
> not "normalise" it.

**Errors:** `422` wrong/expired code (`{"errors": {"code": "That code has expired."}}`),
`429` too many attempts.

**Token lifetimes:** access 60 min, refresh 60 days, refresh rotates on use.

### 4.3 `POST /auth/refresh`

```json
{ "refresh_token": "def50200a1b2..." }
```

**Response `200`** — top level, like verify:

```json
{
  "access_token": "eyJ...",
  "refresh_token": "def50200c3d4..."
}
```

If you don't rotate refresh tokens, echo the same one back — the client
tolerates a missing `refresh_token` and keeps the old one, but explicit is
better.

Failure → `401`. The client then wipes tokens and signs the user out.

### 4.4 `PATCH /auth/profile`

The **final** sign-up step. See §4.6 for why the ordering matters.

```json
{
  "full_name": "Ayesha Khan",
  "role": "customer",
  "gender": "female",
  "date_of_birth": "1996-04-12T00:00:00.000"
}
```

`gender` ∈ `female` | `male` | `unspecified`. `date_of_birth` may be `null`.
`role` may be set exactly once while the OTP-created profile is incomplete;
ignore it for completed profiles so an existing account can never switch roles.

**Response `200`:** `{ "data": { ...user object... } }`

### 4.5 `GET /auth/me` · `POST /auth/logout`

`GET /auth/me` → `{ "data": { ...user object... } }`. Called on every cold
start to restore the session. Keep it fast — it is on the critical path to
first paint.

`POST /auth/logout` → `204`. Revoke the refresh token. Also clear the FCM token
for this device (§9.1).

### 4.6 The sign-up sequence — read this before implementing

The client's onboarding is ordered, and the order is load-bearing:

```
intro → phone (step 1) → OTP (step 1) → role (step 2) → name (step 3) → details (step 4, customer only)
```

- OTP verification immediately signs in an existing user (a user with a
  completed `full_name`). A first-time number receives a provisional,
  profile-incomplete account and continues through role and name; the role is
  finalized by `PATCH /auth/profile`.
- **`/auth/otp/verify` creates the account, but the profile is only complete
  after `PATCH /auth/profile`.** The client's router redirect sends a
  signed-in user straight into the app — so if you treat the user as
  fully-onboarded at verify time, the remaining steps are skipped.

Return `is_verified: false` and keep the account in a `profile_incomplete`
state until `PATCH /auth/profile` lands. Do not block API access on it — the
client manages the step sequence itself; just don't contradict it.

**Sellers** additionally go through KYC (§6.1) after sign-up, at
`/seller/onboarding`, which sits **outside** the onboarding stack. A seller must
be signed in (valid tokens) before that route is reachable.

---

## 5. Customer API

### 5.1 Catalogue

#### `GET /sellers/nearby`

**Called by:** customer home — the "water shelf".
**Client:** [catalog_remote_data_source.dart](../lib/features/catalog/data/datasources/catalog_remote_data_source.dart)

| Query | Required | Notes |
| --- | --- | --- |
| `address_id` | ✅ | which address to measure from |
| `q` | | optional filter text |

**Response `200`**

```json
{
  "data": [
    {
      "id": "SELL-0001",
      "name": "Chashma Pure Water",
      "rating": 4.8,
      "rating_count": 1240,
      "eta_minutes": 25,
      "purification": "RO + UV",
      "sizes": [6, 10, 25],
      "cheapest_refill_price": 110,
      "is_open": true,
      "opens_at": null,
      "distance_metres": 1200,
      "free_delivery_over": 300,
      "logo_url": null,
      "is_regular": true,
      "latitude": 31.5204,
      "longitude": 74.3587,
      "business_type": "roPlant",
      "verification_status": "approved"
    }
  ]
}
```

**Field notes**

- `sizes` — array of **litres as integers**, not labels. Only `6`, `10`, `25`
  are understood; anything else collapses to 25L on the client.
- `purification` — free text shown as-is: `"RO + UV"`, `"Mineral"`.
- `is_regular` — **true when this customer has ordered from this seller
  before.** It is per-customer, not a property of the seller. Drives the
  "your regular" treatment.
- `opens_at` — display string like `"8:00 AM"`, only meaningful when
  `is_open` is false. The client renders `Closed · opens 8:00 AM`.
- `free_delivery_over` — rupee threshold; `0` means always free, `null` means
  no free-delivery offer.
- `distance_metres` — metres from the given address.

**Server rules:** only return `approved`, non-suspended sellers whose service
area covers the address. Sort by a sensible blend of distance and rating; the
client does not re-sort. Closed sellers still appear (greyed) — do not filter
them out.

#### `GET /sellers/search`

| Query | Required | Notes |
| --- | --- | --- |
| `q` | ✅ | search text |
| `address_id` | | scopes to serviceable sellers |
| `sort` | | `nearest` \| `cheapest` \| `fastest` \| `rating` |
| `open_now` | | `true` filters to open sellers |

Same response shape as `/sellers/nearby`. Search should match seller name,
area, and purification label.

#### `GET /sellers/{id}` and `GET /sellers/{id}/bottles`

`GET /sellers/{id}` → one seller object under `data`.

`GET /sellers/{id}/bottles` → the seller's shelf:

```json
{
  "data": [
    {
      "id": "BOTL-0001",
      "seller_id": "SELL-0001",
      "litres": 25,
      "name": "25L Cooler Bottle",
      "refill_price": 110,
      "new_price": 420,
      "deposit": 300,
      "description": "Standard dispenser size",
      "filled_stock": 62,
      "empties_in_yard": 18,
      "photo_url": null,
      "is_visible": true
    }
  ]
}
```

**Field notes**

- `refill_price` — customer hands over an empty bottle.
- `new_price` — customer keeps the bottle. **`deposit` is not added to
  `new_price` by the client** — if the deposit is chargeable, it must already
  be inside `new_price`. `deposit` is the amount refundable on return, shown in
  the empties screen.
- `filled_stock` — the client shows "low stock" at `1–5` and "out of stock" at
  `≤ 0`, and blocks adding to cart when out.
- `empties_in_yard` — seller-side only; harmless to send to customers but not
  displayed.
- `is_visible: false` — **do not return these to customers at all.** The flag
  exists for the seller's own inventory screen, where hidden bottles are still
  listed.

### 5.2 Orders

#### The status lifecycle

`status` is one of exactly these strings:

| Value | Customer sees | Seller bucket |
| --- | --- | --- |
| `pending` | Waiting for the seller | New |
| `accepted` | Order confirmed | Packing |
| `packed` | Bottles loaded | Packing |
| `onTheWay` | On the way | On route |
| `delivered` | Delivered | Done |
| `cancelledByCustomer` | You cancelled this order | Done |
| `rejectedBySeller` | Seller could not take this order | Done |

**Legal transitions:**

```
pending ──accept──> accepted ──pack──> packed ──dispatch──> onTheWay ──deliver──> delivered
   │                    │                 │                     │
   │                    └─────────────────┴─────────────────────┘
   │                              customer cancel
   └──reject──> rejectedBySeller        (cancelledByCustomer)
```

- The customer may cancel from `pending`, `accepted`, `packed`, `onTheWay`.
  Past `delivered`, no. Enforce this — the client hides the button but a replay
  attack shouldn't succeed.
- Only a seller can reject, and only from `pending`.
- Both terminal-unhappy states are final. Never resurrect an order; the
  customer re-orders instead.
- An illegal transition is `409`, not `400`, with a message explaining the
  current state.

#### `POST /orders` — place an order

**Called by:** customer checkout.

```json
{
  "seller_id": "SELL-0001",
  "address_id": "ADDR-0001",
  "lines": [
    {
      "bottle_id": "BOTL-0001",
      "litres": 25,
      "name": "25L Cooler Bottle",
      "kind": "refill",
      "unit_price": 110,
      "quantity": 2
    }
  ],
  "payment_method": "cash",
  "promo_code": null
}
```

`kind` ∈ `refill` | `buyNew`. `payment_method` ∈ `cash` | `wallet` |
`jazzCash` | `card` | `khata`.

> **The client sends `unit_price`. Do not trust it.** Re-price every line from
> your own catalogue and reject with `409` if the client's price is stale
> (`"Prices changed while you were ordering. Please check your cart."`). The
> field is in the payload because the DTO is shared with the response — treat
> it as advisory only.

**Server must validate:**

- seller exists, is `approved`, and `is_open`
- every bottle belongs to that seller, is visible, and has stock ≥ quantity
- the address belongs to the calling customer and is inside the seller's area
- for `wallet`: balance ≥ total, else `409` with a message about topping up
- for `khata`: the customer has an approved khata with **this** seller

**Response `201`** — the full order object (§5.2.1).

#### 5.2.1 The order object

This shape is returned by every order endpoint, and by the seller queue.
It is the single most important shape in the API.

```json
{
  "data": {
    "id": "ORD-0001",
    "reference": "SO-2418",
    "seller_id": "SELL-0001",
    "seller_name": "Chashma Pure Water",
    "lines": [
      {
        "bottle_id": "BOTL-0001",
        "litres": 25,
        "name": "25L Cooler Bottle",
        "kind": "refill",
        "unit_price": 110,
        "quantity": 2
      }
    ],
    "address": {
      "id": "ADDR-0001",
      "label": "home",
      "title": "Home",
      "area": "Gulberg III",
      "house_number": "42-B",
      "rider_note": "Near Hafeez Centre. Ring the bell twice.",
      "latitude": 31.5204,
      "longitude": 74.3587,
      "is_default": true,
      "is_serviceable": true
    },
    "payment_method": "cash",
    "status": "onTheWay",
    "placed_at": "2026-08-17T14:32:00+05:00",
    "customer_name": "Ayesha Khan",
    "delivery_fee": 0,
    "eta_minutes": 25,
    "rider_id": "RIDR-0007",
    "rider_name": "Imran Ali",
    "rider_rating": 4.9,
    "stops_before": 2,
    "rating": null,
    "cancellation_reason": null,
    "rejection_reason": null
  }
}
```

**Critical notes**

- **`address` is a nested object, not an id.** It is a *snapshot* taken at
  order time. If the customer later edits or deletes that address, the order
  must still render the address it was delivered to. Copy the values onto the
  order; do not join live.
- **Do not send `subtotal` or `total`.** The client computes them:
  `subtotal = Σ(unit_price × quantity)`, `total = subtotal + delivery_fee`.
  If you send a `total` that disagrees with the lines, the client shows its own
  figure and the customer sees a different number from your books. Make the
  lines correct.
- **Rider fields are flat, not nested** — `rider_id`, `rider_name`,
  `rider_rating`, `stops_before`. All `null` until a rider is assigned. The
  client builds its rider card only when `rider_id` is non-null.
- `stops_before` — how many stops the rider has before this one. Drives
  "3 stops before you" on the tracking screen. Recompute as the run progresses.
- `customer_name` — populated for seller and rider views; may be `""` for the
  customer's own view.
- `rating` — `null` until rated, then `1`–`5`.

#### `GET /orders`

| Query | Notes |
| --- | --- |
| `status` | optional; `active` and `past` are also accepted as groupings |

Returns `{"data": [ ...orders... ]}`, newest first. Scope to the calling
customer. Support `active` (anything not terminal) and `past` (terminal) as
convenience values — the client's Orders tab is split that way.

#### `GET /orders/{id}` · `GET /orders/{id}/tracking`

`GET /orders/{id}` → one order object.

`GET /orders/{id}/tracking` → the order object **plus** an optional `timeline`:

```json
{
  "data": {
    "...": "all order fields",
    "timeline": [
      { "status": "pending",  "title": "Order placed",    "subtitle": "sent to the seller", "at": "2026-08-17T14:32:00+05:00", "is_complete": true },
      { "status": "accepted", "title": "Order confirmed", "subtitle": "seller accepted",    "at": "2026-08-17T14:34:00+05:00", "is_complete": true },
      { "status": "packed",   "title": "Bottles loaded",  "subtitle": "sealed and checked", "at": "2026-08-17T14:41:00+05:00", "is_complete": true },
      { "status": "onTheWay", "title": "On the way",      "subtitle": "2 stops before you", "at": null, "is_complete": false }
    ]
  }
}
```

> **`timeline` is optional and it overrides.** When present, the client renders
> it verbatim. When absent, the client *derives* the four tracking steps from
> `status` alone, with copy it already owns.
>
> Send `timeline` when you have **real timestamps** — that's its whole value.
> Send it or omit it; never send a half-filled one, because a stored timeline
> wins over the derived one and you'll lose the correct copy.

The four stages the customer follows are: **Order confirmed → Bottles loaded →
On the way → Delivered**. Match those titles if you send a timeline.

#### `POST /orders/{id}/cancel`

```json
{ "reason": "Ordered by mistake" }
```

Returns the updated order (now `cancelledByCustomer`, with
`cancellation_reason` set). `409` if the order is already terminal.

**Refunds:** a wallet- or card-paid order must be refunded to the wallet, and a
`Aqua Wallet Transaction` written. Cash orders need nothing.

#### `POST /orders/{id}/rating`

```json
{ "stars": 5, "tags": ["On time", "Polite rider"], "comment": "Bohat acha service" }
```

`204`. `stars` is 1–5; `tags` and `comment` optional. The rating updates both
the seller's and the rider's rolling average. Only allowed on `delivered`
orders, once.

#### `POST /orders/{id}/report`

Raises a dispute. `reason` is required, `note` optional.

```json
{ "reason": "Bottle seal was broken", "note": "Two of the three were fine." }
```

`204`. Creates an `Aqua Dispute` visible to the seller (§6.7) and notifies
them. The 24-hour settlement clock starts now — see §6.7.

#### `POST /orders/{id}/reorder`

Creates a new `pending` order copying the lines of a past one, re-priced at
today's prices and delivered to the customer's current default address.
Returns the **new** order object. `409` if the seller is closed or bottles are
gone — with a message the customer can act on.

### 5.3 Addresses

**Client:** [address_data_source.dart](../lib/features/addresses/data/datasources/address_data_source.dart)

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/addresses` | the customer's book |
| `POST` | `/addresses` | create (no `id` in body) |
| `PUT` | `/addresses/{id}` | update |
| `DELETE` | `/addresses/{id}` | remove |
| `POST` | `/addresses/{id}/default` | make default |

The address object is as shown in §5.2.1. On create/update the client posts the
same shape minus `id`, and **without `is_serviceable`** — that field is
server-computed.

**Field notes**

- `label` ∈ `home` | `office` | `other` — lowercase, drives the icon.
- `title` is the customer's own name for it (`"Ammi's house"`); `label` is the
  category. They are different fields and both are shown.
- `rider_note` is free text and reaches the rider verbatim
  (`"Ring the bell twice"`). Never drop it.
- **`is_serviceable`** — `false` when no approved seller covers that area.
  Drives the "No sellers here yet" empty state. Compute it on every read; it
  changes as sellers join.
- `POST /addresses` with `is_default: true`, or the dedicated endpoint, must
  atomically clear the flag on the previously-default address. Exactly one
  default per customer.
- Deleting the default address should promote another one, not leave the
  customer with none.

### 5.4 Wallet & payments

**Client:** [wallet_data_source.dart](../lib/features/payments/data/datasources/wallet_data_source.dart)

#### `GET /wallet`

```json
{
  "data": {
    "balance": 340,
    "pending_deposits": 600,
    "transactions": [
      { "id": "WTX-0001", "label": "Top-up · JazzCash", "amount": 1000, "at": "2026-08-16T11:02:00+05:00", "is_credit": true },
      { "id": "WTX-0002", "label": "Order SO-2418",     "amount": 220,  "at": "2026-08-17T14:32:00+05:00", "is_credit": false }
    ]
  }
}
```

`pending_deposits` — bottle deposits that will be released when the customer
returns their empties. Shown separately from the spendable balance.

`amount` is always **positive**; `is_credit` carries the direction.

#### `POST /wallet/top-up`

```json
{ "amount": 1000, "provider": "jazzCash" }
```

`provider` ∈ `jazzCash` | `easypaisa`.

**Response `201`** — a **pending** top-up. The customer approves it in the
provider's own app, so this call returns before the money moves:

```json
{
  "data": {
    "id": "TOP-0001",
    "amount": 1000,
    "provider": "jazzCash",
    "status": "pending",
    "bonus": 60,
    "fee": 0,
    "reference": "JC-88213445",
    "completed_at": null,
    "failure_reason": null
  }
}
```

`status` ∈ `pending` | `succeeded` | `failed`. `bonus` is promotional credit
("Top up Rs 1,000, get Rs 60 free") — the wallet is credited `amount + bonus`.

#### `GET /wallet/top-up/{id}`

Polled by the client while the pending screen is open (roughly every 2s).
Same object. Once `succeeded`, set `completed_at` and credit the wallet **once**
— make the credit idempotent against the provider's reference, because both the
poll and the provider callback will race.

On `failed`, set `failure_reason` to something the customer can act on:
`"You didn't approve the request in time."`

**Time out a pending top-up after 5 minutes** and mark it `failed`. The client's
pending screen expects a resolution; leaving it `pending` forever strands the user.

#### `GET /wallet/transactions`

Paginated ledger, same line shape as above.

#### `POST /payment-methods/cards`

```json
{ "number": "4111111111111111", "holder": "Ayesha Khan", "expiry": "09/28", "cvv": "123", "save": true }
```

`204`.

> **Do not store PAN or CVV.** Forward to the PSP, keep only the token and the
> last four digits. This endpoint is logged with its body redacted on the
> client — mirror that on the server. If your PSP offers a hosted field / SDK
> flow, prefer it and reduce this endpoint to storing a token.

#### `GET /khata`

The monthly-account summary. The headline figures also ride on the user object
(`khata_due`, `khata_seller_name`, `khata_due_date`).

```json
{
  "data": {
    "due": 1180,
    "seller_name": "Chashma Pure Water",
    "due_date": "2026-08-30T00:00:00+05:00",
    "orders": [ { "reference": "SO-2418", "amount": 220, "at": "2026-08-17T14:32:00+05:00" } ]
  }
}
```

### 5.5 Empty bottles

The customer holds deposits on empties and can either **swap** them for full
bottles at refill price, or **return** them for the deposit back.

#### `GET /empties`

```json
{
  "data": {
    "total_deposit": 900,
    "refill_price_per_bottle": 110,
    "holdings": [
      { "id": "EMP-0001", "litres": 25, "count": 2, "seller_id": "SELL-0001", "seller_name": "Chashma", "deposit": 600 },
      { "id": "EMP-0002", "litres": 10, "count": 1, "seller_id": "SELL-0002", "seller_name": "Ravi Aqua", "deposit": 300 }
    ]
  }
}
```

`deposit` is the total for that holding (`count × per-bottle deposit`), not the
per-bottle figure.

#### `POST /empties/return` · `POST /empties/pickup`

```json
{ "holding_ids": ["EMP-0001"], "handling": "refund" }
```

`handling` ∈ `swap` | `refund`.

- `refund` → credits the deposit to the wallet **when the rider collects them**,
  not immediately. The app tells the customer "in 2 days". Until then it counts
  toward `pending_deposits`.
- `swap` → creates a refill order for the same count at refill price.

`/empties/pickup` schedules a collection without an order attached; same body.

### 5.6 Notifications

**Client:** [notification_data_source.dart](../lib/features/notifications/data/datasources/notification_data_source.dart)

| Method | Path | |
| --- | --- | --- |
| `GET` | `/notifications` | the feed for the calling user |
| `POST` | `/notifications/read-all` | mark everything read |
| `PATCH` | `/notifications/{id}` | mark one read |

```json
{
  "data": [
    {
      "id": "NTF-0001",
      "kind": "riderOnTheWay",
      "title": "Imran is on the way",
      "body": "2 stops before you · Rs 220 cash ready",
      "created_at": "2026-08-17T14:45:00+05:00",
      "is_read": false,
      "deep_link": "/customer/order/ORD-0001/track"
    }
  ]
}
```

**`kind` — exact strings, one of:**

`orderUpdate` · `riderOnTheWay` · `priceChange` · `reorderReminder` ·
`khataDue` · `stockLow` · `complaint` · `payout` · `review` · `riderRun`

The client pins `complaint`, `stockLow` and `khataDue` to the top and tints
them — they need action. The rest are chronological.

**`deep_link` is an in-app route path**, not a URL. It must match a real route
or the tap does nothing. Valid examples:

| Route | Use |
| --- | --- |
| `/customer/order/{orderId}/track` | order updates |
| `/customer/order/{orderId}/rate` | after delivery |
| `/customer/wallet` | wallet & khata |
| `/customer/empties` | empties reminder |
| `/seller/orders` | new order for a seller |
| `/seller/disputes/{id}` | complaint raised |
| `/seller/payouts` | payout paid |
| `/rider/run` | run assigned |

Feed is per-user and per-role. A seller must never see customer notifications.

---

## 6. Seller API

All `/seller/*` endpoints act on **the seller derived from the token**. There is
no `seller_id` parameter anywhere in this section, and one must never be
accepted — that would let any seller drive another's store.

### 6.1 Onboarding & KYC

Four steps, matching the client's screens: details → documents → catalogue →
verification waiting room.

#### `POST /seller/register`

```json
{
  "business_name": "Chashma Pure Water",
  "owner_name": "Kamran Sahib",
  "business_type": "roPlant"
}
```

`business_type` ∈ `roPlant` | `waterShop` | `distributor` | `mineralBrand`.

**Response `201`**

```json
{ "data": { "id": "SELL-0001", "verification_status": "detailsReceived" } }
```

#### `POST /seller/documents`

`multipart/form-data`. The client uploads via `ApiClient.upload`.

| Field | Required | Notes |
| --- | --- | --- |
| `cnic_front` | ✅ | image |
| `cnic_back` | ✅ | image |
| `cnic_front_ocr` | ✅ | on-device OCR evidence; max 10,000 characters |
| `cnic_back_ocr` | ✅ | on-device OCR evidence; max 10,000 characters |
| `water_test` | ✅ | water testing certificate |
| `licence` | | NTN / business licence — speeds up approval |
| `plant_photo` | | shown on the store page |

CNIC accepts JPEG/PNG; other documents accept JPEG/PNG/PDF. Maximum 5 MB each.
The server rejects unreadable/non-CNIC images, reversed or duplicate sides, and
mismatched identity numbers before saving. Strip EXIF and store privately —
**CNIC images must never be reachable by a public URL.**

Response: `{"data": {"verification_status": "documentsUploaded"}}`

#### `POST /seller/verification` — submit for review

Body may include the catalogue set up in step 3:

```json
{
  "bottles": [
    { "litres": 25, "refill_price": 110, "new_price": 420 },
    { "litres": 10, "refill_price": 70,  "new_price": 190 },
    { "litres": 6,  "refill_price": 45,  "new_price": 120 }
  ],
  "sells_other_sizes": false
}
```

`sells_other_sizes` flags a seller who trades a size Aqua Mart doesn't list yet
— it is **not** priced here; it's a note for the verification team to follow up.

Response: `{"data": {"verification_status": "inReview"}}`

#### `GET /seller/verification` — the waiting room

Polled by the verification screen.

```json
{
  "data": {
    "verification_status": "inReview",
    "submitted_at": "2026-08-15T10:00:00+05:00",
    "estimated_hours": 24,
    "rejection_reason": null
  }
}
```

`verification_status` ∈ `detailsReceived` | `documentsUploaded` | `inReview` |
`approved` | `rejected`.

Only `approved` unlocks `/seller/*`. On `rejected`, put an actionable sentence
in `rejection_reason` — "The water test certificate has expired. Upload a
current one." — and allow re-submission.

### 6.2 `GET /seller/dashboard` — Today

**Client:** [seller_data_source.dart](../lib/features/seller/data/datasources/seller_data_source.dart)

```json
{
  "data": {
    "orders_today": 18,
    "delivered": 11,
    "earned": 4820,
    "is_open": true,
    "pending_count": 3,
    "low_stock_label": "6L bottles running low — 3 left in stock",
    "rating": 4.8,
    "rating_count": 1240,
    "on_time_percent": 96,
    "sync_online": true,
    "sync_pending": 0,
    "last_synced_at": "2026-08-17T14:50:00+05:00"
  }
}
```

> **The sync fields are flat**, not nested under a `sync` object. The client
> assembles them into its `ErpSyncState`.

- `sync_online` — is the seller's ERP reachable right now.
- `sync_pending` — orders taken while offline, waiting to upload. Non-zero
  raises a banner on Today and a row in Profile. **This is the honest signal
  that the app's numbers and the seller's books have drifted** — don't fake it
  as always-zero.
- `low_stock_label` — a ready-made sentence, or `null`. The client displays it
  verbatim; compose it server-side so the threshold logic lives in one place.
- `earned` — today's delivered revenue in rupees.
- `rating` / `rating_count` — the store's standing, maintained as customers
  rate delivered orders. A store nobody has rated sends `0` / `0`; the client
  prints a dash rather than "0.0", which would read as a terrible score.
- `on_time_percent` — deliveries that met the promised window over the last 30
  days, as `delivered_at <= placed_at + eta_minutes`. Orders missing
  `delivered_at` or with no ETA are **excluded, not counted late** — absent
  data must never manufacture a bad record. No measurable orders sends `100`.

### 6.3 `POST /seller/open`

```json
{ "is_open": false }
```

`204`. Closing hides the seller from `/sellers/nearby` **for new orders only** —
orders already in flight continue normally. Do not cancel anything.

### 6.4 Order queue

#### `GET /seller/orders`

Returns `{"data": [ ...order objects... ]}` — the same shape as §5.2.1, with
`customer_name` populated.

The client buckets by status into **New** (`pending`), **Packing**
(`accepted`, `packed`), **On route** (`onTheWay`), **Done** (terminal).
Return all four buckets in one call; do not pre-filter. Sort oldest-first
within New so the longest-waiting customer is at the top.

#### `POST /seller/orders/{id}/accept` · `POST /seller/orders/{id}/advance`

`advance` moves the order one step along the happy path:

```
pending → accepted → packed → onTheWay → delivered
```

The client's single action button calls `advance` for every step; `accept` is
the explicit first-step alias. Implement both — `accept` is `advance`
restricted to `pending`.

Empty body. Returns the updated order object.

`409` if the order is terminal, or if the transition is illegal.

> **`packed → onTheWay` should require an assigned rider.** Returning `409`
> with `"Assign a rider before sending this order out."` is better than
> dispatching an order nobody is carrying.

#### `POST /seller/orders/{id}/decline`

```json
{ "reason": "Out of 25L stock today" }
```

Returns the order as `rejectedBySeller` with `rejection_reason` set. Only legal
from `pending`. Notify the customer immediately — the client has a dedicated
"Seller could not take this order" screen keyed off this state.

#### `POST /seller/orders/{id}/assign`

```json
{ "rider_id": "RIDR-0007" }
```

`204`. The rider must belong to this seller and be `idle` or `onRun`. Adds a
stop to that rider's current run (§7.1) and sets `rider_id` on the order.

### 6.5 Inventory

| Method | Path | |
| --- | --- | --- |
| `GET` | `/seller/inventory` | all bottles, **including hidden ones** |
| `PUT` | `/seller/inventory/{id}` | update (body is the full bottle object) |
| `DELETE` | `/seller/inventory/{id}` | remove |

Bottle object as §5.1. Unlike the customer-facing shelf, this returns bottles
with `is_visible: false` — the seller manages them here.

`filled_stock` and `empties_in_yard` are editable by the seller. If you wire
real ERPNext stock later, these become read-through to `Bin` — keep the field
names.

Deleting a bottle that appears on a live order must fail with `409`; hide it
instead.

### 6.6 Riders

#### `GET /seller/riders`

```json
{
  "data": [
    {
      "id": "RIDR-0007",
      "name": "Imran Ali",
      "status": "onRun",
      "stops_left": 6,
      "distance_from_customer": 1400,
      "eta_minutes": 12,
      "delivered": 84,
      "on_time_percent": 96,
      "rating": 4.9,
      "late_deliveries": 2,
      "complaints": 0
    }
  ]
}
```

`status` ∈ `onRun` | `idle` | `offDuty`.

`distance_from_customer` and `eta_minutes` are only meaningful when the client
is choosing a rider for a specific order — send `null` otherwise. The
performance figures (`delivered`, `on_time_percent`, `rating`,
`late_deliveries`, `complaints`) are **this week's**.

#### `POST /seller/riders/invite`

```json
{ "phone": "+92 301 5528841", "areas": "Gulberg & Model Town", "hours": "7 AM – 9 PM" }
```

`201`. Sends an SMS with the seller's 6-character join code and creates a
pending invitation the rider will see at §7.5. Responds with the created
invite, plus the code, so the confirmation screen can quote both:

```json
{
  "data": {
    "id": "INV-0004",
    "phone": "+923015528841",
    "status": "pending",
    "sent_at": "2026-08-19T09:12:00+05:00",
    "expires_at": "2026-08-26T09:12:00+05:00",
    "days_left": 7,
    "code": "CHS42K"
  }
}
```

`phone` comes back **normalised to E.164** — the client must display what the
server returns rather than what the seller typed.

#### `GET /seller/riders/code`

```json
{ "data": { "code": "CHS42K" } }
```

The seller's own join code, created on demand if they have none on file.

#### `GET /seller/riders/invitations`

Invites still awaiting a reply — the seller's "waiting on" list. Same element
shape as the invite response above, without `code`. Accepted invites are
**not** listed: the rider is in `GET /seller/riders` by then, and returning
both would show one person twice.

`days_left` counts whole days to `expires_at` and is floored at `0`, so an
overdue invite never reports a negative.

#### `POST /seller/riders/invitations/{id}/resend`

Sends the same code to the same number again and restarts the expiry window.
Deliberately does **not** create a second invitation — the rider would see two
identical offers. `409 already_answered` once the rider has replied.

#### `DELETE /seller/riders/invitations/{id}`

`204`. Withdraws a pending invite. The record is marked `declined` rather than
deleted, so a rider still holding the SMS is told it was withdrawn instead of
hitting a 404. `409 already_answered` if they already replied.

### 6.7 Disputes

#### `GET /seller/disputes` · `GET /seller/disputes/{id}`

```json
{
  "data": {
    "id": "DSP-0001",
    "order_reference": "SO-2418",
    "customer_name": "Ayesha Khan",
    "reason": "Bottle seal was broken",
    "customer_note": "Two of the three were fine.",
    "order_summary": "3 × 25L refill",
    "amount": 330,
    "raised_at": "2026-08-17T16:10:00+05:00",
    "customer_history": "Her first complaint in 14 orders.",
    "has_photo": true
  }
}
```

`customer_history` is context that helps the seller judge fairly — compose it
server-side ("Her first complaint in 14 orders", "Third complaint this month").
`null` is fine.

> **The 24-hour clock.** The client computes time remaining as
> `raised_at + 24h`. Settle inside that window and the seller's rating is
> unaffected. So `raised_at` must be the moment the customer reported it, and
> must never be rewritten when the seller opens the dispute.

#### `POST /seller/disputes/{id}/resolve`

```json
{ "resolution": "refund" }
```

`resolution` ∈ `replacement` | `refund` | `escalate`.

- `replacement` → create a new zero-cost order for the same lines.
- `refund` → credit `amount` to the customer's wallet, write a transaction.
- `escalate` → hand to Aqua Mart support; the dispute stays open, the clock
  stops, and the seller's rating is protected pending review.

`204`.

### 6.8 Service area & hours

#### `GET` / `PUT /seller/service-area`

```json
{ "data": { "areas": ["Gulberg III", "Model Town", "Garden Town"], "radius_km": 5 } }
```

Areas are named localities as customers recognise them. `radius_km` is a
fallback for addresses that don't match a named area.

An address is serviceable (§5.3) when its area is in this list **or** it falls
within `radius_km` of the seller's location.

#### `GET` / `PUT /seller/hours`

```json
{
  "data": {
    "days": [0, 1, 2, 3, 4, 5, 6],
    "opens_at": "08:00",
    "closes_at": "22:00"
  }
}
```

`days` — **0 = Monday … 6 = Sunday**, matching the client's `M T W T F S S`
toggles. Times are `HH:mm`, 24-hour, Asia/Karachi.

These hours drive `is_open` and `opens_at` on the seller object automatically.
The manual `/seller/open` toggle (§6.3) **overrides** them for the rest of the
day — a seller who closes early stays closed until the next day's opening time.

### 6.9 Payouts

#### `GET /seller/payouts` · `GET /seller/payouts/{id}`

```json
{
  "data": [
    {
      "id": "PAY-0001",
      "week_label": "11 – 17 Aug",
      "orders_delivered": 96,
      "gross_sales": 28400,
      "deposits_taken": 3600,
      "deposits_refunded": 1200,
      "commission": 2840,
      "complaint_refunds": 330,
      "cash_collected_by_riders": 19200,
      "net_paid": 8430,
      "is_paid": true,
      "paid_at": "2026-08-18T11:00:00+05:00",
      "bank_label": "Meezan Bank ••4471",
      "reference": "TRX-99120"
    }
  ]
}
```

The arithmetic the statement screen implies:

```
net_paid = gross_sales
         + deposits_taken
         − deposits_refunded
         − commission
         − complaint_refunds
         − cash_collected_by_riders
```

`cash_collected_by_riders` is netted off because that money is **already in the
seller's hands** — the rider handed it over at the end of the run. The client
displays these lines as sent; make them add up, because a seller checking the
maths and finding it wrong is the fastest way to lose them.

---

## 7. Rider API

The rider app is the simplest and the most operationally sensitive — it is used
one-handed on a motorbike, often on poor signal.

### 7.1 `GET /rider/run` — today's run

**Client:** [rider_data_source.dart](../lib/features/rider/data/datasources/rider_data_source.dart)

```json
{
  "data": {
    "id": "RUN-0001",
    "label": "Morning run",
    "seller_name": "Chashma Pure Water",
    "finished_at": null,
    "stops": [
      {
        "id": "STOP-0001",
        "order_id": "ORD-0001",
        "customer_name": "Ayesha Khan",
        "address": "House 42-B, Gulberg III · Near Hafeez Centre. Ring the bell twice.",
        "items": "2 × 25L refill",
        "amount_to_collect": 220,
        "payment_method": "cash",
        "distance_metres": 1200,
        "empties_to_collect": 2,
        "status": "pending",
        "completed_at": null,
        "plot": { "x": -0.4, "y": 0.2 }
      }
    ]
  }
}
```

**Field notes — these carry real operational weight:**

- **`address` is one pre-composed string**, not an object. Include the
  `rider_note` in it, as shown. The rider reads this at the gate; if the note
  is missing they ring the wrong bell.
- **`amount_to_collect` is `0` for anything already paid.** Only `cash` orders
  carry a non-zero figure. Getting this wrong means a rider asks a prepaid
  customer for money.
- **`distance_metres` is measured from the previous stop**, not from the depot.
  The client sums the remaining stops to show run length — an absolute
  distance would make that sum meaningless.
- `empties_to_collect` — the number of empties to take back, which equals the
  refill quantity on that order.
- `items` — a short human string (`"2 × 25L refill + 1 × 6L new"`).
- `plot` — `{x, y}` each in `-1..1`, the stop's position on the run map. This
  is a placeholder until the Maps SDK is wired in. **Send both or send `null`**
  — a half-filled plot pins the stop to an axis it was never on. When you have
  real coordinates, keep sending `plot` and add `latitude`/`longitude`
  alongside; the client will move over without a contract change.
- `status` ∈ `pending` | `delivered` | `failed`.

**Stop order is the delivery order.** The client takes the first `pending` stop
as "next". Sequence them optimally server-side; the rider does not re-sort.

If there is no run today, return a run with an empty `stops` array — not `404`.

### 7.2 `POST /rider/stops/{id}/complete`

Empty body. **Returns the entire updated run**, not just the stop — the client
replaces its state wholesale.

Side effects, all in one transaction:

1. stop → `delivered`, `completed_at` set
2. order → `delivered`
3. cash orders: `amount_to_collect` added to the rider's cash-in-hand
4. empties recorded against the customer's holdings, releasing any pending
   deposit
5. `stops_before` recomputed on every later stop's order
6. customer notified, and prompted to rate

> **Make this idempotent.** Riders lose signal and retap. A second call on an
> already-`delivered` stop must return the run unchanged with `200`, not
> double-count the cash.

### 7.3 `POST /rider/stops/{id}/fail`

```json
{ "reason": "Nobody home" }
```

Returns the updated run. Stop → `failed`. The order does **not** become
terminal — it returns to the seller to reschedule or refund. No cash is
counted. Notify both the customer and the seller.

### 7.4 `POST /rider/cash-handover` · `GET /rider/earnings`

```json
{ "amount": 4820 }
```

`204`. Records the rider handing collected cash to the seller and zeroes
cash-in-hand. Reconcile against the run's actual collected total and flag a
mismatch to the seller rather than silently accepting a short handover.

`GET /rider/earnings`:

```json
{
  "data": {
    "deliveries": 84,
    "per_delivery": 45,
    "on_time_bonus": 500,
    "fuel_advance": 300,
    "rating": 4.9,
    "rating_count": 61,
    "per_day": [12, 14, 9, 15, 11, 13, 10],
    "is_top_rider": true
  }
}
```

`per_day` is **Monday-first, seven entries**. The client charts it and calls out
the best day, so a wrong-length array silently misreports the rider's week.

The client computes: `gross = deliveries × per_delivery`, and
`net_due = gross + on_time_bonus − fuel_advance`. `fuel_advance` is money
already drawn, hence subtracted.

### 7.5 Rider onboarding

A rider cannot self-register into a store — they join **by a seller's invite
code**. Five steps: identity → vehicle → code → confirm → waiting for approval.

#### `GET /rider/seller-codes/{code}`

Resolves a 6-character code so the rider can confirm who they're joining
before committing.

```json
{
  "data": {
    "seller_name": "Chashma Pure Water",
    "area": "Gulberg III",
    "rider_count": 4,
    "joined_year": 2024
  }
}
```

Unknown code → `{"data": null}` with `200`, **not** `404`. The client treats
null as "no seller matches" and shows an inline hint rather than an error
screen.

Rate-limit this — it is an unauthenticated lookup and an obvious enumeration
target. 10 attempts per device per hour.

#### `POST /rider/application`

```json
{
  "full_name": "Imran Ali",
  "cnic": "35202-8841234-1",
  "vehicle": "motorbike",
  "registration_number": "KMR-4471",
  "seller_code": "CHSM24"
}
```

`vehicle` ∈ `motorbike` | `rickshaw` | `loader` | `onFoot`.

- CNIC is 13 digits, conventionally `#####-#######-#`. Validate on digits only.
- `registration_number` is required for every vehicle **except `onFoot`**.
- The CNIC is held for the seller who hires them and is **never shown to
  customers**.

`201`. Creates a pending rider attached to that seller and notifies the seller
to approve.

#### `GET /rider/invitations` · `POST /rider/invitations/{id}`

`GET` returns a list; the client uses **the first element only**:

```json
{
  "data": [
    {
      "id": "INV-0001",
      "seller_name": "Chashma Pure Water",
      "sent_by": "Kamran Sahib",
      "sent_to": "+92 301 5528841",
      "areas": "Gulberg & Model Town",
      "hours": "7 AM – 9 PM"
    }
  ]
}
```

Empty array when there's nothing pending. `POST /rider/invitations/{id}` with
`{"accept": true}` (or `false`) responds; `204`.

Accepting attaches the rider to the seller and puts them in the seller's rider
list as `idle`.


---

## 8. Realtime (Socket.IO)

### 8.1 Why sockets at all

Three things in this app are genuinely live, and polling them is either too
slow or too expensive:

| Need | Who watches | Consequence of polling |
| --- | --- | --- |
| Order status changes | customer tracking screen | customer stares at a stale screen |
| New order arriving | seller queue | seller misses orders; SLA breaks |
| Rider position / stop progress | customer + seller | "3 stops before you" goes stale |

Everything else (wallet, earnings, payouts, inventory) is fine on request/response.
**Do not push what nobody is watching** — it costs battery on a rider's phone
that is already running maps all day.

> The Flutter client does not yet have a socket layer — the notifications feed
> is currently polled. This section is therefore a **greenfield contract**:
> build it as specified and the client work is a straight implementation of
> what's below.

### 8.2 Transport

Frappe already ships a Socket.IO server (`frappe/socketio.js`, port 9000). Use
it rather than standing up a second realtime stack.

```
wss://api.aquamart.pk/socket.io/
```

Client library: `socket_io_client` for Dart (matching Socket.IO **v4**).

**Handshake:** authenticate with the same access token, in `auth`, not in the
query string — query strings end up in proxy logs.

```dart
IO.io('wss://api.aquamart.pk', IO.OptionBuilder()
    .setTransports(['websocket'])
    .setAuth({'token': accessToken})
    .build());
```

Reject the connection with `connect_error` if the token is missing, expired, or
the role doesn't match the rooms being joined. On `401`-equivalent, the client
refreshes its token and reconnects.

### 8.3 Rooms

Join server-side from the authenticated identity. **Never let a client ask to
join an arbitrary room** — that is a full data breach in one line.

| Room | Members | Carries |
| --- | --- | --- |
| `user:{userId}` | that user only | notifications, personal events |
| `order:{orderId}` | the order's customer, seller, assigned rider | status, rider position |
| `seller:{sellerId}` | seller + their riders | new orders, queue changes |
| `rider:{riderId}` | that rider only | run assignment, stop changes |

A client is auto-joined to `user:{own}` plus the rooms its role entitles it to.
A customer joins `order:{id}` only for their own orders, and only while the
tracking screen is open — emit a `subscribe:order` / `unsubscribe:order` event
and validate ownership on each.

### 8.4 Events — server → client

Payloads are the same JSON shapes as the REST responses, so the client reuses
its DTOs. **Send the whole object, not a diff** — partial updates mean the
client has to merge, and merge bugs are invisible until they aren't.

#### `order:status`

Room: `order:{orderId}` and `seller:{sellerId}`.

```json
{
  "order_id": "ORD-0001",
  "status": "onTheWay",
  "order": { "...": "the full order object from §5.2.1" }
}
```

Emit on every transition, including `cancelledByCustomer` and
`rejectedBySeller`.

#### `order:new`

Room: `seller:{sellerId}`. Fires the seller's new-order sound and badge.

```json
{ "order": { "...": "full order object" } }
```

#### `order:rider_assigned`

Room: `order:{orderId}`.

```json
{
  "order_id": "ORD-0001",
  "rider_id": "RIDR-0007",
  "rider_name": "Imran Ali",
  "rider_rating": 4.9,
  "stops_before": 2
}
```

#### `rider:location`

Room: `order:{orderId}`. The one high-frequency event.

```json
{
  "rider_id": "RIDR-0007",
  "order_id": "ORD-0001",
  "latitude": 31.5204,
  "longitude": 74.3587,
  "heading": 145.0,
  "stops_before": 2,
  "eta_minutes": 8,
  "at": "2026-08-17T14:52:11+05:00"
}
```

**Rate:** emit at most **every 10 seconds**, and only while the order is
`onTheWay` with a live watcher in the room. A rider's phone is on mobile data
and a bike battery — 1 Hz tracking is a real cost with no visible benefit at
map zoom.

Riders push their position up on `rider:ping` (§8.5); the server fans it out
only to the orders that rider is currently carrying.

#### `run:updated`

Room: `rider:{riderId}`. Whole run object (§7.1) after any change — a stop
completed elsewhere, a new stop assigned mid-run, a resequence.

#### `notification:new`

Room: `user:{userId}`. The notification object from §5.6.

```json
{ "notification": { "id": "NTF-0001", "kind": "riderOnTheWay", "...": "..." } }
```

This replaces the current polling of `/notifications`.

#### `seller:dashboard`

Room: `seller:{sellerId}`. The dashboard object from §6.2, emitted when a
counter moves. Throttle to once per 5 seconds — a busy seller changes numbers
constantly and the screen only needs to look alive.

### 8.5 Events — client → server

| Event | From | Payload | Notes |
| --- | --- | --- | --- |
| `subscribe:order` | customer, seller | `{"order_id": "..."}` | validate ownership |
| `unsubscribe:order` | any | `{"order_id": "..."}` | on leaving tracking |
| `rider:ping` | rider | `{"latitude":…, "longitude":…, "heading":…}` | every 10 s while on a run |
| `seller:typing` | — | — | not used; do not add chat in v1 |

Validate `rider:ping` against an active run. A rider not on a run pinging
locations is either a bug or someone probing — drop it.

### 8.6 Delivery guarantees & reconnection

Sockets are an **accelerator, not a source of truth**. Every screen must still
work if the socket never connects.

- On reconnect, the client re-fetches over REST and rejoins rooms. Do not
  attempt to replay missed events.
- Never make a state change socket-only. If `order:status` is the sole way the
  client learns an order was delivered, a customer on a lift with no signal
  never finds out.
- Sequence numbers are unnecessary if you always send whole objects — last
  write wins is correct here.

---

## 9. Push notifications (FCM)

Sockets cover the foreground. Push covers a backgrounded or killed app — which,
for a seller waiting on orders, is most of the day.

### 9.1 Token registration

```
POST /notifications/devices
{ "fcm_token": "...", "platform": "android", "app_version": "1.0.0" }

DELETE /notifications/devices
{ "fcm_token": "..." }
```

Register after sign-in and on every token refresh; delete on logout. One user
may have several devices — send to all of them.

### 9.2 Payload

Send **data messages**, not notification messages, so the app controls
presentation and the tap routes correctly in every state.

```json
{
  "data": {
    "kind": "riderOnTheWay",
    "title": "Imran is on the way",
    "body": "2 stops before you · Rs 220 cash ready",
    "deep_link": "/customer/order/ORD-0001/track",
    "notification_id": "NTF-0001"
  },
  "android": { "priority": "high" },
  "apns": { "headers": { "apns-priority": "10" } }
}
```

`kind` and `deep_link` use exactly the values in §5.6.

### 9.3 What to push, per role

| Role | Push | Don't push |
| --- | --- | --- |
| Customer | order accepted, rider on the way, delivered, order rejected, khata due | every status micro-step |
| Seller | **new order** (high priority, sound), complaint raised, payout paid, low stock | routine status changes they made themselves |
| Rider | run assigned, stop added mid-run, invitation | earnings updates |

**The seller's new-order push is the most important notification in the
product.** A missed order is lost revenue and a customer who waited for nothing.
High priority, distinct sound, and it must survive Doze — test on a real
low-end Android device, not an emulator.

Never push a status change to the person who caused it.

---

## 10. Implementation notes for the Frappe app

### 10.1 Suggested layout

```
aqua_mart/
├── aqua_mart/
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth.py            # otp request/verify/refresh/profile/me/logout
│   │   ├── catalog.py         # sellers, nearby, search, bottles
│   │   ├── orders.py          # place, list, track, cancel, rate, report
│   │   ├── addresses.py
│   │   ├── wallet.py          # wallet, top-up, cards, khata
│   │   ├── empties.py
│   │   ├── notifications.py
│   │   ├── seller.py          # dashboard, queue, inventory, riders, payouts
│   │   ├── rider.py           # run, stops, earnings, application
│   │   └── realtime.py        # socket emitters
│   ├── doctype/               # the custom DocTypes from §3.2
│   ├── services/              # business rules — NOT in the api layer
│   │   ├── order_state.py     # the transition table, one place
│   │   ├── pricing.py
│   │   ├── payouts.py
│   │   └── serializers.py     # dict builders matching this document
│   └── tasks.py               # scheduled jobs
└── hooks.py
```

**Keep the transition table in one module** (`order_state.py`). It is enforced
from three different roles' endpoints, and a second copy will drift.

**Put every response shape in `serializers.py`.** One function per object:
`serialize_order(so)`, `serialize_seller(profile, for_customer=None)`,
`serialize_run(run)`. When a field name in this document is wrong, you fix it
in one file — that is the whole point.

### 10.2 Whitelisting & routing

```python
@frappe.whitelist(allow_guest=True)   # /auth/otp/request, /auth/otp/verify, /rider/seller-codes/*
@frappe.whitelist()                   # everything else
```

Guest-allowed endpoints are exactly three. Everything else must require a
session. Audit this list before launch; it is the highest-value mistake to make.

For clean paths, either use the nginx rewrite in §1.1 or add
`website_route_rules` in `hooks.py`.

### 10.3 Response helper

Wrap every handler so the envelope is impossible to get wrong:

```python
def ok(data, status=200):
    frappe.local.response["http_status_code"] = status
    frappe.local.response["data"] = data
    # Frappe's default "message" key must not also be set
    frappe.local.response.pop("message", None)

def fail(message, status=400, code=None, errors=None):
    frappe.local.response["http_status_code"] = status
    frappe.local.response["message"] = message
    if code:   frappe.local.response["code"] = code
    if errors: frappe.local.response["errors"] = errors
```

### 10.4 Idempotency

These must be safe to call twice — the client retries, and riders lose signal:

- `POST /rider/stops/{id}/complete`
- `POST /orders` (accept an `Idempotency-Key` header; return the original order)
- `POST /wallet/top-up/{id}` completion (both the poll and the PSP callback fire)
- `POST /seller/orders/{id}/advance`

### 10.5 Scheduled jobs

| Job | Frequency | Does |
| --- | --- | --- |
| expire OTPs | 5 min | delete codes past TTL |
| time out top-ups | 1 min | pending > 5 min → `failed` |
| open/close stores | 5 min | apply business hours to `is_open` |
| khata reminders | daily | notify customers 3 days before due |
| weekly payouts | Monday 06:00 | build `Aqua Payout` per seller |
| dispute escalation | hourly | unsettled past 24 h → escalate |
| low-stock alerts | hourly | notify sellers under threshold |

### 10.6 Security checklist

- [ ] OTP codes hashed at rest, never logged, never returned
- [ ] Rate limits: OTP request, OTP verify, seller-code lookup
- [ ] CNIC and KYC documents in private storage, signed short-lived URLs only
- [ ] No PAN or CVV persisted — PSP token only
- [ ] Every `/seller/*` and `/rider/*` handler re-derives the actor from the
      session, never from the body
- [ ] Order ownership checked on read as well as write
- [ ] Socket rooms joined server-side from identity
- [ ] `403` reserved for genuine authorisation failures (it signs the user out)
- [ ] Payload size caps on uploads; images stripped of EXIF

### 10.7 Build order

Ship in this sequence — each phase leaves the app usable:

1. **Auth** — OTP, tokens, `/auth/me`, profile. Nothing works without it.
2. **Catalogue + addresses** — the customer can browse. Read-only, low risk.
3. **Orders** — place, list, track, cancel. The core loop.
4. **Seller queue** — accept/advance/decline. Now orders actually move.
5. **Rider run** — stops, complete, fail. Now they arrive.
6. **Wallet, empties, disputes, payouts** — the money edges.
7. **Sockets + push** — replace polling.

Phases 1–5 are the minimum for a real delivery. Everything after is
improvement, not enablement.

---

## 11. Client-side switch-over

**Done.** The switch-over is complete: the mock data sources and the
`USE_MOCK_DATA` flag have been removed, and every feature constructs its
`*ApiDataSource`. The app is API-only and needs a reachable backend to run.

Hosts are the only configuration left:

```bash
flutter run --dart-define=AQUA_API_BASE_URL=https://api.aquamart.pk/v1 \
            --dart-define=AQUA_SOCKET_URL=https://api.aquamart.pk \
            --dart-define=AQUA_SITE_NAME=api.aquamart.pk
```

See [BACKEND_INTEGRATION.md](BACKEND_INTEGRATION.md) for the wiring details,
including the socket handshake, which is stricter than §8.2 describes.

**Recommended integration order:** auth → catalogue → orders → seller → rider,
matching §10.7. Keep the rest on mocks while you go; the two coexist happily.

### Verifying a feature is really integrated

For each feature, check all four:

1. happy path returns the expected shape
2. an error path shows a sensible message (kill the server and try)
3. an empty state renders (new user, no orders)
4. the field names match this document exactly — a typo'd enum does not error,
   it silently falls back to a default

---

## Appendix A — Enum reference

Every enum value the API exchanges. **Case-sensitive.**

| Enum | Values |
| --- | --- |
| `role` | `customer` `seller` `rider` |
| `gender` | `female` `male` `unspecified` |
| order `status` | `pending` `accepted` `packed` `onTheWay` `delivered` `cancelledByCustomer` `rejectedBySeller` |
| `payment_method` | `cash` `wallet` `jazzCash` `card` `khata` |
| line `kind` | `refill` `buyNew` |
| address `label` | `home` `office` `other` |
| `business_type` | `roPlant` `waterShop` `distributor` `mineralBrand` |
| `verification_status` | `detailsReceived` `documentsUploaded` `inReview` `approved` `rejected` |
| rider `status` | `onRun` `idle` `offDuty` |
| stop `status` | `pending` `delivered` `failed` |
| `vehicle` | `motorbike` `rickshaw` `loader` `onFoot` |
| top-up `provider` | `jazzCash` `easypaisa` |
| top-up `status` | `pending` `succeeded` `failed` |
| notification `kind` | `orderUpdate` `riderOnTheWay` `priceChange` `reorderReminder` `khataDue` `stockLow` `complaint` `payout` `review` `riderRun` |
| dispute `resolution` | `replacement` `refund` `escalate` |
| bottle `litres` | `6` `10` `25` (integers, not strings) |

---

## Appendix B — Endpoint index

| # | Method | Path | Role |
| --- | --- | --- | --- |
| 1 | POST | `/auth/otp/request` | guest |
| 2 | POST | `/auth/otp/verify` | guest |
| 3 | POST | `/auth/refresh` | guest |
| 4 | POST | `/auth/logout` | any |
| 5 | GET | `/auth/me` | any |
| 6 | PATCH | `/auth/profile` | any |
| 7 | GET | `/sellers` | customer |
| 8 | GET | `/sellers/nearby` | customer |
| 9 | GET | `/sellers/search` | customer |
| 10 | GET | `/sellers/{id}` | customer |
| 11 | GET | `/sellers/{id}/bottles` | customer |
| 12 | GET | `/orders` | customer |
| 13 | POST | `/orders` | customer |
| 14 | GET | `/orders/{id}` | customer |
| 15 | GET | `/orders/{id}/tracking` | customer |
| 16 | POST | `/orders/{id}/cancel` | customer |
| 17 | POST | `/orders/{id}/rating` | customer |
| 18 | POST | `/orders/{id}/report` | customer |
| 19 | POST | `/orders/{id}/reorder` | customer |
| 20 | GET | `/addresses` | customer |
| 21 | POST | `/addresses` | customer |
| 22 | PUT | `/addresses/{id}` | customer |
| 23 | DELETE | `/addresses/{id}` | customer |
| 24 | POST | `/addresses/{id}/default` | customer |
| 25 | GET | `/wallet` | customer |
| 26 | POST | `/wallet/top-up` | customer |
| 27 | GET | `/wallet/top-up/{id}` | customer |
| 28 | GET | `/wallet/transactions` | customer |
| 29 | POST | `/payment-methods/cards` | customer |
| 30 | GET | `/khata` | customer |
| 31 | GET | `/empties` | customer |
| 32 | POST | `/empties/return` | customer |
| 33 | POST | `/empties/pickup` | customer |
| 34 | GET | `/notifications` | any |
| 35 | POST | `/notifications/read-all` | any |
| 36 | PATCH | `/notifications/{id}` | any |
| 37 | POST | `/notifications/devices` | any |
| 38 | DELETE | `/notifications/devices` | any |
| 39 | POST | `/seller/register` | seller |
| 40 | POST | `/seller/documents` | seller |
| 41 | POST | `/seller/verification` | seller |
| 42 | GET | `/seller/verification` | seller |
| 43 | GET | `/seller/dashboard` | seller |
| 44 | POST | `/seller/open` | seller |
| 45 | GET | `/seller/orders` | seller |
| 46 | POST | `/seller/orders/{id}/accept` | seller |
| 47 | POST | `/seller/orders/{id}/advance` | seller |
| 48 | POST | `/seller/orders/{id}/decline` | seller |
| 49 | POST | `/seller/orders/{id}/assign` | seller |
| 50 | GET | `/seller/inventory` | seller |
| 51 | PUT | `/seller/inventory/{id}` | seller |
| 52 | DELETE | `/seller/inventory/{id}` | seller |
| 53 | GET | `/seller/riders` | seller |
| 54 | POST | `/seller/riders/invite` | seller |
| 54a | GET | `/seller/riders/code` | seller |
| 54b | GET | `/seller/riders/invitations` | seller |
| 54c | POST | `/seller/riders/invitations/{id}/resend` | seller |
| 54d | DELETE | `/seller/riders/invitations/{id}` | seller |
| 55 | GET | `/seller/disputes` | seller |
| 56 | GET | `/seller/disputes/{id}` | seller |
| 57 | POST | `/seller/disputes/{id}/resolve` | seller |
| 58 | GET/PUT | `/seller/service-area` | seller |
| 59 | GET/PUT | `/seller/hours` | seller |
| 60 | GET | `/seller/payouts` | seller |
| 61 | GET | `/seller/payouts/{id}` | seller |
| 62 | GET | `/rider/run` | rider |
| 63 | POST | `/rider/stops/{id}/complete` | rider |
| 64 | POST | `/rider/stops/{id}/fail` | rider |
| 65 | POST | `/rider/cash-handover` | rider |
| 66 | GET | `/rider/earnings` | rider |
| 67 | GET | `/rider/invitations` | rider |
| 68 | POST | `/rider/invitations/{id}` | rider |
| 69 | GET | `/rider/seller-codes/{code}` | guest |
| 70 | POST | `/rider/application` | rider |

---

## Appendix C — Open questions for the product owner

These are genuinely undecided in the client and need a business answer before
the matching endpoint is final:

1. **Delivery fee.** The order object carries `delivery_fee` and sellers have
   `free_delivery_over`, but no rule says how the fee is computed. Flat per
   seller? By distance? Who sets it — the seller or Aqua Mart?
2. **Commission rate.** Payouts show a `commission` line. The rate and whether
   it applies to deposits is not specified anywhere in the app.
3. **Khata approval.** The client shows khata as a payment method and a due
   balance, but there is no flow for a customer to *request* one or a seller to
   grant it. Who opens a khata, and what is the limit?
4. **Rider pay.** `per_delivery` and `on_time_bonus` are displayed as facts.
   Who sets them — the seller, or a platform-wide rate?
5. **Deposit amount.** Defaults to Rs 300 per bottle in the client. Is that
   fixed platform-wide, or per seller and per size?
6. **Multi-seller carts.** The cart and order model assume **one seller per
   order**. Confirm this is intended before anyone builds around it.
7. **Rider–seller exclusivity.** Can a rider work for two sellers? The data
   model currently assumes one.
