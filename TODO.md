# SunHat TODO

Last updated: July 19, 2026
This is the **single live tracker**. Completed audits and phased plans were folded in here and removed
(`IMPROVEMENT_PLAN.md`, `REPO_AUDIT_IOS.md`, `REPO_AUDIT_IOS_IMPLEMENTATION.md`,
`NATIVE_IOS_FEATURE_PROGRESS.md`, `UI_POLISH_RECOMMENDATIONS.md`, `audit/` — all in git history).
Future-surface plans stay as reference: [WIDGET_SETUP.md](WIDGET_SETUP.md),
[WATCHOS_PORT_PLAN.md](WATCHOS_PORT_PLAN.md), [IPAD_PORT_PLAN.md](IPAD_PORT_PLAN.md).
The July 10 product/code audit lives in [CODE_AUDIT.md](CODE_AUDIT.md) with a resolution log.

## Build Status

- [x] Debug simulator build: **passing, zero warnings** (July 19, 2026)
- [x] Unit tests: **passing** (July 19, 2026 — includes new trigger-engine dry-period/zero-tolerance and hourly/advisory/historical honesty suites)
- [ ] UI smoke tests: not yet run reliably (local XCTest UI runner instability)

Simulator policy: use only the configured `iPhone 17 Pro` (`20465D2E-7941-46FD-BAE2-21335FE5F0B1`).

---

## Submission Blockers — require Wesley / hardware / App Store Connect

These cannot be verified from this machine's simulator:

1. **Device-verify the core loop** — install a signed build on hardware, create a reminder whose
   condition is currently true, background the app, confirm the notification arrives.
   (BGTaskScheduler cannot be trusted from simulator/unit tests.)
2. **WeatherKit entitlement provisioning** — confirm the WeatherKit capability is enabled for
   `org.wesley.sunhat` on the release App ID and that a distribution profile generated *after*
   adding the capability is used. A failed WeatherKit fetch on device now logs the raw error
   (Console.app, subsystem `org.wesley.sunhat`, category `AppleWeatherKitAPI`).
3. **Email inboxes** — send a test mail to `support@`, `feedback@`, `privacy@` `sunhat.app`
   and confirm delivery (MX exists, delivery unverified).
4. **Site content renders** — open `https://sunhat.app/privacy` and `/terms` in a real browser
   (the site is a JS-rendered SPA; both return 200 but rendered policy text must be confirmed).
5. **App Store Connect** — support URL, privacy policy URL, privacy nutrition labels
   (location: app functionality only, no tracking — must match `PrivacyInfo.xcprivacy`),
   screenshots upload (`AppStore/sunhat_app_store_screens_v2/` + `_dark` variants),
   and metadata from `AppStore/aso_metadata.txt`.

## Remaining QA (local, pre-submission)

- [ ] Interactive tap-through QA on simulator: onboarding, permissions, create, edit, settings,
      light + dark, Dynamic Type at accessibility sizes
- [ ] Known layout issue: in `DetailedReminderView`, scrolling to the bottom lands the
      "Notification Settings" section header under the floating nav bar / status bar
      (noted in `ScreenshotCaptureUITests.swift` — reproduces regardless of scroll timing)
- [ ] Remaining VoiceOver audit: weather cards, forecast charts, trigger indicators, badges

---

## Post-Launch / Architecture (not blockers)

### Correctness & data
- [ ] Recovery mode write-gating: the in-memory fallback now shows a banner stating changes
      won't persist; a stricter version would disable creates/edits and offer export/retry
- [ ] `maximumDailyNotifications` ledger — delivery counting exists via
      `UserPreferences.recordNotificationDelivered`; verify enforcement end-to-end on device
- [ ] WeatherKit quota/backoff policy — free tier ~500k calls/month; ~115 active users saturate
      it at the current 15-min cadence. Mitigations: aggressive caching (present), widgets must
      read the cache, consider backing off when long-backgrounded

### Architecture
- [ ] Convert `WeatherServiceActor` (a `@MainActor` class) into a real actor with DTO boundaries;
      move provider/network/cache work off the main actor
- [ ] Normalized location keys + SwiftData predicates for weather cache/history lookups
      (currently bounded to 50 newest rows and filtered in memory)
- [ ] `AppContainer` composition root (all DI protocols exist)
- [ ] Continue `@Observable` migration: `DashboardViewModel`, `WeatherViewModel`,
      `OnboardingCoordinator` (Combine-heavy — do last)
- [ ] Split long settings/privacy views and remaining `DashboardView` sections
- [ ] Replace remaining ad hoc alert booleans with typed alert state

### Platform depth
- [ ] String catalog localization (no `.xcstrings` yet; all copy is inline English)
- [ ] App Intents v2 — reminder `AppEntity` + pause/resume/complete/create actions
      (current intents only open screens)
- [ ] Declarative haptics — migrate `UINotificationFeedbackGenerator` /
      `UIImpactFeedbackGenerator` call sites to `.sensoryFeedback`
- [ ] CI: `.github/workflows/ios-build.yml` runs build-for-testing; add a test step when
      hosted simulator launches are stable
- [ ] Notification "View Forecast" action should deep-link to the reminder detail (currently logs only)

### New surfaces (in priority order)
- [ ] `SunHatKit` shared framework — requires Xcode GUI target creation, see [WIDGET_SETUP.md](WIDGET_SETUP.md)
- [ ] WidgetKit small + Lock Screen widgets (reuse `NextReadyReminderSnapshot`)
- [ ] watchOS complication ([WATCHOS_PORT_PLAN.md](WATCHOS_PORT_PLAN.md))
- [ ] iPad-optimized layout ([IPAD_PORT_PLAN.md](IPAD_PORT_PLAN.md))
- [ ] Live Activities: **skip for v1** (no canonical distance-to-trigger/ETA signal)
- [ ] CloudKit sync re-enablement (prepared in code; needs provisioning + migration plan)

### Polish
- [ ] Design token namespace (spacing, radii, animation durations, glass tint strength)
- [ ] Prefer semantic text styles over `AppFontStyle` in new code
- [ ] Profile dashboard scroll / creation / refresh with Instruments on hardware

---

## Resolved July 19, 2026 (this pass)

- [x] **Privacy delete-all bug**: `deleteAllUserData` left orphaned `TriggerCondition` and
      `ForecastDay` rows (GDPR path) — now deletes every schema type explicitly; schema-parity test passes
- [x] **Synthetic hourly forecast removed** — Weather tab hourly strip now maps real WeatherKit
      hours through `WeatherProviding.fetchHourlyForecast` (new `HourlyForecastDTO` pipeline,
      in-memory 15-min cache, honest "unavailable" empty state; never synthesized)
- [x] **Synthetic "official" weather alerts renamed** — all threshold notices are now branded
      "SunHat … Advisory" with the exact threshold disclosed (WeatherViewModel + DashboardViewModel + UI titles)
- [x] **Historical comparisons are honest** — `yesterdayTemp`/`lastWeekTemp`/`historicalAvgTemp`
      are optional; hardcoded seasonal constants removed; monthly average computed from stored
      data (≥3 samples) or "Not enough history yet"
- [x] **Trigger engine §5.3** — forecast prediction now passes real coordinates and current
      precipitation probability (was hardcoded 0/0/0)
- [x] **Trigger engine §5.4** — 24/48-h dry requirements evaluate every forecast day covering
      the window and require coverage (was a single current-conditions sample)
- [x] **Trigger engine §5.5** — zero temperature tolerance can no longer produce NaN confidence
- [x] **`DataAnalyticsView` deleted** — unreachable screen with non-functional privacy toggles
- [x] **Screenshot UI tests are `@MainActor`** — Swift 6 actor-isolation warnings resolved
- [x] **Atmosphere Canvas pauses when scene is inactive** (was a 30 FPS full-screen loop in background)
- [x] **Recovery-mode banner states data-loss consequence** and support contact
- [x] **Screenshot seeder** now seeds stored weather history so demo/screenshot builds show real comparisons
- [x] Creation-screen cleanup (July 17 thread): deleted dead creation subviews
      (`ForecastLikelihoodView`, `ReminderPreviewCards`, `TitleNotesIconSection`,
      `WeatherConditionBuilder`, preview file), added `FlowLayoutConditions` +
      `ReminderIconColorPicker`, flattened tile styling; dark-mode App Store screenshot set generated

<details>
<summary>Older completed work (see git history for details)</summary>

- Background task configuration, ModelContainer injection, expiration-race and
  `weatherActor!` crash fixes; duplicate-registration guards (tested)
- One canonical background notification path (`TriggerEngineManager`); persisted cooldowns
- Weekly forecast fabrication removed; humidity/cloud cover from real hourly aggregates;
  real `precipitationAmount`; no mock weather generators anywhere
- Native settings redesign; enforced notification master switch + quiet hours (tested);
  data export/delete with schema-parity tests; wrong-store bug fixed
- Liquid Glass migration, deprecated-API sweep (`foregroundColor` → `foregroundStyle` etc.),
  `NavigationStack` everywhere, `ContentUnavailableView` empty states, system typography
- Onboarding trimmed to 4 steps; streamlined single-screen creation flow; animation speed pass;
  Reduce Motion coverage; VoiceOver labels on icon-only buttons; 44pt hit targets
- App Intents (open/create), Spotlight indexing, notification actions, lifecycle
  review/feedback prompts; store recovery with quarantine + banner
- `@Observable` migration: `UserPreferencesViewModel`, `SettingsViewModel`,
  `LocationPickerViewModel`, `DataPrivacyViewModel`; DI seams
  (`WeatherProviding`, `LocationManaging`, `SettingsOpening`, `NotificationPermissionProviding`)
- App Store assets: light + dark framed screenshot sets, ASO metadata within limits,
  `sunhat.app` live with privacy/terms returning 200

</details>
