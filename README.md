# Aqua Mart

Water delivery for Pakistan — three apps in one codebase: **customer**, **seller**, and **rider**.

Built from the Aqua Mart design system. Talks to the ERPNext/Frappe backend in
`frappe-bench-v16/apps/aqua_mart` — see
[docs/BACKEND_INTEGRATION.md](docs/BACKEND_INTEGRATION.md).

## Running it

```bash
flutter pub get
flutter run \
  --dart-define=AQUA_API_BASE_URL=http://localhost:8001/v1 \
  --dart-define=AQUA_SOCKET_URL=http://localhost:9001 \
  --dart-define=AQUA_SITE_NAME=aqua.mart
```

The app is **API-only** — every screen reads from the backend, so it needs a
reachable one to get past the sign-in flow. The defines above match a local
bench and are the defaults, so a bare `flutter run` works against one.

The app opens on the language picker → role picker. Sign-in sends a real OTP;
in development, enable the fixed dev code in Aqua Settings.

| Role | Lands on | Notable flows |
| --- | --- | --- |
| I need water | Water shelf home | browse → bottle → cart → pay → track → rate |
| I sell water | Today dashboard | 4-step KYC signup, order queue, disputes, payouts |
| I deliver | Morning run | stop-by-stop delivery, cash handover, earnings |

## Architecture

Feature-first, with clean-architecture layering **inside** each feature. A
feature owns its whole vertical slice, so work stays in one directory.

```
lib/
├── core/                     cross-cutting concerns
│   ├── error/                Failure hierarchy (typed, not strings)
│   ├── localization/         AppLanguage — English / اردو / Roman Urdu
│   ├── network/              ApiClient, endpoint registry, interceptors
│   ├── realtime/             Socket.IO client + event registry
│   ├── providers/            Riverpod roots (ApiClient, socket, storage)
│   ├── router/               GoRouter config + route-name registry
│   ├── storage/              token + preference persistence
│   ├── theme/                design tokens: colours, type, spacing
│   └── utils/                Result<T>, Formatters
│
├── features/<feature>/
│   ├── domain/               entities + repository interfaces (pure Dart)
│   ├── data/                 DTOs, data sources, repository impls
│   └── presentation/         providers, screens, widgets
│
└── shared/widgets/           the reusable widget kit
```

**Dependency rule:** `presentation → domain ← data`. The domain layer imports
nothing from the other two, so business rules stay testable without Flutter.

### Features

`auth` · `catalog` · `orders` · `addresses` · `payments` · `empties` ·
`notifications` · `customer` · `seller` · `seller_onboarding` · `rider`

## Navigation

One `GoRouter` ([app_router.dart](lib/core/router/app_router.dart)) with three
`StatefulShellRoute`s — one per role — so each role's tabs keep independent
navigation stacks. Detail screens push above the shells on the root navigator.

Every path and route name lives in [app_routes.dart](lib/core/router/app_routes.dart);
screens navigate by name (`context.pushNamed(AppRoutes.cart)`), never by literal path.

A `redirect` guard enforces the entry sequence: **language → role → signup → role's home**.
Signed-in users are bounced out of onboarding; signed-out users can't reach an app shell.

## The data layer

Designed so REST integration is additive, not a rewrite. Four layers:

```
Screen → Provider → Repository → DataSource → ApiClient → REST
                        ↓            ↓
                    Result<T>       DTO ⇄ Entity
```

**1. `ApiClient`** — wraps Dio. Translates every transport error into a typed
`Failure` (`NetworkFailure`, `AuthFailure`, `ValidationFailure`, …). Features
never import `dio`. Auth token attach + refresh-on-401 is an interceptor.

**2. Data sources** — an interface per feature with one REST implementation:

```dart
abstract interface class CatalogRemoteDataSource { ... }

class CatalogApiDataSource implements CatalogRemoteDataSource { ... }   // REST
```

The interface stays because it is the seam the repository depends on — a
second implementation (a cache, a fake in a test) plugs in without touching
the feature.

**3. DTOs** — own all JSON parsing (`fromJson` / `toJson` / `toDomain`), so
entities carry no serialisation concerns and a backend field rename touches one file.

**4. Repositories** — return `Result<T>`, never throw across layers:

```dart
final result = await repo.nearbySellers(addressId: id);
result.when(
  success: (sellers) => ...,
  failure: (f) => ...,   // f.message is already user-facing
);
```

### Pointing at another backend

Every endpoint is registered in
[api_endpoints.dart](lib/core/network/api_endpoints.dart); hosts come from
[api_environment.dart](lib/core/network/api_environment.dart).

```bash
flutter run --dart-define=AQUA_API_BASE_URL=https://api.aquamart.pk/v1 \
            --dart-define=AQUA_SOCKET_URL=https://api.aquamart.pk \
            --dart-define=AQUA_SITE_NAME=api.aquamart.pk
```

### Tests

```bash
flutter test                                       # 38, no backend needed
flutter test test/live --run-skipped --tags live   # against a live bench
```

Nothing above the data source changes — not the repository, providers, or screens.

## State management

Riverpod 3. `Notifier` / `AsyncNotifier` throughout (`StateProvider` is gone in v3).

Screens render `AsyncValue` exhaustively so loading, error, and empty states are
never accidentally skipped:

```dart
switch (async) {
  AsyncLoading() => const SkeletonList(),
  AsyncError(:final error) => ErrorView(failure: asFailure(error), onRetry: ...),
  AsyncValue(value: final data) => ...,
}
```

## Design system

Tokens in [core/theme/](lib/core/theme/) — a single source of truth for colour,
type, spacing and radius. No hard-coded colours or font sizes in screens.

- **Palette** — cerulean `#1C7A9E` accent, teal `#3F9188` secondary, on `#E8F2F8`
- **Type** — two stacks:
  - headings — `Bricolage Grotesque, Figtree, system-ui, sans-serif`
  - body — `-apple-system, system-ui, sans-serif` (the platform UI font)

  Both brand faces are bundled in [`assets/fonts/`](assets/fonts/) as **static
  instances** cut from the upstream variable fonts at exactly the weights the
  app uses (Bricolage 700/800, Figtree 400–800). Static beats shipping the
  variable file: weight rendering is then identical on every platform. ~380 KB
  total. Both are SIL Open Font License; the OFL texts sit alongside the fonts.

  Body copy stays on the system font by design — most legible at small sizes,
  and it inherits the user's own accessibility settings. `AppTypography.brandBody()`
  is there for the rare spot that wants Figtree instead.
- **Frame** — buttons, tags, chips and inputs are pill; cards are 22–28px
- **Logo** — the Fluid Cart mark is drawn as a `CustomPainter`
  ([aqua_logo.dart](lib/shared/widgets/aqua_logo.dart)), so it scales cleanly and
  drops its ripple details below 48px as the brand rules require

## Localisation

`AppLanguage` covers English, اردو and Roman Urdu. Urdu flips the layout to RTL
via `Directionality` in [app.dart](lib/app.dart); Roman Urdu stays LTR. Prices,
order numbers and phone numbers stay in Latin digits in every locale — the
`Formatters` helpers are deliberately locale-independent.

UI strings are currently inline. To add ARB-based translation, wire
`flutter_localizations` + `intl` codegen and replace the literals — the
direction and font handling is already in place.

## Testing

```bash
flutter test
```

18 tests over cart mechanics, order-status transitions, formatters and order-line
maths — the logic most likely to break silently.

## Known gaps

These are deliberate stubs, not oversights:

- **Maps** — [`MapPlaceholder`](lib/shared/widgets/map_placeholder.dart) stands in
  for the Google Maps SDK. Replace that one widget to go live; every map screen
  routes through it.
- **Payment rails** — the JazzCash handoff simulates approval and timeout. Real
  integration replaces `MockWalletDataSource`.
- **Push notifications** — the feed is polled; FCM is not wired.
- **Token storage** — `SharedPreferences` today. Swap `PrefsTokenStorage` for
  `flutter_secure_storage` before shipping; the `TokenStorage` interface won't change.
