# SunHat Read-Only Audit Report

Scope: concurrency, architecture, performance, accessibility, privacy/security, and dead code. This audit is source-inspection based. I did not modify app source, tests, or project configuration.

Note: I did not run a fresh `xcodebuild` command during this read-only pass because the project build tooling is configured to mutate build-number state. Existing local build logs under `/tmp/sunhat-ui-polish-*.log` contained no `warning:` or `error:` matches.

## Findings

### Critical

1. **Critical - Startup can hard-crash on persistent-store creation failure**
   `SunHat/sunhat.swift:72` creates the SwiftData container and `SunHat/sunhat.swift:75` calls `fatalError` on any error, so a migration, app-group, or store-corruption issue bricks launch instead of offering recovery.
   **One-line fix:** Replace `fatalError` with a recoverable store bootstrap path that logs, backs up/quarantines the bad store when appropriate, and shows a repair/reset UI.

### High

2. **High - Forecast-based reminder evaluation is stubbed to always fail**
   `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:268` enters forecast analysis, but `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:277` returns `willTriggerInAdvancePeriod: false`, `confidence: 0.0`, and `daysAnalyzed: 0`; related humidity, wind, precipitation, and time constraints are also marked unimplemented at `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:39`.
   **One-line fix:** Carry forecast and non-temperature condition fields through the Sendable transfer models and implement real forecast evaluation instead of returning a false placeholder.

3. **High - Background trigger evaluation is coupled to a main-actor global weather service**
   `SunHat/Services/Trigger/TriggerEngine.swift:192` evaluates reminders inside an actor but hops to `WeatherService.shared` through `Task { @MainActor ... }` at `SunHat/Services/Trigger/TriggerEngine.swift:195`; the fallback path repeats this at `SunHat/Services/Trigger/TriggerEngine.swift:240`, while `WeatherService` itself is a `@MainActor` singleton at `SunHat/Services/Weather/WeatherService.swift:15`.
   **One-line fix:** Inject a `WeatherProviding` dependency into `TriggerEngine` and keep weather fetch/cache work actor-safe and off the main actor.

4. **High - OpenWeatherMap API keys are persisted in UserDefaults and may be bundled in plaintext**
   `SunHat/Services/Weather/WeatherServiceConfiguration.swift:96` accepts an API key, `SunHat/Services/Weather/WeatherServiceConfiguration.swift:186` stores encoded configuration in `UserDefaults`, `SunHat/Services/Weather/WeatherServiceConfiguration.swift:249` includes `openWeatherMapAPIKey` in that payload, and `SunHat/Services/Weather/WeatherServiceConfiguration.swift:352` also loads `APIKeys.plist` from the app bundle.
   **One-line fix:** Store user-entered provider credentials in Keychain, avoid shipping real provider keys in the bundle, and keep only non-secret provider preferences in `UserDefaults`.

5. **High - Privacy export writes sensitive location/reminder data into Documents without protection or cleanup**
   `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:394` writes export files to the app Documents directory, `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:399` writes raw data there, and `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:402` shares the file URL without visible deletion or file-protection handling.
   **One-line fix:** Write exports to a temporary protected file with complete file protection, share that URL, and delete it after the share sheet completes.

6. **High - OpenWeatherMap location sharing is not reflected in the in-app third-party privacy text**
   `SunHat/Services/Weather/WeatherAPI.swift:333` sends latitude, longitude, and `appid` to OpenWeatherMap, while the third-party services section in `SunHat/Views/Settings/DataPrivacyView.swift:380` through `SunHat/Views/Settings/DataPrivacyView.swift:404` lists only Apple services.
   **One-line fix:** Add OpenWeatherMap to the privacy UI when that provider is enabled and describe what location data leaves the device.

### Medium

7. **Medium - Weather service singleton and main-context setup weakens dependency injection and background reliability**
   `SunHat/Services/Weather/WeatherService.swift:15` makes the service `@MainActor`, `SunHat/Services/Weather/WeatherService.swift:17` exposes `static let shared`, and `SunHat/Services/Weather/WeatherService.swift:30` configures its actor from `modelContainer.mainContext`; many view models and background managers call `WeatherService.shared` directly.
   **One-line fix:** Move weather access behind an injected protocol and construct background-safe model actors from `ModelContainer` rather than passing main-context state through a global service.

8. **Medium - WeatherViewModel publishes too many independent fields from a main-actor loading pipeline**
   `SunHat/ViewModels/WeatherViewModel.swift:14` isolates the whole view model to the main actor, `SunHat/ViewModels/WeatherViewModel.swift:17` through `SunHat/ViewModels/WeatherViewModel.swift:51` expose many independent `@Published` fields, and `SunHat/ViewModels/WeatherViewModel.swift:130` through `SunHat/ViewModels/WeatherViewModel.swift:152` update them across sequential async loads.
   **One-line fix:** Replace the many independent published properties with a small immutable `WeatherViewState`, do fetch/derivation work off-main, then publish one state update per refresh.

9. **Medium - Trigger prediction work is sequential and re-sorts after per-reminder async estimates**
   `SunHat/ViewModels/WeatherViewModel.swift:300` loads triggers, `SunHat/ViewModels/WeatherViewModel.swift:310` processes reminders sequentially, and `SunHat/ViewModels/WeatherViewModel.swift:327` sorts every result set after the loop.
   **One-line fix:** Move trigger prediction derivation into the model/trigger layer, use bounded concurrency for per-reminder estimates, and publish a pre-sorted compact result.

10. **Medium - Background refresh fetches all reminders and filters in memory**
    `SunHat/Services/Weather/WeatherService.swift:337` creates an unfiltered `FetchDescriptor<WeatherReminder>`, `SunHat/Services/Weather/WeatherService.swift:341` fetches every reminder, and `SunHat/Services/Weather/WeatherService.swift:343` filters active reminders with locations in memory.
    **One-line fix:** Use a SwiftData predicate or dedicated model-actor query that fetches only active reminders with locations.

11. **Medium - Particle animations use unmanaged repeating timers and per-tick Tasks**
    `SunHat/Views/Onboarding/CelebrationView.swift:253` starts a 50 Hz repeating `Timer`, `SunHat/Views/Onboarding/CelebrationView.swift:255` spawns a new `Task` each tick, and the welcome particle layer repeats the same timer/Task pattern at `SunHat/Views/Components/WelcomeViewComponents.swift:142`.
    **One-line fix:** Replace timer-driven particles with `TimelineView(.animation)` or `Canvas`, pause when not visible, and provide a deterministic Reduce Motion fallback.

12. **Medium - Tutorial bubble collapses two actions into one VoiceOver element and has a 20 pt dismiss target**
    `SunHat/Views/Components/TutorialBubbleView.swift:35` defines a separate dismiss button, `SunHat/Views/Components/TutorialBubbleView.swift:40` gives its icon a 20x20 frame, then `SunHat/Views/Components/TutorialBubbleView.swift:75` combines the entire bubble into one accessibility element.
    **One-line fix:** Keep the open and dismiss actions as separate accessible controls, add a 44x44 content shape/frame for dismiss, and order them explicitly for VoiceOver.

13. **Medium - Several selection controls are below Apple's 44 pt hit-target guidance**
    `SunHat/Views/Reminders/StreamlinedWeatherConditionsSection.swift:121` fixes mode buttons at 32 pt high, `SunHat/Views/Onboarding/UserPreferencesOnboardingView.swift:487` fixes timing rows at 32 pt high, and `SunHat/Views/Reminders/AllRemindersView.swift:347`/`SunHat/Views/Reminders/AllRemindersView.swift:348` leave filter chips dependent on small text padding.
    **One-line fix:** Give tappable controls at least a 44 pt hit area using frame/contentShape while preserving the compact visual treatment if needed.

### Low

14. **Low - Reminder-list filtering is recomputed from SwiftUI view properties**
    `SunHat/Views/Reminders/AllRemindersView.swift:27` filters reminders for search, `SunHat/Views/Reminders/AllRemindersView.swift:39` applies the selected filter, and `SunHat/Views/Reminders/AllRemindersView.swift:51`/`SunHat/Views/Reminders/AllRemindersView.swift:55` compute active and inactive arrays on demand.
    **One-line fix:** Cache derived reminder groups when query/filter inputs change or move the filter predicate into the data/query layer.

15. **Low - DateFormatter and ISO8601DateFormatter are allocated in computed/hot paths**
    `SunHat/Views/Weather/TemperatureTrendChart.swift:121`, `SunHat/Views/Weather/WeatherViewComponents.swift:504`, `SunHat/Models/WeatherData.swift:162`, and `SunHat/ViewModels/UserPreferencesViewModel.swift:129` allocate formatter instances inline.
    **One-line fix:** Use static cached formatters or Swift `FormatStyle` values so repeated view/model rendering does not allocate formatter objects.

16. **Low - @unchecked Sendable is used to paper over otherwise simple value models and mutable test doubles**
    `SunHat/Models/ReminderLocation.swift:11` and `SunHat/Models/ReminderLocation.swift:45` mark immutable value wrappers as `@unchecked Sendable`, `SunHat/Services/Location/LocationPermissionManager.swift:413` does the same for manual location data containing `CLLocationCoordinate2D`, and `SunHatTests/WeatherServiceTests.swift:273` marks a mutable mock as `@unchecked Sendable`.
    **One-line fix:** Replace unchecked sendability with explicitly Sendable stored primitives or isolate mutable mocks behind an actor/MainActor test harness.

17. **Low - Compiled native-surface components are not reachable from the current app shell**
    `SunHat/Views/Dashboard/MainTabView.swift:41` through `SunHat/Views/Dashboard/MainTabView.swift:61` expose Home, Reminders, Settings, and New Task only; `SunHat/Views/Weather/WeatherView.swift:12` defines a full Weather screen that only appears in its preview at `SunHat/Views/Weather/WeatherView.swift:533`, and `SunHat/Views/Components/NextReadyReminderCompactView.swift:8` plus `SunHat/Models/NextReadyReminderSnapshot.swift:27` are only referenced by previews/tests.
    **One-line fix:** Either wire these surfaces into Dashboard/widgets/App Intents or remove/de-scope them until they have a production entry point.

## Top 5 To Fix Now

1. **Replace the `fatalError` SwiftData bootstrap path.**
   **Blast radius:** App launch, migrations, app-group store access, and any user with a corrupted or incompatible local store.

2. **Implement real forecast and non-temperature trigger evaluation.**
   **Blast radius:** Core reminder correctness, background notifications, App Intent/widget truth, and user trust in weather-triggered reminders.

3. **Remove main-actor singleton weather access from trigger/background paths.**
   **Blast radius:** Background refresh reliability, testability, Swift concurrency safety, and animation/UI responsiveness while weather work runs.

4. **Move API-key persistence out of UserDefaults and remove plaintext bundled secrets.**
   **Blast radius:** Provider configuration, release packaging, user-entered keys, and App Store/privacy review posture.

5. **Fix privacy export file handling.**
   **Blast radius:** Data export flow, sensitive reminder/location/weather history at rest, Files/iTunes backup exposure, and user privacy expectations.

## Implemented

Verification:
- App build passed: `xcodebuild -project SunHat.xcodeproj -scheme SunHat -destination 'id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' build`.
- XCTest subset executed during `test`: 4 tests passed before Swift Testing runner startup.
- Full `test` did not complete: first run hit CoreSimulator `Invalid device state`; retry ran XCTest successfully, then stalled after `◇ Test run started.` in the Swift Testing phase and was terminated.
- Manual smoke launch passed: installed and launched `org.wesley.sunhat` on simulator `20465D2E-7941-46FD-BAE2-21335FE5F0B1`; screenshot captured at `/tmp/sunhat-audit-fixes-launch.png`.
- Commit reference: not created because the working tree had many pre-existing uncommitted source changes, including files touched by these fixes; committing would risk bundling unrelated user changes.

1. **Critical - Startup can hard-crash on persistent-store creation failure**
   `status: fixed`
   `commit: not created - pre-existing dirty worktree`
   Implemented store quarantine, persistent retry, in-memory recovery fallback, and a top recovery banner instead of the original `fatalError` path.

2. **High - Forecast-based reminder evaluation is stubbed to always fail**
   `status: fixed`
   `commit: not created - pre-existing dirty worktree`
   Added Sendable forecast-day transfer data and implemented forecast-day matching across temperature, humidity, wind, precipitation, time window, and sky-condition constraints.

3. **High - Background trigger evaluation is coupled to a main-actor global weather service**
   `status: fixed`
   `commit: not created - pre-existing dirty worktree`
   Trigger evaluation now uses an injected `WeatherAPI` dependency and converts weather DTOs directly into Sendable transfer data instead of calling `WeatherService.shared` through a `@MainActor` task.

4. **High - OpenWeatherMap API keys are persisted in UserDefaults and may be bundled in plaintext**
   `status: fixed`
   `commit: not created - pre-existing dirty worktree`
   Added Keychain-backed OpenWeatherMap credential storage, migration from legacy UserDefaults payloads, and removed bundle `APIKeys.plist` lookup from the development setup path.

5. **High - Privacy export writes sensitive location/reminder data into Documents without protection or cleanup**
   `status: fixed`
   `commit: not created - pre-existing dirty worktree`
   Privacy exports now write to a protected temporary directory with complete file protection and delete the shared file when sharing completes or presentation fails.

6. **High - OpenWeatherMap location sharing is not reflected in the in-app third-party privacy text**
   `status: fixed`
   `commit: not created - pre-existing dirty worktree`
   Added OpenWeatherMap to the third-party services section with coordinate-sharing disclosure and provider-conditional wording.

7. **Medium - Weather service singleton and main-context setup weakens dependency injection and background reliability**
   `status: blocked`
   `commit: not created - pre-existing dirty worktree`
   Resolution plan: migrate UI weather consumers from `WeatherService.shared` to injected `WeatherProviding` dependencies and split `WeatherServiceActor` into a real non-main actor or `@ModelActor`; reason: fully replacing the app-wide singleton touches multiple view models/background managers and is a broader architecture migration than a safe audit-fix hunk.

8. **Medium - WeatherViewModel publishes too many independent fields from a main-actor loading pipeline**
   `status: blocked`
   `commit: not created - pre-existing dirty worktree`
   Resolution plan: introduce a `WeatherViewState` snapshot and update `WeatherView` bindings in one focused refactor; reason: the screen currently binds many individual properties, so changing this safely requires a dedicated view/view-model migration and UI regression pass.

9. **Medium - Trigger prediction work is sequential and re-sorts after per-reminder async estimates**
   `status: blocked`
   `commit: not created - pre-existing dirty worktree`
   Resolution plan: move trigger prediction derivation into `TriggerEngine` or `WeatherModelActor` and add deterministic tests for prediction ordering; reason: existing prediction helpers are main-actor view-model methods and need extraction before bounded concurrency is safe.

10. **Medium - Background refresh fetches all reminders and filters in memory**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Replaced the unfiltered reminder fetch with a SwiftData predicate for active, incomplete, unpaused reminders that have locations.

11. **Medium - Particle animations use unmanaged repeating timers and per-tick Tasks**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Replaced confetti and welcome particle timers with `TimelineView`-driven deterministic rendering and static Reduce Motion fallbacks.

12. **Medium - Tutorial bubble collapses two actions into one VoiceOver element and has a 20 pt dismiss target**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Split open and dismiss into contained accessible controls and expanded the dismiss target to 44x44.

13. **Medium - Several selection controls are below Apple's 44 pt hit-target guidance**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Expanded reported mode buttons, onboarding timing rows, and filter chips to at least 44 pt tappable areas.

14. **Low - Reminder-list filtering is recomputed from SwiftUI view properties**
    `status: blocked`
    `commit: not created - pre-existing dirty worktree`
    Resolution plan: move filtering into a small reminder-list view model or SwiftData-backed query layer; reason: caching SwiftData model arrays in view state risks stale UI without a broader data-flow cleanup.

15. **Low - DateFormatter and ISO8601DateFormatter are allocated in computed/hot paths**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Replaced cited inline `DateFormatter` usage with `formatted(...)` and reused a local ISO8601 formatter within export generation.

16. **Low - @unchecked Sendable is used to paper over otherwise simple value models and mutable test doubles**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Converted location value models to Sendable primitive-backed wrappers and made the weather test double an actor.

17. **Low - Compiled native-surface components are not reachable from the current app shell**
    `status: fixed`
    `commit: not created - pre-existing dirty worktree`
    Added the Weather tab and surfaced `NextReadyReminderCompactView` on the dashboard using `NextReadyReminderSelector`.
