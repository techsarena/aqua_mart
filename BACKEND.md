# Aqua Mart backend

Implementation of `API_SPEC.md` on ERPNext v16 + Frappe v16.

## Layout

```
aqua_mart/
├── api/                     # HTTP layer, one module per spec section
│   ├── renderer.py          # serves /v1/* (before_request), JSON envelope
│   ├── router.py            # path + verb -> handler table (all 70 endpoints)
│   ├── auth.py              # §4   otp request/verify/refresh/profile/me/logout
│   ├── catalog.py           # §5.1 sellers, nearby, search, bottles
│   ├── orders.py            # §5.2 place, list, track, cancel, rate, report
│   ├── addresses.py         # §5.3
│   ├── wallet.py            # §5.4 wallet, top-up, cards, khata
│   ├── empties.py           # §5.5
│   ├── notifications.py     # §5.6 + §9.1 device registration
│   ├── seller.py            # §6   onboarding, queue, inventory, riders, payouts
│   ├── rider.py             # §7   run, stops, earnings, application
│   └── realtime.py          # §8   socket room authorisation
├── services/                # business rules — NOT in the api layer
│   ├── order_state.py       # THE transition table (one copy, §10.1)
│   ├── serializers.py       # every response shape (one file, §10.1)
│   ├── pricing.py, geo.py, wallet.py, runs.py, empties.py,
│   ├── dashboard.py, notifications.py, realtime.py,
│   ├── tokens.py            # JWT access/refresh
│   ├── phone.py             # E.164 normalisation + OTP
│   ├── guard.py             # role enforcement, request body
│   └── response.py          # ok()/fail() envelope helpers
├── aqua_mart/doctype/       # 24 custom DocTypes (§3.2)
├── realtime/handlers.js     # socket.io handlers (§8.5)
└── tasks.py                 # scheduled jobs (§10.5)
```

## Routing

The client's clean paths (`/v1/orders/{id}/cancel`) are served from the
`before_request` hook rather than a `page_renderer`, because
`frappe/app.py` routes only GET/HEAD/POST into the website stack and the
spec needs PATCH, PUT and DELETE as well. The nginx rewrite in §1.1 is
therefore optional — the documented paths work against a bare bench.

## Configuration

Almost everything operational lives on the **Aqua Settings** single DocType
(Desk → Aqua Mart → Aqua Settings), not in site config, so it can be changed
without a deploy. Defaults match the spec, and the doc does not need to be
saved for them to apply.

| Section | Controls |
| --- | --- |
| OTP Delivery | `console` / `whatsapp` / `sms`, plus a fixed dev code |
| OTP Limits | TTL, max attempts, resend interval, hourly cap |
| WhatsApp | Meta Cloud API, UltraMsg, or OpenWA credentials |
| SMS | Twilio, or any generic `{phone}` / `{message}` gateway |
| Tokens | access and refresh lifetimes |
| Commerce | deposit, commission rate, low-stock threshold, dispute window |
| Push | FCM server key |

Credentials use `Password` fields, so they are encrypted at rest. The
settings are cached for 5 minutes and the cache is cleared on save, so the
hot paths (every OTP, every token mint) do not hit the database.

**For app development without a gateway:** leave the provider on `console`,
tick *Use Fixed Dev Code*, and every OTP becomes `472901`. The controller
refuses that combination on a live provider, so it cannot be left on by
accident. In `console` mode the code is written to the Error Log — the only
place a plaintext code is ever recorded, and never reachable by the app.
The API never returns the code in any mode (§4.1).

Only two keys remain in `site_config.json`:

| site_config key | Purpose |
| --- | --- |
| `aqua_jwt_secret` | HS256 signing key. Set this so tokens survive a restore; falls back to the site encryption key. |
| `aqua_fcm_key` | Legacy fallback for the FCM key if it is not set in Aqua Settings. |

Pluggable integrations, via `hooks.py` in any app. A hook wins over the
Aqua Settings provider, so an integrator can bypass the built-in senders:

| Hook | Signature |
| --- | --- |
| `aqua_sms_sender` | `(phone, code)` — OTP and rider invites |
| `aqua_push_sender` | `(tokens, payload)` — replaces the default FCM call |
| `aqua_card_tokeniser` | `(customer, number, holder, expiry, cvv, save)` — PSP tokenisation |

## Open questions

Appendix C items are implemented with a stated default, all in one place:

| # | Question | Current behaviour | Where |
| --- | --- | --- | --- |
| 1 | Delivery fee | flat per seller, waived over `free_delivery_over` | `Aqua Seller Profile` |
| 2 | Commission | 10% of gross, deposits excluded | **Aqua Settings** → Commission Rate |
| 3 | Khata approval | `Aqua Khata.is_approved`, no self-serve request flow yet | `api/wallet.py` |
| 4 | Rider pay | per-rider `per_delivery` / `on_time_bonus` | `Aqua Rider Profile` |
| 5 | Deposit | Rs 300, per-bottle override | **Aqua Settings** → Default Deposit |
| 6 | Multi-seller carts | one seller per order, enforced | `api/orders.py` |
| 7 | Rider exclusivity | one seller per rider | `Aqua Rider Profile.seller` |

Change any of these in the one place listed rather than at call sites.
The commission rate in particular is a placeholder and needs a business
answer before real payouts run.
