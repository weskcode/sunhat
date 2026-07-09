# REPO_AUDIT_IOS Implementation

Date: 2026-07-07

## Work Summary

- PR 1 - Weather Trust: removed fabricated weekly forecast rows and backed the Weather tab weekly forecast with real `WeatherData.forecastDays`.
- PR 2 - Background Notification Ownership: made `TriggerEngineManager` the canonical reminder evaluator/notification path after background weather refresh.
- PR 3 - Weather Cache Query Tightening: reduced unbounded weather cache/history scans and ensured cached weather coordinates are populated consistently.
- PR 4 - Privacy Schema Coverage: centralized the SwiftData schema and expanded privacy export/delete coverage across every app model type.
- PR 5 - CI Gate: added a minimal GitHub Actions build-for-testing workflow.

I tackled P1 first because the audit identified it as a user-trust issue: the Weather tab could present random weekly values as if they were forecast data.

## Top 10 Priority Coverage

1. P1 Weather tab fabricates weekly forecast values - Implemented.
   - Audit ref: `REPO_AUDIT_IOS.md` P1, lines 401-406.
   - Fix: `WeatherViewModel` now maps `WeatherData.forecastDays` directly; missing forecast days remain missing. `WeatherModelActor.fetchForecastData` now reads cached forecast rows instead of returning `[]`.
   - Test/build: added Swift Testing coverage for source-backed weekly rows and empty forecast state; build-for-testing passes.

2. P2 Background trigger ownership is split - Implemented.
   - Audit ref: P2, lines 410-415.
   - Fix: `BackgroundWeatherManager` now refreshes weather only, then delegates reminder evaluation to `TriggerEngineManager`.
   - Test/build: build-for-testing passes.

3. P3 Weather network/cache work remains main-actor isolated - Partial.
   - Audit ref: P3, lines 419-424.
   - Fix: did not do a risky full actor migration because the service still returns SwiftData `WeatherData` model objects. Reduced main-actor persistence pressure by tightening cache/history query paths first.
   - Next: split provider fetch/rate limiting into a non-main actor returning DTOs, then hand off SwiftData writes through a model actor or main context.

4. P4 Weather cache/history lookups fetch too broadly - Implemented, partial normalization.
   - Audit ref: P4, lines 428-433.
   - Fix: bounded cache lookup to the 50 newest rows, added timestamp predicate for cleanup/history, and populated `locationLatitude`/`locationLongitude` when caching.
   - Next: add a normalized rounded/geohash location key and retention-policy tests.

5. P5 Physical-device background delivery remains unverified - Blocked locally.
   - Audit ref: P5, lines 437-442.
   - Reason: requires signed hardware install, backgrounding, notification delivery observation, and logs.

6. P6 App Intents only open screens - Not implemented.
   - Audit ref: P6, lines 446-451.
   - Reason: larger feature PR; requires reminder `AppEntity` design and write-path confirmations.

7. P7 Inline localization blocks future growth - Not implemented.
   - Audit ref: P7, lines 455-460.
   - Reason: should be a dedicated string-catalog migration PR.

8. P8 Privacy export/delete is manually maintained - Implemented, DTO migration still future.
   - Audit ref: P8, lines 464-469.
   - Fix: introduced a shared `SunHatModelSchema`, added explicit privacy export/delete coverage lists, expanded export data for previously omitted persisted types, and added tests that compare privacy coverage to the app schema.
   - Next: move export dictionaries to typed `Codable` DTOs if import/restore or versioned export compatibility becomes a product requirement.

9. P9 UIKit haptics remain in SwiftUI views - Not implemented.
   - Audit ref: P9, lines 473-478.
   - Reason: calls are spread across onboarding/reminder creation flows; proper migration should move feedback to state-driven `.sensoryFeedback` triggers in each owning view.

10. P10 No CI gate - Implemented.
    - Audit ref: P10, lines 482-487.
    - Fix: added `.github/workflows/ios-build.yml`.
    - Test/build: validated the same generic simulator build-for-testing command locally.

## Changes by File

- `.github/workflows/ios-build.yml`
  - Added a pull request and `main` push workflow that runs `xcodebuild build-for-testing` for `SunHatUnitTests`.

- `SunHat/ViewModels/WeatherViewModel.swift`
  - Replaced random weekly forecast padding with deterministic mapping from provider forecast days.
  - Added `dailyWeatherData(from:)` mapping helper for testability and stable ordering.

- `SunHat/Services/Data/WeatherModelActor.swift`
  - Implemented cached forecast lookup for `fetchForecastData(for:days:)`.
  - Added date-range predicate for historical weather reads before location filtering.

- `SunHat/Services/Weather/BackgroundWeatherManager.swift`
  - Removed direct reminder evaluation and direct notification delivery.
  - Delegates background/manual reminder evaluation to `TriggerEngineManager`.

- `SunHat/Services/Trigger/TriggerEngineManager.swift`
  - Added `isBackground` routing to `evaluateAllReminders` so delegated background work still uses background notification context.

- `SunHat/Services/Weather/WeatherService.swift`
  - Bounded cache lookup fetches.
  - Populates coordinate fields when caching weather.
  - Uses a timestamp predicate for old-cache cleanup.

- `SunHatTests/WeatherViewModelDependencyTests.swift`
  - Added coverage that weekly forecast rows come from provider forecast days without fabricated padding.
  - Added coverage that no provider forecast days produce an empty weekly forecast.

- `SunHat/Models/SunHatModelSchema.swift`
  - Added one shared source of truth for the SwiftData schema model list.

- `SunHat/sunhat.swift`
  - Replaced the inline app schema list with `SunHatModelSchema.schema`.

- `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift`
  - Added schema coverage sets for privacy export/delete checks.
  - Expanded privacy export to include trigger conditions, notification configs, reminder history, saved locations, location history, and forecast days.

- `SunHatTests/DataPrivacyViewModelTests.swift`
  - Added schema parity coverage so privacy export/delete lists fail when a persisted model type is added without privacy handling.
  - Expanded delete-all coverage to insert and delete one instance of every SwiftData model type.

Note: the worktree already had unrelated modified files before this sprint (`CLAUDE.md`, several tests, and an untracked `WeatherBackdropPaletteTests.swift`). I did not revert or claim those.

## Feature Verification

- Weather tab current conditions: compile-verified through `WeatherViewModel` dependency tests and app build.
- Weather tab weekly forecast: source-backed rows and empty state are covered by new Swift Testing cases.
- Background weather refresh: compile-verified; now routes through one reminder evaluation manager.
- Reminder notifications: delivery path is centralized through `TriggerEngineManager`/`TriggerNotificationManager`; physical delivery still requires device verification.
- Settings/privacy/export: compile-verified with schema coverage tests added; export now includes previously omitted persisted model categories.
- App Intents: build metadata extraction succeeds during build-for-testing, but real entity/action expansion remains a future PR.

## Test/Build Evidence

- `xcodebuild -list -project SunHat.xcodeproj`
  - Passed. Schemes found: `SunHat`, `SunHatUnitTests`.

- `xcodebuild test -project SunHat.xcodeproj -scheme SunHatUnitTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
  - Build reached app/test-bundle launch, then failed due CoreSimulator state:
    `Invalid device state`, Mach error `-308`, simulator server died.
  - Result bundle: `~/Library/Developer/Xcode/DerivedData/SunHat-ghhhlxtumhrxyzbenqskartivsyf/Logs/Test/Test-SunHatUnitTests-2026.07.07_11-58-39--0400.xcresult`.

- `xcodebuild build-for-testing -project SunHat.xcodeproj -scheme SunHatUnitTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
  - Passed after each implementation batch.

- `xcodebuild build-for-testing -project SunHat.xcodeproj -scheme SunHatUnitTests -destination 'generic/platform=iOS Simulator'`
  - Passed. This is the command used by the new CI workflow.

- `xcodebuild build-for-testing -project SunHat.xcodeproj -scheme SunHatUnitTests -destination 'generic/platform=iOS Simulator'`
  - Passed again after adding privacy schema/export/delete coverage.

## Remaining Risks

- `WeatherServiceActor` is still `@MainActor`; a complete fix needs DTO boundaries and actor/model-context separation.
- Weekly hourly forecast still uses synthetic hourly variation; the audit prioritized weekly fabrication first, but hourly should be reviewed next for the same user-trust standard.
- Background notification delivery is locally compile-verified only; physical-device delivery is still unproven.
- Localization, AppEntity-backed App Intents, and declarative haptics remain open.
- Privacy export now has schema coverage, but typed `Codable` export DTOs are still a future hardening step.
- CI currently build-for-tests; once hosted simulator launch is stable, add `test-without-building` or full `xcodebuild test`.

## Next PR Suggestions

1. WeatherService actor split: provider fetch/rate limiting as DTO-returning non-main actor; SwiftData persistence through a model actor.
2. Physical-device background delivery proof: signed install, true-condition reminder, background refresh/log capture, readiness doc update.
3. Privacy export DTOs: replace dictionary payload assembly with versioned `Codable` export types.
4. App Intents v2: reminder `AppEntity` plus pause/resume/complete/create intents.
5. Declarative haptics: migrate onboarding/reminder creation views to `.sensoryFeedback`.
