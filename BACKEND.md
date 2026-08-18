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

| site_config key | Purpose |
| --- | --- |
| `aqua_jwt_secret` | HS256 signing key. Set this so tokens survive a restore; falls back to the site encryption key. |
| `aqua_fcm_key` | FCM server key for push (§9). Without it, the in-app feed and sockets still work. |

Pluggable integrations, via `hooks.py` in any app:

| Hook | Signature |
| --- | --- |
| `aqua_sms_sender` | `(phone, message)` — OTP and rider invites |
| `aqua_push_sender` | `(tokens, payload)` — replaces the default FCM call |
| `aqua_card_tokeniser` | `(customer, number, holder, expiry, cvv, save)` — PSP tokenisation |

Without an SMS sender configured, OTP codes are written to the Error Log in
developer mode only, and never returned by the API (§4.1).

## Open questions

Appendix C items are implemented with a stated default, all in one place:

| # | Question | Current behaviour | Where |
| --- | --- | --- | --- |
| 1 | Delivery fee | flat per seller, waived over `free_delivery_over` | `services/pricing.py` |
| 2 | Commission | 10% of gross, deposits excluded | `tasks.py::COMMISSION_RATE` |
| 3 | Khata approval | `Aqua Khata.is_approved`, no self-serve request flow yet | `api/wallet.py` |
| 4 | Rider pay | per-rider `per_delivery` / `on_time_bonus` | `Aqua Rider Profile` |
| 5 | Deposit | Rs 300 default, per-bottle override | `constants.DEFAULT_DEPOSIT` |
| 6 | Multi-seller carts | one seller per order, enforced | `api/orders.py` |
| 7 | Rider exclusivity | one seller per rider | `Aqua Rider Profile.seller` |

Change any of these in the one place listed rather than at call sites.
