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
   - High-risk files include `WeatherViewModel.swift`, `DashboardView.swift`, `StreamlinedReminderCreationView.swift`, `FirstReminderCreationComponents.swift`, and `LocationManagementComponents.swift`.
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
   - Split `LocationManagementComponents.swift`.
   - Split `ReminderManagementComponents.swift`.
   - Split `DetailedReminderComponents.swift`.
   - Split `FirstReminderCreationComponents.swift`.

2. **Make presentation state explicit**
   - Replace multi-boolean sheets in settings/reminder creation with `ActiveSheet`.
   - Replace ad hoc alerts with typed alert state.

3. **Extract ViewData from large ViewModels**
   - Start with `WeatherViewModel`.
   - Move display strings and metric presentation into value structs.
   - Keep raw weather data and business rules out of view bodies.

4. **Introduce dependency protocols at ViewModel boundaries**
   - `WeatherProviding`
   - `LocationProviding`
   - `NotificationPermissionProviding`
   - `SettingsOpening`
   - Keep live implementations in services.

5. **Add a composition root**
   - Add `AppContainer` to build shared services and ViewModels.
   - Stop creating service singletons from leaf views.

6. **Move low-risk ViewModels to Observation**
   - Start with `UserPreferencesViewModel`, `SettingsViewModel`, and `LocationPickerViewModel`.
   - Keep Combine-heavy services on `ObservableObject` until their dependencies are isolated.

7. **Performance pass**
   - Remove filtering/sorting/formatting from large view bodies.
   - Replace remaining delayed `DispatchQueue` animation flows with cancellable task-based state.
   - Use Instruments on dashboard scrolling, reminder creation, weather refresh, and onboarding.

## Testing Strategy

- Add ViewModel tests around state transitions:
  - success
  - failure
  - cancellation/no stale overwrite
- Stub service protocols instead of relying on singletons.
- Add focused UI smoke tests only for navigation and critical onboarding/reminder flows.
- Keep XCTest verification blocked until simulator launch instability is resolved.

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

Verification:

- Simulator build passed after the detailed-reminder split with zero warnings.
- Simulator build passed after the first-reminder creation split with zero warnings.
