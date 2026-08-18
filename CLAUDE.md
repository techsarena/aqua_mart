# Aqua Mart — working notes

Flutter water-delivery app for Pakistan. Three roles in one codebase: **customer**,
**seller**, **rider**. **API-only** — it talks to the ERPNext/Frappe backend in
`frappe-bench-v16/apps/aqua_mart`; there are no mock data sources, so a
reachable API is required to run it.

[README.md](README.md) documents the architecture (layering, data flow, going live).
**Read it first** — this file covers only what the README doesn't: conventions to
follow and traps that have already cost time.

## Commands

```bash
flutter analyze lib/ test/     # must be clean before you call anything done
flutter test                   # full suite
flutter run                    # needs a reachable backend
```

Point it at a backend with `--dart-define=AQUA_API_BASE_URL=` (plus
`AQUA_SOCKET_URL` / `AQUA_SITE_NAME`). Defaults target a local bench — see
[docs/BACKEND_INTEGRATION.md](docs/BACKEND_INTEGRATION.md).

## The design is the spec

This app is built from a design document, not invented. When a screen's layout,
copy, colour, or spacing is in question, **the design wins** — don't improvise a
"nicer" version.

- The user supplies the design as an HTML bundle or a `design-handoff.zip`.
- The bundle is self-extracting: the real markup is a JSON blob inside a
  `<script type="__bundler/template">` tag, not the visible HTML. Parse it out
  before reading.
- **Revisions exist.** A newer zip can supersede an older HTML file. Diff the
  option labels (`dv-olabel`) between revisions before assuming a section is
  unchanged — usually only one or two sections actually moved.
- Later turns supersede earlier ones. The canvas iterates: turn 2b explicitly
  replaces the home screen from 1b. Build the resolved design, not the first draft.

Design tokens are already transcribed into [app_colors.dart](lib/core/theme/app_colors.dart),
[app_typography.dart](lib/core/theme/app_typography.dart), and
[app_spacing.dart](lib/core/theme/app_spacing.dart). Change the token, not the
call site, when the design's scale changes.

## Conventions

- **Navigate by name**, never by literal path: `context.pushNamed(AppRoutes.cart)`.
  Every route lives in [app_routes.dart](lib/core/router/app_routes.dart).
- **Repositories return `Result<T>`** and never throw across layers. `failure.message`
  is already user-facing — show it, don't rewrite it.
- **Never swallow a failure.** `failure: (_) {}` hides real bugs; surface it
  (snackbar, error view) or you will debug it blind later.
- **Features are vertical slices.** `presentation → domain ← data`; domain imports
  neither Flutter nor the other two layers.
- Comments explain *why*, not what. Match the density of the surrounding file.

## Traps

**Onboarding step order is deliberate and easy to break.**
Current flow: intro → phone (1) → OTP (1) → role (2) → name (3) → details (4).

- OTP shares step 1 with phone — it verifies that step, it isn't its own.
- The account is created at the **last** step ([signup_details_screen.dart](lib/features/auth/presentation/screens/signup_details_screen.dart)),
  not at OTP. Calling `signIn()` earlier makes the router redirect skip every
  remaining step straight into the app.
- Sellers must be signed in **before** routing to `/seller/onboarding` — that path
  sits outside the onboarding stack, so a signed-out seller bounces to the intro.
- The intro `push`es (not `go`es) to step 1, so step 1 has a back route.
- If you reorder steps, update every `step:`. The account is created by
  `PATCH /auth/profile` at the last step, so the backend decides what the
  finished profile looks like.

**Urdu.** `AppLanguage.urdu` sets locale `ur`, which mirrors the whole layout.
`localizationsDelegates` in [app.dart](lib/app.dart) is load-bearing — without it,
selecting Urdu crashes every screen with an `AppBar`. Note `AppTypography.urduFamily`
(`Noto Nastaliq Urdu`) is **not bundled**; it resolves to a system fallback.

**`flutter_localizations` pins `intl` to 0.20.2.** Don't bump `intl` past it.

## Widget tests

The suite drives the real widget tree through the router, so layout matters:

- Default test viewport is **800×600**, smaller than a phone. Tall screens need
  `tester.ensureVisible(...)` before `tap`, or the tap silently misses.
- **Never leave a perpetual animation on screen.** A looping `AnimationController`
  (blinking caret, skeleton shimmer) means `pumpAndSettle` never returns. This has
  hung the suite more than once — prefer a static widget.
- The OTP screen's 30s resend countdown is a real `Timer`, and the screen is
  `push`ed so it keeps ticking underneath later steps. Drain it before a test ends
  or the binding reports a pending timer.
- Mock data sources have a **600 ms latency**; `pumpAndSettle` alone sometimes
  isn't enough after an action that hits one. Pump past it explicitly.
- The OTP keypad is a custom widget, not a `TextField` — tap the digit keys.

### Verifying layout visually

Headless tests render text as boxes unless you load the fonts, and the fallback
font is much wider than Figtree — which produces **false overflow** at test size.
Before "fixing" an overflow, check whether it reproduces with real fonts:

```dart
final loader = FontLoader('Figtree')
  ..addFont(Future.value(ByteData.sublistView(
      File('assets/fonts/Figtree-400.ttf').readAsBytesSync())));
await loader.load();
tester.view.physicalSize = const Size(402 * 3, 874 * 3);  // the design's frame
tester.view.devicePixelRatio = 3;
```

Then `RenderRepaintBoundary.toImage` to a PNG and look at it. Keep such probes in
the scratchpad and delete them — don't commit render harnesses.
