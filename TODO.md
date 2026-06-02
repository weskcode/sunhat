# SunHat TODO

Last updated: June 2, 2026

## Current Verification

- [x] Compile-only simulator build passed on the existing `iPhone 17 Pro` simulator (`C3E7115C-C029-4352-A255-EFB6CB69367A`) with no warnings or errors.
- [x] `SunHatTests` passed on the same simulator: `131 passed, 0 failed`.
- [ ] UI smoke tests still need a stable XCTest run on the same simulator.
- [ ] Visual QA still needs to be performed on the same simulator.

Do not clone or repeatedly launch additional simulators for routine validation.

## Completed Product Simplification

- [x] Simplified the app concept around weather-triggered reminders.
- [x] Made `StreamlinedReminderCreationView` the normal creation UI.
- [x] Removed comprehensive creation from normal navigation.
- [x] Removed color/icon pickers from the main creation flow.
- [x] Added activity-based icon/color defaults.
- [x] Focused notification settings on enabled state, quiet hours, and daily maximum.
- [x] Hid advanced notification controls such as sounds, vibration patterns, grouping, and critical alerts from the simplified settings flow.
- [x] Reduced onboarding animation staging.
- [x] Kept location and notification permission requests on dedicated explanatory onboarding pages.
- [x] Replaced the old create-task FAB with `GlassCreateTaskButton`.

## Completed UI And HIG Cleanup

- [x] Converted primary reminder/location/weather-alert empty states to `ContentUnavailableView`.
- [x] Removed the unused custom `EmptyStateView`.
- [x] Migrated all `SunHat/Views` usage from `NavigationView` and old toolbar placements to `NavigationStack` and modern toolbar placements.
- [x] Converted `onTapGesture` row actions in `SunHat/Views` to explicit controls.
- [x] Replaced major multi-sheet boolean presentation state with item-driven sheets in settings, location, dashboard, reminder management, reminder detail, and privacy screens.
- [x] Cleaned up remaining creation/location sheet booleans in all reminders, weather, and retired comprehensive creation screens.
- [x] Converted `MainTabView` tab selection from integer tags to an enum.
- [x] Replaced splash and tutorial hint delayed `DispatchQueue.main.asyncAfter` flows with cancellable `.task` flows.

## Completed Architecture And Testing Cleanup

- [x] Replaced scattered placeholder support/privacy/terms values with centralized `AppSupportLinks`.
- [x] Retired global Inter/custom display typography in favor of native system text styles.
- [x] Added compact next-ready reminder snapshot/view support for future widget/watch surfaces.
- [x] Added Swift Testing coverage for activity defaults and next-ready reminder selection.
- [x] Split dashboard support cards and forecast rows out of `DashboardView.swift`.
- [x] Split `WeatherCondition` display mapping and location dependency adapters out of `WeatherViewModel.swift`.
- [x] Removed dead commented legacy implementation from `WeatherViewModel.swift`.
- [x] Added `WeatherProviding` and `SettingsOpening` dependency protocols.
- [x] Added Swift Testing coverage for `WeatherProviding` and `SettingsOpening`.
- [x] Migrated `UserPreferencesViewModel` from `ObservableObject`/`@Published` to `@Observable`.

## Highest Priority Next

- [ ] Run a visual QA pass for onboarding, empty states, and create-task placement on the existing configured simulator.
- [ ] Run UI smoke tests only when the XCTest UI runner is stable on that simulator.
- [ ] Confirm ownership and final production values for `sunhat.app`, support email, feedback email, and privacy email before App Store submission.
- [ ] Audit background task configuration:
  - Confirm `BGTaskSchedulerPermittedIdentifiers` includes weather refresh and trigger evaluation identifiers.
  - Inject the app `ModelContainer` into background managers instead of creating ad hoc containers in background code.
  - Add tests for duplicate registration, unavailable background refresh, and notification deduplication.

## Architecture Backlog

- [ ] Add an app composition root (`AppContainer`) after remaining dependencies are explicit.
- [ ] Continue ViewModel dependency protocols:
  - [x] `WeatherProviding`
  - [x] `LocationManaging`
  - [x] `SettingsOpening`
  - [ ] `NotificationPermissionProviding`
- [ ] Continue migrating low-risk ViewModels to `@Observable`:
  - [x] `UserPreferencesViewModel`
  - [ ] `SettingsViewModel`
  - [ ] `LocationPickerViewModel`
- [ ] Continue splitting large files, especially remaining dashboard sections, `StreamlinedReminderCreationView.swift`, and long settings/privacy views.
- [ ] Replace remaining ad hoc alert booleans with typed alert state where multiple alerts or selected model state can conflict.

## Design, Accessibility, And Performance Backlog

- [ ] Standardize spacing, corner radii, card padding, animation durations, and glass tint strength in a small design token namespace.
- [ ] Continue migrating legacy `.regularMaterial` surfaces to deliberate Liquid Glass treatment when editing each owning screen.
- [ ] Audit Dynamic Type, Reduce Motion, hit targets, and VoiceOver labels across all primary screens.
- [ ] Replace remaining non-cancellable delayed UI work with `.task`, `Task.sleep(for:)`, and cancellation-aware state.
- [ ] Remove render-time derived filtering/sorting/formatting from large view bodies.
- [ ] Profile dashboard scrolling, reminder creation, weather refresh, and onboarding before deeper visual redesign.

## Product Scope Decisions

- [ ] Add actual WidgetKit and watchOS targets only if they are still in scope.
  - Keep them minimal: next ready reminder plus an unavailable state.
  - Reuse `NextReadyReminderSnapshot` and `NextReadyReminderCompactView`.
  - The current project tree has shared compact code only; no widget/watch targets are present.
- [ ] Re-enable CloudKit sync only after provisioning and release-readiness review.
