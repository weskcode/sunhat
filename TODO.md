# SunHat TODO

Last updated: July 30, 2026
This is the **single live tracker**. Completed audits and phased plans were folded in here and removed
(`IMPROVEMENT_PLAN.md`, `REPO_AUDIT_IOS.md`, `REPO_AUDIT_IOS_IMPLEMENTATION.md`,
`NATIVE_IOS_FEATURE_PROGRESS.md`, `UI_POLISH_RECOMMENDATIONS.md`, `audit/`, all in git history).
Future-surface plans stay as reference: [WIDGET_SETUP.md](WIDGET_SETUP.md),
[WATCHOS_PORT_PLAN.md](WATCHOS_PORT_PLAN.md), [IPAD_PORT_PLAN.md](IPAD_PORT_PLAN.md).
The July 10 product/code audit lives in [CODE_AUDIT.md](CODE_AUDIT.md) with a resolution log.

## Build Status

- [x] Debug simulator build: **passing, zero warnings** (July 21, 2026)
- [x] Unit tests: **passing, 247 tests / 50 suites** (July 21, 2026)
- [x] UI smoke tests: **run successfully** (July 21, 2026), `ScreenshotCaptureUITests` (10/10) run reliably
      once the simulator's location permission is left in a granted state (see note below); light mode only,
      dark mode / Dynamic Type still want a manual pass

Simulator policy: use only the configured `iPhone 17 Pro` (`20465D2E-7941-46FD-BAE2-21335FE5F0B1`).

July 30 follow-up verification: the full production target and every unit-test source pass
standalone Swift 6 type checking against the iOS 26.5 SDK with MainActor default isolation.
On August 19, the current app built successfully, installed, launched, and rendered its
onboarding screen on the configured iPhone 17 Pro simulator. A focused re-test compiled but
the Xcode test runner stalled while finalizing its log amid unrelated concurrent Xcode jobs;
the last completed automated baseline remains 68 focused and 258 full-suite tests.

---

## Submission Blockers, require Wesley / hardware / App Store Connect

These cannot be verified from this machine's simulator:

1. **Device-verify the core loop**, install a signed build on hardware, create a reminder whose
   condition is currently true, background the app, confirm the notification arrives.
   (BGTaskScheduler cannot be trusted from simulator/unit tests.)
2. **WeatherKit entitlement provisioning**, confirm the WeatherKit capability is enabled for
   `org.wesley.sunhat` on the release App ID and that a distribution profile generated *after*
   adding the capability is used. A failed WeatherKit fetch on device now logs the raw error
   (Console.app, subsystem `org.wesley.sunhat`, category `AppleWeatherKitAPI`).
3. **Email inboxes**, send a test mail to `support@`, `feedback@`, `privacy@` `sunhat.app`
   and confirm delivery (MX exists, delivery unverified).
4. **Site content renders**, open `https://sunhat.app/privacy` and `/terms` in a real browser
   (the site is a JS-rendered SPA; both return 200 but rendered policy text must be confirmed).
5. **App Store Connect**, support URL, privacy policy URL, privacy nutrition labels
   (location: app functionality only, no tracking, must match `PrivacyInfo.xcprivacy`),
   screenshots upload (`AppStore/sunhat_app_store_screens_v2/` + `_dark` variants),
   and metadata from `AppStore/aso_metadata.txt`.

## Remaining QA (local, pre-submission)

- [x] Interactive tap-through QA on simulator: onboarding, dashboard, weather, create, edit,
      reminders list, settings, done July 21, 2026 via `ScreenshotCaptureUITests` (real device
      interaction, not just unit tests) plus manual screenshot review. **Light mode only.**
- [ ] Dark mode + Dynamic Type at accessibility sizes: still wants a manual pass
- [ ] Remaining VoiceOver audit: weather cards, forecast charts, trigger indicators, badges
- **Simulator note**: on this machine, `org.wesley.sunhat`'s location permission can drift to
  `notDetermined` or `denied` (any `xcrun simctl privacy reset`, or a fresh install, resets it).
  `notDetermined` makes the OS pop a real permission dialog that `ScreenshotCaptureUITests` doesn't
  dismiss, breaking every screenshot after it; `denied` fails `DashboardViewModelTests.viewModelInitialState()`
  (asserts `errorMessage == nil` at construction, which races real CoreLocation state). Keep it
  granted: `xcrun simctl privacy <udid> grant location org.wesley.sunhat`.

---

## Post-Launch / Architecture (not blockers)

### Correctness & data
- [ ] Recovery mode write-gating: the in-memory fallback now shows a banner stating changes
      won't persist; a stricter version would disable creates/edits and offer export/retry
- [ ] `maximumDailyNotifications` ledger, delivery counting exists via
      `UserPreferences.recordNotificationDelivered`; verify enforcement end-to-end on device
- [ ] WeatherKit quota/backoff policy, free tier ~500k calls/month; ~115 active users saturate
      it at the current 15-min cadence. Mitigations: aggressive caching (present), widgets must
      read the cache, consider backing off when long-backgrounded

### Architecture
- [ ] Convert `WeatherServiceActor` (a `@MainActor` class) into a real actor with DTO boundaries;
      move provider/network/cache work off the main actor
- [ ] Normalized location keys + SwiftData predicates for weather cache/history lookups
      (currently bounded to 50 newest rows and filtered in memory)
- [ ] `AppContainer` composition root (all DI protocols exist)
- [ ] Continue `@Observable` migration: `DashboardViewModel`, `WeatherViewModel`,
      `OnboardingCoordinator` (Combine-heavy, do last)
- [ ] Split long settings/privacy views and remaining `DashboardView` sections
- [ ] Replace remaining ad hoc alert booleans with typed alert state

### Platform depth
- [ ] String catalog localization (no `.xcstrings` yet; all copy is inline English)
- [ ] App Intents v2, reminder `AppEntity` + pause/resume/complete/create actions
      (current intents only open screens)
- [ ] Declarative haptics, migrate `UINotificationFeedbackGenerator` /
      `UIImpactFeedbackGenerator` call sites to `.sensoryFeedback`
- [ ] CI: `.github/workflows/ios-build.yml` runs build-for-testing; add a test step when
      hosted simulator launches are stable
- [x] Notification default/View actions deep-link to reminder detail through a persisted
      one-shot handoff; deleted reminders show an unavailable state

### New surfaces (in priority order)
- [ ] `SunHatKit` shared framework, requires Xcode GUI target creation, see [WIDGET_SETUP.md](WIDGET_SETUP.md)
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

## Resolved July 30, 2026 (follow-up audit)

- [x] Delete All Data clears manual-location coordinates from memory and UserDefaults.
- [x] Delete All Data clears pending/delivered notifications and the app badge.
- [x] Quiet-hours or policy-suppressed triggers remain eligible for later delivery and
      no longer advance notification cooldown/statistics.
- [x] Weather-tab location loads are generation-gated so an older request cannot overwrite
      a newer selected city.
- [x] WeatherKit/provider cancellation propagates instead of continuing through fallback
      providers or expired cache recovery.
- [x] Ordinary reminder deletion explicitly removes owned trigger, notification-config,
      and history rows while preserving potentially shared locations.
- [x] Heavy rain/snow, sun showers/flurries, and wintry mix retain their precipitation type.
- [x] Notification default/View action uses an app-level handoff to open reminder detail.
- [x] Run the July 30 focused suite (68 passed) and full `SunHatTests` suite (258 passed),
      with no failures, skips, warnings, or diagnostics.
- [x] Run a fresh runtime smoke test, August 19 build, install, launch, and onboarding render passed.

Detailed evidence and finding IDs: [CODE_AUDIT.md](CODE_AUDIT.md) §15.

---

## Resolved July 21, 2026 (this pass)

Full QA pass over the July 19 audit-fix commit plus everything else in the app: clean rebuild,
full unit suite, then interactive tap-through via `ScreenshotCaptureUITests` with manual screenshot
review. Found and fixed 4 bugs (1 pre-existing, 3 introduced by the July 19 pass); 5 new regression
tests added (247 tests / 50 suites, up from 242/49).

- [x] **Weather tab silently broken for manual-location users**, `WeatherViewModel` resolves its
      location through `LocationPermissionManager.shared.manualLocation`, an in-memory-only
      property with no persistence, while `DashboardViewModel` reads the separately-persisted
      `UserPreferences.manualLocationLatitude/Longitude`. Any user who picked a manual (non-GPS)
      location would see the Dashboard keep working across relaunches while the Weather tab quietly
      fell back to an empty/zeroed state, no error, just wrong data. `LocationPermissionManager`
      now persists `manualLocation` (UserDefaults, `Codable`) and restores it at init.
      (`LocationPermissionManager.swift`; `LocationPermissionManagerTests.swift`, 3 new tests)
- [x] **`ScreenshotSeeder` never set the location the Weather tab actually reads**, same root
      cause as above; seeded builds showed the Weather tab in the broken empty state (confirmed via
      screenshot). Seeder now sets `LocationPermissionManager.shared.manualLocation` directly.
      (`ScreenshotSeeder.swift`)
- [x] **Trigger engine dry-period fix (July 19) had its own edge case**, the new 24h/48h coverage
      check compared raw forecast-day timestamps against a `now + N hours` cutoff, but a provider
      day stamped at a non-midnight hour (WeatherKit doesn't guarantee midnight, `WeatherAPI.swift`
      already works around this elsewhere via `calendar.startOfDay`) could fall just outside that
      cutoff and get miscounted as "no forecast coverage," a false negative on the exact bug this
      pass was fixing. Now buckets by calendar day instead of comparing raw timestamps.
      (`TriggerEngine+ForecastAnalysis.swift`; `TriggerEngineForecastAnalysisTests.swift`, 1 new test)
- [x] **`DetailedReminderView` floating nav bar clipped scrolled content**, the known issue noted
      in `ScreenshotCaptureUITests.swift`: the custom nav bar was a plain `.overlay`, so any section
      scrolling near the top (e.g. "Notification Settings") rendered underneath it. Switched to
      `.safeAreaInset(edge: .top)`, which reserves the space instead of floating over it; trimmed
      the header's now-redundant compensating top padding. Verified via screenshot, sections now
      scroll fully clear of the bar instead of stopping half-hidden under it.
      (`DetailedReminderView.swift`)

Also: deleted 3 stray duplicate `" 2.swift"` files (byte-identical iCloud/Time-Machine conflict
copies of already-tracked files, harmless but untracked clutter) and refreshed the `Raw` App Store
screenshot set to reflect the fixes above (Weather tab now shows real historical/UV/dew-point data
instead of zeros). `Framed`/`FramedDark` and the dark screenshot set were not regenerated, run
`generate_screenshots_v2.py` / `_dark.py` if updated marketing assets are wanted.

## Resolved July 19, 2026 (this pass)

- [x] **Privacy delete-all bug**: `deleteAllUserData` left orphaned `TriggerCondition` and
      `ForecastDay` rows (GDPR path), now deletes every schema type explicitly; schema-parity test passes
- [x] **Synthetic hourly forecast removed**, Weather tab hourly strip now maps real WeatherKit
      hours through `WeatherProviding.fetchHourlyForecast` (new `HourlyForecastDTO` pipeline,
      in-memory 15-min cache, honest "unavailable" empty state; never synthesized)
- [x] **Synthetic "official" weather alerts renamed**, all threshold notices are now branded
      "SunHat … Advisory" with the exact threshold disclosed (WeatherViewModel + DashboardViewModel + UI titles)
- [x] **Historical comparisons are honest**, `yesterdayTemp`/`lastWeekTemp`/`historicalAvgTemp`
      are optional; hardcoded seasonal constants removed; monthly average computed from stored
      data (≥3 samples) or "Not enough history yet"
- [x] **Trigger engine §5.3**, forecast prediction now passes real coordinates and current
      precipitation probability (was hardcoded 0/0/0)
- [x] **Trigger engine §5.4**, 24/48-h dry requirements evaluate every forecast day covering
      the window and require coverage (was a single current-conditions sample)
- [x] **Trigger engine §5.5**, zero temperature tolerance can no longer produce NaN confidence
- [x] **`DataAnalyticsView` deleted**, unreachable screen with non-functional privacy toggles
- [x] **Screenshot UI tests are `@MainActor`**, Swift 6 actor-isolation warnings resolved
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
