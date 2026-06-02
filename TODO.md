# SunHat TODO

Last updated: June 2, 2026

## Completed From Recent Chat

- [x] Review app concept and simplify the product around weather-triggered reminders.
- [x] Make `StreamlinedReminderCreationView` the normal creation UI.
- [x] Remove comprehensive creation from normal navigation.
- [x] Remove color/icon pickers from the main creation flow.
- [x] Add activity-based icon/color defaults.
- [x] Keep notification settings focused on enabled state, quiet hours, and daily maximum.
- [x] Hide advanced notification controls such as sounds, vibration patterns, grouping, and critical alerts from the simplified settings flow.
- [x] Reduce onboarding animation staging.
- [x] Keep location permission and notification permission on dedicated onboarding pages with explanatory copy.
- [x] Replace the old create-task FAB with a Liquid Glass create button.
- [x] Convert primary reminder/location/weather-alert empty states to `ContentUnavailableView`.
- [x] Remove the unused custom `EmptyStateView` after migrating primary empty states.
- [x] Migrate `DataPrivacyView` from `NavigationView` to `NavigationStack`.
- [x] Migrate `PrivacyContactView` from `NavigationView` to `NavigationStack`.
- [x] Migrate `DataExportOptionsView` from `NavigationView` to `NavigationStack`.
- [x] Retire global Inter/custom display typography in favor of native system text styles.
- [x] Add compact next-ready reminder snapshot/view support for future widget/watch surfaces.
- [x] Add Swift Testing coverage for activity defaults and next-ready reminder selection.
- [x] Run `SunHatTests` on the single configured simulator: `127 passed, 0 failed`.

## Circle Back

- [ ] Add actual WidgetKit and watchOS targets if they are still in scope.
  - Keep them minimal: next ready reminder plus an unavailable state.
  - Reuse `NextReadyReminderSnapshot` and `NextReadyReminderCompactView`.
- [ ] Run a visual QA pass for onboarding, empty states, and create-task placement on the single configured simulator.
- [ ] Run UI smoke tests only when the XCTest UI runner is stable on the existing configured simulator.
- [ ] Replace placeholder production support, privacy, and terms URLs.
- [ ] Finish remaining `NavigationView` to `NavigationStack` migration.
- [ ] Convert remaining tap-gesture rows to real `Button` controls.
- [ ] Replace boolean-heavy sheet/alert state with item-driven presentation.
- [ ] Continue splitting large files, especially `DashboardView.swift`, `WeatherViewModel.swift`, and `StreamlinedReminderCreationView.swift`.
- [ ] Introduce ViewModel dependency protocols and an app composition root.
- [ ] Migrate low-risk ViewModels to `@Observable`.
- [ ] Audit Dynamic Type, Reduce Motion, hit targets, and VoiceOver labels across all primary screens.
- [ ] Profile dashboard scrolling, reminder creation, weather refresh, and onboarding before deeper visual redesign.

## Verification Notes

- Use the existing configured simulator only: `iPhone 17 Pro` (`C3E7115C-C029-4352-A255-EFB6CB69367A`).
- Do not clone additional simulators for routine validation.
- Swift Testing covers unit/integration tests only. UI tests must remain XCTest-based.
