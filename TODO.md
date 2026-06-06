# SunHat TODO

Last updated: June 6, 2026

## Build Status

- [x] Compile-only simulator build: **passing** (verified June 6, 2026)
- [x] Unit tests: **222 passing, 0 failed** (verified June 6, 2026; added reminder lifecycle, settings model/enums, Codable transport, and live-forecast mapping coverage)
- [x] Create-task button verified on simulator (detached search-slot glass button; opens create sheet from any tab)
- [ ] UI smoke tests: not yet run (XCTest UI runner previously timed out)
- [ ] Visual QA: broader pass not yet performed on simulator

Simulator policy: use the single configured `iPhone 17 Pro` (`C3E7115C-C029-4352-A255-EFB6CB69367A`) only.

---

## App Store Blockers

These must be resolved before submission. Ordered by risk.

> See **[IMPROVEMENT_PLAN.md](IMPROVEMENT_PLAN.md)** for the full expert review + phased roadmap (widgets, watch, Live Activities, shared `SunHatKit` framework, data-accuracy debt, WeatherKit quota).

### 1. Background Task Configuration

- [x] Add `BGTaskSchedulerPermittedIdentifiers` to `Info.plist` with both task identifiers
- [x] Add `fetch` to `UIBackgroundModes` in `Info.plist`
- [x] Inject the app `ModelContainer` into `BackgroundWeatherManager` and `TriggerEngineManager` from `SunHatApp.init()`
- [x] Fix background task expiration handler race condition (double `setTaskCompleted` crash)
- [x] Fix latent `WeatherService.weatherActor!` crash reachable from background refresh before configuration (configure at startup + guard the force-unwraps)
- [ ] **Device-verify the full loop**: create a reminder whose condition is currently true, background the app, confirm a notification arrives (BGTaskScheduler can't be trusted from simulator/unit tests)
- [ ] Add tests: duplicate registration guard, unavailable background refresh fallback

### 2. Production URLs and Contact Info

`AppSupportLinks.swift` points to `sunhat.app` domain and email addresses that may not exist yet.

- [ ] Confirm `sunhat.app` domain is registered and hosting privacy/terms pages
- [ ] Confirm `support@sunhat.app`, `feedback@sunhat.app`, `privacy@sunhat.app` inboxes are active
- [ ] Verify App Store Connect metadata matches (support URL, privacy policy URL)

### 3. Visual QA and Onboarding Verification

- [ ] Run the app on simulator and walk through: onboarding, permission screens, dashboard empty state, create first reminder, reminder list, weather view, settings
- [ ] Verify onboarding primary action is visible and reachable without scrolling on smallest supported screen
- [ ] Verify all buttons are real `Button` controls (not gesture-only surfaces)
- [ ] Test light mode and dark mode on all key screens

### 4. App Review Compliance

- [x] Verify location permission strings are accurate and specific (Info.plist has 4 specific usage descriptions)
- [ ] Verify WeatherKit entitlement is provisioned for the release App ID (currently in entitlements)
- [x] Confirmed no analytics/tracking SDKs — ATT not required
- [x] Offline error handling verified — dashboard shows "Weather unavailable" with error message

---

## High Priority (Pre-Launch Polish)

### Accessibility

- [ ] Test all screens at default and accessibility Dynamic Type sizes (risk areas: dashboard cards, forecast chips, reminder rows, horizontal tag layouts)
- [x] Added VoiceOver labels to icon-only buttons: edit, more options, sort, create, location actions
- [x] Respect `accessibilityReduceMotion` — already adopted in 22+ views including CelebrationView, onboarding, dashboard, reminders
- [x] Fixed SavedLocationCard ellipsis button hit target from 30x30 to 44x44
- [ ] Full Dynamic Type audit at accessibility sizes (risk areas: dashboard cards, forecast chips, horizontal tag layouts)
- [ ] Remaining VoiceOver audit: weather cards, forecast charts, trigger indicators, badges

### Error Handling

- [x] **Settings link failures** — `SettingsOpening.open` now returns success (`async -> Bool`); `SettingsViewModel` surfaces a "Couldn't Open" alert when Contact Support / Send Feedback / Terms / Open Settings can't launch (e.g. mailto with no mail account). Covered by `SettingsViewModelDependencyTests` (success + failure paths).
- [ ] Remaining silent failures to surface: notification-permission request failures (`SettingsViewModel`/`NotificationPreferencesViewModel`), data-export failures (`DataPrivacyViewModel`), and the direct `UIApplication.shared.open` calls in `PrivacyContactView`/`HelpFAQView`/`DataPrivacyView` (route through the opener + alert).

---

## Medium Priority (Architecture Improvement)

### ViewModel Migration to @Observable

- [x] `UserPreferencesViewModel` — done
- [x] `SettingsViewModel` — done (extracted `CLLocationManagerDelegate` into `SettingsLocationDelegate`)
- [x] `LocationPickerViewModel` — done (extracted delegates into `LocationPickerDelegate`)
- Defer: `DashboardViewModel`, `WeatherViewModel`, `OnboardingCoordinator` (Combine-heavy)

### Dependency Injection

- [x] `WeatherProviding` protocol
- [x] `LocationManaging` protocol
- [x] `SettingsOpening` protocol
- [ ] `NotificationPermissionProviding` protocol
- [ ] `AppContainer` composition root (after protocols are complete)

### File Organization

Continue splitting large files (one primary type per file):
- [ ] `StreamlinedReminderCreationView.swift`
- [ ] Long settings/privacy views
- [ ] Remaining dashboard sections in `DashboardView.swift`

### Presentation State

- [ ] Replace remaining ad hoc alert booleans with typed alert state where conflicts are possible

---

## Low Priority (Post-Launch / Nice-to-Have)

### Design Tokens

- [ ] Create a small design token namespace for spacing, corner radii, card padding, animation durations, and glass tint strength

### Font Wrapper Cleanup

- [x] Renamed `AppFont.inter()` to `AppFont.system()` (legacy naming resolved)
- [ ] Prefer direct semantic styles (`.headline`, `.body`) in new code (137 `AppFontStyle` usages remain — low priority)

### Performance Profiling

- [ ] Profile dashboard scroll, reminder creation, weather refresh, and onboarding with Instruments
- [ ] Remove render-time filtering/sorting/formatting from large view bodies

### Additional Targets

- [ ] WidgetKit target (if desired) — reuse `NextReadyReminderSnapshot` and `NextReadyReminderCompactView`
- [ ] watchOS target (if desired) — same compact view contract
- [ ] CloudKit sync re-enablement (prepared in code, needs provisioning)

---

## Completed (Reference)

<details>
<summary>Product Simplification</summary>

- [x] Simplified app concept around weather-triggered reminders
- [x] Made `StreamlinedReminderCreationView` the normal creation UI
- [x] Removed comprehensive creation from normal navigation
- [x] Removed color/icon pickers from main creation flow
- [x] Added activity-based icon/color defaults
- [x] Focused notification settings on enabled state, quiet hours, daily maximum
- [x] Hid advanced notification controls from simplified settings
- [x] Reduced onboarding animation staging
- [x] Kept location/notification permissions on dedicated onboarding pages
- [x] Replaced old FAB with `GlassCreateTaskButton`

</details>

<details>
<summary>UI and HIG Cleanup</summary>

- [x] Converted primary empty states to `ContentUnavailableView` (7 usages across 5 files)
- [x] Removed unused custom `EmptyStateView`
- [x] Migrated all views from `NavigationView` to `NavigationStack`
- [x] Converted all `onTapGesture` row actions to explicit controls
- [x] Replaced major multi-sheet booleans with item-driven sheets
- [x] Converted `MainTabView` tab selection to enum
- [x] Replaced splash/tutorial/welcome delayed dispatches with cancellable `.task` flows
- [x] Removed global Inter/custom display typography for system text styles
- [x] Removed all `Inter-` and `SF Pro Display` custom font references

</details>

<details>
<summary>Architecture and Testing</summary>

- [x] Centralized support/privacy/terms values in `AppSupportLinks`
- [x] Added `NextReadyReminderSnapshot` + `NextReadyReminderCompactView`
- [x] Added Swift Testing coverage for activity defaults and next-ready selection
- [x] Split dashboard support cards/forecast rows into `DashboardComponents.swift`
- [x] Split weather condition display mapping from `WeatherViewModel`
- [x] Removed dead commented legacy code from `WeatherViewModel`
- [x] Added `WeatherProviding`, `LocationManaging`, `SettingsOpening` protocols with tests
- [x] Migrated `UserPreferencesViewModel` to `@Observable`
- [x] Split location, reminder, settings sub-views into focused files
- [x] Moved forecast UI from `Services/Weather/` into `Views/Weather/Forecast/`

</details>

<details>
<summary>Concurrency and Background Tasks (June 5, 2026)</summary>

- [x] Replaced all 10 `DispatchQueue.main.asyncAfter` calls in production code with cancellable `Task.sleep`
  - `CelebrationView.swift` (3 calls — celebration animation sequence)
  - `DetailedReminderView.swift` (3 calls — edit mode transitions)
  - `ManualLocationEntryView.swift` (2 calls — focus delay and search debounce)
  - `ComprehensiveReminderCreationViewModel.swift` (1 call — clear parsed info)
- [x] Replaced `DispatchWorkItem` debounce in `ManualLocationEntryView` with `Task`-based cancellation
- [x] Fixed `Info.plist`: added `BGTaskSchedulerPermittedIdentifiers` and `fetch` background mode
- [x] Injected shared `ModelContainer` into `BackgroundWeatherManager` and `TriggerEngineManager` from app entry point
- [x] Fixed background task expiration handler race condition (was calling `setTaskCompleted` twice)
- [x] Deleted 3 completed/redundant planning documents (`FONT_CUSTOMIZATION_PLAN.md`, `ARCHITECTURE_AUDIT_PLAN.md`, `HIG_DESIGN_PERFORMANCE_AUDIT_PLAN.md`)
- [x] Migrated all 23 `.regularMaterial` surfaces to `.glassEffect()` across 10 files
- [x] Confirmed zero analytics/tracking SDKs — no ATT framework needed
- [x] Confirmed offline error handling exists (dashboard shows "Weather unavailable" card with error message)
- [x] Migrated `SettingsViewModel` to `@Observable` (extracted `CLLocationManagerDelegate` into helper)
- [x] Migrated `LocationPickerViewModel` to `@Observable` (extracted delegates into helper)
- [x] Renamed `AppFont.inter()` to `AppFont.system()` across all call sites
- [x] Added VoiceOver labels to icon-only buttons (edit, more options, sort, create, location actions)
- [x] Fixed SavedLocationCard ellipsis hit target to 44x44pt minimum

</details>

<details>
<summary>Test Coverage Expansion (June 5, 2026)</summary>

New Swift Testing suites added for previously untested core logic:
- [x] `WeatherReminderTests.swift` — reminder lifecycle: `isCurrentlyActive` (snooze/scheduled dates/max triggers), `canTrigger` cooldown gating, `statusText` state machine, `displayTitle`/`shortDescription`, and trigger/complete/snooze/skip/pause/resume mutations + history entries
- [x] `ReminderPriorityTests` — priority `sortOrder` ranking and sorting
- [x] `UserPreferencesTests.swift` — activity interest add/remove/toggle/idempotency, quiet hours description, timestamp bookkeeping
- [x] `SettingsEnumsTests.swift` — `NotificationTiming` lead intervals (parameterized) + monotonicity, `TemperatureUnit` symbols/names/round-trip (parameterized)

Known remaining test gaps (pre-existing XCTest files, lower priority):
- `SunHatTests.swift` contains Xcode boilerplate (`testExample`, empty `testPerformanceExample` measure block, `XCTAssertNotNil` on non-optionals) that adds noise without value — candidate for removal/migration to Swift Testing

</details>

<details>
<summary>Create Button + Live Weather (June 6, 2026)</summary>

- [x] Replaced the bottom-accessory / over-content create button with a native `Tab(role: .search)` detached glass button (Apple Music search-slot style), intercepted via a custom selection `Binding` to open the create sheet without switching tabs. Verified on simulator (opens from Home and Reminders, first tap, no stray tab switch). Deleted dead `GlassCreateTaskButton.swift` + `CreateTaskFloatingButton.swift`.
- [x] Wired the create sheet's "Current Location" card to live `WeatherService` data (real temp/feels-like/condition in the user's unit; loading / real / "Weather unavailable" states). Removed hardcoded `74° / Light Rain / Feels like 71°`.
- [x] Wired the forecast/likelihood path to live WeatherKit via a single `loadWeather()` call; deleted `generateEnhancedMockForecast`/`getCurrentSeasonalBaseTemp`/`getRealisticWeatherCondition` and the `fetchRealWeatherForecast` stub — no fabricated data, empty/unavailable on failure.
- [x] Wired daily `precipitationAmount` to real `DayWeather.precipitationAmount` (was hardcoded 0.0).
- [x] Deleted the unreachable comprehensive creation flow (`ComprehensiveReminderCreationView` + VM, ~31 KB) and unused `RealTimeWeatherCard` — removing the last mock-weather generators; extracted shared `SectionHeaderView` to its own file first.
- [x] Added Swift Testing: `ForecastMappingTests` (condition mapping parameterized over all 13 `WeatherCondition` cases, temp rounding, 7-day cap, empty input), Codable round-trip for `NextReadyReminderSnapshot`, and a no-fabrication contract test for `loadWeather()`.
- All active weather surfaces (Dashboard, WeatherView, DetailedReminderView, create sheet) now use live data.

</details>
