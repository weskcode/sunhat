# SunHat Architecture Audit Plan

## Architecture Fit

**MVVM: fit.**

- SunHat is already a SwiftUI + MVVM app, so improving boundaries incrementally is lower risk than introducing TCA, VIPER, or a full Clean Architecture rewrite.
- The main issue is not the selected pattern; it is boundary drift. Several files mix view rendering, view-model state, service work, helper models, and navigation.

## Current Architecture

- UI stack: SwiftUI, with some UIKit system APIs used for app settings, mail links, background tasks, and notifications.
- Presentation: mostly `View` + `ObservableObject` ViewModel.
- Persistence: SwiftData models under `Models/`.
- Side effects: weather, location, background tasks, trigger evaluation, notifications, and settings actions live under `Services/` and `ViewModels/`.
- Navigation: currently mixed. Some screens use `NavigationStack`, while remaining legacy sheets still use `NavigationView` and old toolbar placements.
- Async model: mixed `async`/`await`, Combine, `Task`, and remaining `DispatchQueue.main.asyncAfter` in animation and delayed UI flows.

## Current Verification

- Unit tests: `SunHatTests` passed on the existing configured iPhone 17 Pro simulator (`127 passed, 0 failed`) on June 2, 2026.
- UI tests: not rerun after the latest changes. Swift Testing does not support UI tests, and the previous UI-test runner timed out in Xcode launch setup.
- Simulator policy: use the single configured simulator only; avoid cloning or launching extra simulators for routine validation.

## Anti-Patterns Found

1. **Views in service folders**
   - `Services/Weather/WeatherForecastIntegration.swift` contained SwiftUI views, preview code, and UI-only data.
   - Fix: moved these types into `Views/Weather/Forecast/`.

2. **Multiple responsibilities per file**
   - `LocationPickerView.swift` contained the screen, row view, ViewModel, CLLocation delegate, and MKLocalSearch delegate.
   - `SettingsSubViews.swift` contained unrelated settings modal screens plus a helper model.
   - Fix: split these into one primary type per file.

3. **Service and ViewModel singleton coupling**
   - Managers still use `shared` singletons and some direct service references.
   - Recommended direction: introduce protocol-based dependencies in ViewModels first, then move app wiring into a composition root.

4. **Boolean presentation state**
   - Settings and creation flows have many independent booleans for sheets and alerts.
   - Recommended direction: replace with `enum ActiveSheet: Identifiable` and `enum ActiveAlert`.

5. **Mixed async orchestration**
   - Some delayed work now uses cancellable tasks, but onboarding and animation flows still use `DispatchQueue.main.asyncAfter`.
   - Recommended direction: move UI delays to `.task`, store task handles where cancellation matters, and ignore cancellation explicitly.

6. **Large ViewModels and large view files**
   - High-risk areas include `WeatherViewModel.swift`, `DashboardView.swift`, `StreamlinedReminderCreationView.swift`, `Views/Reminders/Creation/`, and `Views/Location/`.
   - Recommended direction: extract ViewData, state enums, subviews, and service protocols before changing behavior.

## Files Cleaned Up In This Pass

### Location

- `Views/Location/LocationPickerView.swift`
  - Now owns only the picker screen and view-local state.
- `Views/Location/LocationResultRow.swift`
  - Extracted row rendering.
- `ViewModels/LocationPickerViewModel.swift`
  - Extracted search/location state and async MapKit resolution.

### Weather Forecast UI

- Removed `Services/Weather/WeatherForecastIntegration.swift`.
- Added:
  - `Views/Weather/Forecast/CurrentWeatherData.swift`
  - `Views/Weather/Forecast/RealTimeWeatherCard.swift`
  - `Views/Weather/Forecast/TriggerStatusIndicator.swift`
  - `Views/Weather/Forecast/ForecastTimelineView.swift`
  - `Views/Weather/Forecast/ForecastDayCard.swift`
  - `Views/Weather/Forecast/DayDetailsCard.swift`
  - `Views/Weather/Forecast/DetailedForecastView.swift`
  - `Views/Weather/Forecast/DetailedDayCard.swift`

### Settings

- Removed `Views/Settings/SettingsSubViews.swift`.
- Added:
  - `Views/Settings/PrivacyPolicyView.swift`
  - `Views/Settings/DataAnalyticsView.swift`
  - `Views/Settings/AboutView.swift`
  - `Views/Settings/FAQItem.swift`
  - `Views/Settings/HelpFAQView.swift`

### Reminders

- Made `StreamlinedReminderCreationView` the normal creation flow.
- Removed comprehensive creation from standard navigation.
- Removed color/icon picker UI from the main creation path.
- Added activity-based appearance defaults in `FirstReminderCreationViewModel`.
- Split reminder management, detail, and first-creation components into focused feature files.

### Shared Compact Surfaces

- Added `Models/NextReadyReminderSnapshot.swift`.
- Added `Views/Components/NextReadyReminderCompactView.swift`.
- These are intentionally minimal so future WidgetKit/watchOS targets can show only the next ready reminder or one unavailable state.

## Target Structure

Prefer feature slices inside the existing app layout:

```text
SunHat/
  Models/
  Services/
    Weather/
    Location/
    Trigger/
    Background/
  ViewModels/
    Settings/
    LocationPickerViewModel.swift
  Views/
    Dashboard/
    Location/
    Onboarding/
    Reminders/
    Settings/
    Weather/
      Forecast/
  Utilities/
```

Longer term, move toward:

```text
SunHat/
  App/
    AppContainer.swift
    AppRouter.swift
  Features/
    Dashboard/
    Location/
    Onboarding/
    Reminders/
    Settings/
    Weather/
  Domain/
    Entities/
    UseCases/
  Data/
    Weather/
    Location/
    Persistence/
```

Do not jump to the long-term structure in one commit. Move feature-by-feature after dependencies are explicit.

## Refactor Sequence

1. **Finish type-per-file cleanup**
   - [x] Split `LocationManagementComponents.swift`.
   - [x] Split `ReminderManagementComponents.swift`.
   - [x] Split `DetailedReminderComponents.swift`.
   - [x] Split `FirstReminderCreationComponents.swift`.
   - [ ] Continue with remaining large files: `DashboardView.swift`, `WeatherViewModel.swift`, `StreamlinedReminderCreationView.swift`, and long settings/privacy views.

2. **Make presentation state explicit**
   - [ ] Replace multi-boolean sheets in settings/reminder creation with `ActiveSheet`.
   - [ ] Replace ad hoc alerts with typed alert state.

3. **Extract ViewData from large ViewModels**
   - [ ] Start with `WeatherViewModel`.
   - [ ] Move display strings and metric presentation into value structs.
   - [ ] Keep raw weather data and business rules out of view bodies.

4. **Introduce dependency protocols at ViewModel boundaries**
   - [ ] `WeatherProviding`
   - [ ] `LocationProviding`
   - [ ] `NotificationPermissionProviding`
   - [ ] `SettingsOpening`
   - [ ] Keep live implementations in services.

5. **Add a composition root**
   - [ ] Add `AppContainer` to build shared services and ViewModels.
   - [ ] Stop creating service singletons from leaf views.

6. **Move low-risk ViewModels to Observation**
   - [ ] Start with `UserPreferencesViewModel`, `SettingsViewModel`, and `LocationPickerViewModel`.
   - [ ] Keep Combine-heavy services on `ObservableObject` until their dependencies are isolated.

7. **Performance pass**
   - [ ] Remove filtering/sorting/formatting from large view bodies.
   - [ ] Replace remaining delayed `DispatchQueue` animation flows with cancellable task-based state.
   - [ ] Use Instruments on dashboard scrolling, reminder creation, weather refresh, and onboarding.

## Product Scope Cleanup From Recent Chat

Completed:

- [x] Keep only the streamlined reminder creator in normal navigation.
- [x] Remove color/icon picker from the main creation flow.
- [x] Use activity-based icon/color defaults.
- [x] Keep notification settings focused on enabled state, quiet hours, and daily maximum.
- [x] Reduce onboarding animation staging.
- [x] Replace the old FAB with a Liquid Glass create button.
- [x] Convert primary empty states to `ContentUnavailableView`.
- [x] Move global typography back to native system text styles.
- [x] Add Swift Testing coverage for activity defaults and the compact next-ready selector.

Circle back:

- [ ] Add real WidgetKit and watchOS targets if still desired. The app currently has shared compact snapshot/view code, not separate targets.
- [ ] Run a visual QA pass for onboarding, empty states, and create-task placement on the single configured simulator.
- [ ] Run UI smoke tests only after the UI-test runner is stable on that simulator.
- [ ] Replace placeholder privacy/support/contact URLs.
- [ ] Finish dependency injection cleanup and `@Observable` migration.

## Testing Strategy

- Add ViewModel tests around state transitions:
  - success
  - failure
  - cancellation/no stale overwrite
- Stub service protocols instead of relying on singletons.
- Add focused UI smoke tests only for navigation and critical onboarding/reminder flows.
- Keep using Swift Testing for new unit/integration tests.
- UI tests must remain XCTest-based because Swift Testing does not support UI tests.
- Unit verification is currently passing; UI smoke verification still needs a stable single-simulator run.

## Architecture PR Checklist

- View does not call services directly.
- ViewModel owns explicit state and user intents.
- ViewModel dependencies are injected behind protocols when side effects are involved.
- Async tasks are cancellable or intentionally fire-and-forget.
- Domain models do not import SwiftUI unless they are truly presentation-only data.
- Feature view files contain one primary type when practical.
- Navigation destinations and sheets are modeled as value state, not many booleans.
- New files are placed under the owning feature folder, not a generic catch-all.

## Execution Notes

Completed cleanup batches:

- Split `LocationPickerView.swift` into the view plus `LocationPickerViewModel` and `LocationResultRow`.
- Moved forecast UI from `Services/Weather/WeatherForecastIntegration.swift` into `Views/Weather/Forecast/`.
- Split settings subviews into focused settings files.
- Split `LocationManagementComponents.swift` into focused location feature files.
- Split `ReminderManagementComponents.swift` into `Views/Reminders/Management/`.
- Split `DetailedReminderComponents.swift` into `Views/Reminders/Detail/`.
- Split `FirstReminderCreationComponents.swift` into `Views/Reminders/Creation/`.
- Simplified creation/navigation scope around the streamlined reminder creator.
- Added minimal compact reminder snapshot/view support for future widget/watch surfaces.

Verification:

- Simulator build passed after the detailed-reminder split with zero warnings.
- Simulator build passed after the first-reminder creation split with zero warnings.
- `SunHatTests` passed after the product simplification and compact-surface tests: `127 passed, 0 failed`.
