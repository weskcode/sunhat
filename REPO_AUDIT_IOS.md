# SunHat iOS Repository Audit

Audit date: July 7, 2026
Scope: static full-repo architecture/code review plus local build and unit-test verification.
App identity: SunHat is a location-aware, weather-triggered reminder app. The primary loop is: create a weather task -> monitor forecast/current conditions -> evaluate triggers -> deliver a notification when conditions match.

Verification performed during this audit:
- `xcodebuild -list -project SunHat.xcodeproj`: targets are `SunHat`, `SunHatTests`, and `SunHatUITests`; schemes are `SunHat` and `SunHatUnitTests`.
- `xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -configuration Debug build`: passed with no `warning:` or `error:` lines in `/tmp/sunhat_audit_build.log`.
- `xcodebuild -scheme SunHatUnitTests -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' test`: passed, 231 tests in 48 suites.
- UI tests and physical-device background notification delivery were not run during this audit.

Apple platform references checked for July 2026 modernization context:
- Apple SwiftUI updates page: https://developer.apple.com/documentation/updates/swiftui
- Apple Liquid Glass overview: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- Apple WWDC25 "Build a SwiftUI app with the new design": https://developer.apple.com/videos/play/wwdc2025/323/

## 1. Executive Summary

SunHat is built as a modern SwiftUI + SwiftData app targeting iOS 26.4 with Swift 6.2. The code already uses several current platform patterns: `@main App` lifecycle, SwiftData in an App Group container, WeatherKit, App Intents, Core Spotlight indexing, Swift Testing, iOS 26 `Tab` API, `tabBarMinimizeBehavior`, and Liquid Glass surfaces.

The highest-value product path is still not fully proven locally: background weather monitoring and notification delivery can be build/test verified, but the actual BGTaskScheduler-to-notification loop requires hardware verification. The repo itself documents that device verification remains pending in `TODO.md:30`.

The architecture is mostly MVVM with services and protocol seams added over time. It is pragmatic and testable in several important places (`WeatherProviding`, `LocationManaging`, `SettingsOpening`, `NotificationPermissionProviding`), but there are still duplicate or partially overlapping paths for weather evaluation, forecast display, and background trigger notification.

Top risks:

1. **High - Weather tab can display fabricated weekly forecast values.** `WeatherModelActor.fetchForecastData` returns `[]` at `SunHat/Services/Data/WeatherModelActor.swift:60-66`, then `WeatherViewModel.loadWeekly` fills seven days with `Double.random` and `Int.random` at `SunHat/ViewModels/WeatherViewModel.swift:249-292`.
2. **High - Background notification ownership is split across two managers.** `BackgroundWeatherManager` registers `org.wesley.sunhat.weather-refresh` at `SunHat/Services/Weather/BackgroundWeatherManager.swift:42-65` and evaluates/sends notifications at `SunHat/Services/Weather/BackgroundWeatherManager.swift:101-244`; `TriggerEngineManager` separately registers `org.wesley.sunhat.trigger-evaluation` at `SunHat/Services/Trigger/TriggerEngineManager.swift:104-164` and can also send trigger notifications at `SunHat/Services/Trigger/TriggerEngineManager.swift:168-256`.
3. **High - Weather service actor is annotated `@MainActor`, so network/cache work is not isolated away from UI.** `WeatherServiceActor` is declared `@MainActor` at `SunHat/Services/Weather/WeatherService.swift:97-104`, performs provider fetches and SwiftData cache scans at `SunHat/Services/Weather/WeatherService.swift:132-242`, and fetches all cached weather rows before filtering in memory at `SunHat/Services/Weather/WeatherService.swift:205-236`.
4. **Medium - SwiftData forecast/history reads use broad fetches and manual filtering.** Weather cache lookup fetches all `WeatherData` rows at `SunHat/Services/Weather/WeatherService.swift:212-236`; historical lookup fetches all weather rows and filters by coordinates/date in memory at `SunHat/Services/Data/WeatherModelActor.swift:117-139`.
5. **Medium - The app targets iOS 26.4 but still has older imperative haptic calls in SwiftUI flows.** Examples include `UINotificationFeedbackGenerator` in `SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:210-218` and `UIImpactFeedbackGenerator` in onboarding/location flows surfaced by search.
6. **Medium - App Intents handoff is app-opening only, not direct data actions.** Intents store a pending destination in App Group defaults at `SunHat/AppIntents/SunHatShortcuts.swift:56-103` and `SunHat/Services/Routing/SunHatIntentHandoff.swift:18-40`; no intent creates, pauses, or completes a reminder in the data layer.
7. **Medium - Privacy export is useful but manual dictionary/CSV generation is fragile.** Export code hand-builds JSON and CSV at `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:210-310`; it is easy for fields to drift from SwiftData models.
8. **Low - Several docs are stale relative to current source.** `IMPROVEMENT_PLAN.md:42` says foreground trigger persistence is pending, but `TriggerEngineManager.updateReminderWithResult` now calls `reminder.trigger()` and saves at `SunHat/Services/Trigger/TriggerEngineManager.swift:235-255`.

## 2. Repo Inventory (iOS-focused)

Project structure:
- Direct Xcode project: `SunHat.xcodeproj`.
- Workspace wrapper: `SunHat.xcodeproj/project.xcworkspace/contents.xcworkspacedata`.
- Targets: `SunHat`, `SunHatTests`, `SunHatUITests`.
- Shared schemes: `SunHat`, `SunHatUnitTests`.
- Build configurations: `Debug`, `Release`.
- Swift files: 179.
- Swift LOC: about 38,265.
- Metal files: none.
- Dependency manager: no `Package.swift`, `Podfile`, `Cartfile`, or CI workflow found in the repo scan.

Build settings and deployment:
- App deployment target is iOS 26.4 at `SunHat.xcodeproj/project.pbxproj:327` and `SunHat.xcodeproj/project.pbxproj:364`.
- App Swift version is 6.2 at `SunHat.xcodeproj/project.pbxproj:339` and `SunHat.xcodeproj/project.pbxproj:376`.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` is enabled at `SunHat.xcodeproj/project.pbxproj:338` and `SunHat.xcodeproj/project.pbxproj:375`.
- App bundle ID is `org.wesley.sunhat` at `SunHat.xcodeproj/project.pbxproj:333` and `SunHat.xcodeproj/project.pbxproj:370`.
- App version is `MARKETING_VERSION = 1.0`; current project version is `5` at `SunHat.xcodeproj/project.pbxproj:316-333`.
- Release build-number script increments `buildnumber.txt` and writes `CFBundleVersion` into the built product at `SunHat.xcodeproj/project.pbxproj:87-107`.

Capabilities and configuration:
- WeatherKit entitlement is present in `SunHat/SunHat.entitlements`.
- App Group entitlement is `group.org.wesley.sunhat` in `SunHat/SunHat.entitlements`.
- Background modes include `fetch`; permitted identifiers are `org.wesley.sunhat.weather-refresh` and `org.wesley.sunhat.trigger-evaluation` in `SunHat/Info.plist`.
- Location purpose strings include When In Use, Always, temporary accuracy, and accuracy authorization in `SunHat/Info.plist`.
- Privacy manifest declares location collection for app functionality, no tracking, and UserDefaults accessed API reason `CA92.1` in `SunHat/PrivacyInfo.xcprivacy`.

Framework usage:
- SwiftUI for all primary UI surfaces.
- UIKit only where platform integration is needed: app delegate, notifications, opening settings, review prompt, share sheet, haptics.
- SwiftData for persistence.
- WeatherKit primary weather provider.
- URLSession backup OpenWeatherMap provider, but it is only enabled if an API key is supplied.
- BackgroundTasks for weather refresh and trigger evaluation.
- UserNotifications for notification categories, delivery, and actions.
- AppIntents for shortcuts.
- CoreSpotlight for searchable reminders/locations.
- MapKit/CoreLocation for location search and permissions.

Localization:
- No `.strings`, `.stringsdict`, or `.xcstrings` files were found. User-facing strings are inline Swift literals.
- RTL and pluralization are not explicitly implemented beyond system controls.

Testing:
- Unit tests mix Swift Testing (`@Test`, `#expect`) and XCTest performance tests.
- UI tests are XCTest-based in `SunHatUITests`.
- Current unit verification: 231 tests passed.

## 3. Architecture & Data Flow

Text diagram:

```text
SunHatApp / AppDelegate
  -> SwiftData ModelContainer (App Group: group.org.wesley.sunhat)
  -> WeatherService.shared.configure(modelContainer:)
  -> TriggerEngineManager.shared.configure(modelContainer:)
  -> ContentView
      -> OnboardingContainerView until OnboardingCoordinator says complete
      -> MainTabView
          -> DashboardView / DashboardViewModel
          -> WeatherView / WeatherViewModel
          -> AllRemindersView
          -> SettingsView / SettingsViewModel
          -> StreamlinedReminderCreationView / FirstReminderCreationViewModel

Data layer
  -> SwiftData models: WeatherReminder, TriggerCondition, LocationData,
     WeatherData, ForecastDay, NotificationConfig, ReminderHistory,
     UserPreferences, SavedLocation, LocationHistory
  -> WeatherService + AppleWeatherKitAPI/OpenWeatherMapAPI
  -> WeatherModelActor DTOs for cross-actor model access

Background / system surfaces
  -> BackgroundWeatherManager: BGAppRefreshTask -> WeatherService -> reminder checks -> UNNotificationRequest
  -> TriggerEngineManager: BGAppRefreshTask/manual evaluation -> TriggerEngine -> TriggerNotificationManager
  -> App Intents -> App Group UserDefaults handoff -> MainTabView selection/create sheet
  -> Core Spotlight -> MainTabView onContinueUserActivity -> tab routing
```

Responsibilities:
- `SunHat/sunhat.swift`: app lifecycle, notification delegate, SwiftData container, store recovery, service configuration.
- `SunHat/Views/Dashboard/MainTabView.swift`: tab shell, create-sheet action, App Intent and Spotlight handoff, lifecycle prompts.
- `SunHat/Services/Weather/WeatherService.swift`: app-facing weather fetch facade, provider orchestration, rate limiting, cache writes.
- `SunHat/Services/Weather/WeatherAPI.swift`: WeatherKit and OpenWeatherMap provider adapters plus DTO mapping.
- `SunHat/Services/Weather/BackgroundWeatherManager.swift`: BG refresh scheduling, active reminder filtering, condition evaluation, direct notification sending.
- `SunHat/Services/Trigger/TriggerEngine.swift`: actor-based advanced trigger evaluation using Sendable DTOs.
- `SunHat/Services/Data/WeatherModelActor.swift`: SwiftData model actor and DTO conversion bridge.
- `SunHat/ViewModels/*`: MVVM state and UI orchestration.
- `SunHat/Services/Search/SunHatSearchIndexer.swift`: Core Spotlight indexing and destination mapping.
- `SunHat/AppIntents/SunHatShortcuts.swift`: Shortcuts surface and app-opening intents.

Key call flows:
- App launch: `SunHatApp.init` configures background/weather/trigger services at `SunHat/sunhat.swift:159-167`, then injects the model container at `SunHat/sunhat.swift:170-180`.
- Create reminder: `MainTabView` opens `StreamlinedReminderCreationView` at `SunHat/Views/Dashboard/MainTabView.swift:64-80`; the view calls `FirstReminderCreationViewModel.createReminder` at `SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:210-218`; the view model inserts `WeatherReminder`, `TriggerCondition`, and `LocationData` then indexes the reminder at `SunHat/ViewModels/FirstReminderCreationViewModel.swift:291-364`.
- Weather refresh: Dashboard/Weather tab calls `WeatherService.fetchCurrentWeather`; `WeatherServiceActor` checks cache, rate limits, calls providers, converts DTOs, and saves `WeatherData` at `SunHat/Services/Weather/WeatherService.swift:132-267`.
- Background notification: `BackgroundWeatherManager.handleBackgroundTask` calls `WeatherService.shared.handleBackgroundRefresh()` then `checkTriggeredConditions()` at `SunHat/Services/Weather/BackgroundWeatherManager.swift:101-123`.

## 4. What the App Does (User Workflows)

Primary workflow 1: create a weather-triggered task.
- Trigger: user taps the detached `New Task` tab/button.
- UI: `MainTabView` intercepts `.add` selection and presents `StreamlinedReminderCreationView` at `SunHat/Views/Dashboard/MainTabView.swift:27-80`.
- State: `FirstReminderCreationViewModel` owns title, notes, location, temperature range/exact condition, sky filters, current-weather card, and likelihood at `SunHat/ViewModels/FirstReminderCreationViewModel.swift:15-39`.
- Weather: `loadWeather` fetches live weather from `WeatherService` and maps forecast days at `SunHat/ViewModels/FirstReminderCreationViewModel.swift:145-180`.
- Persistence: `createReminder` inserts `WeatherReminder`, `TriggerCondition`, optional `LocationData`, saves the context, then indexes in Spotlight at `SunHat/ViewModels/FirstReminderCreationViewModel.swift:291-364`.
- Recovery: save failure deletes the unsaved reminder and surfaces `creationErrorMessage` at `SunHat/ViewModels/FirstReminderCreationViewModel.swift:351-360`, displayed by the view at `SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:99-109`.

Primary workflow 2: monitor weather and notify.
- Trigger: BGTaskScheduler launches `org.wesley.sunhat.weather-refresh`, or user triggers manual refresh.
- UI state: Dashboard shows current weather, active reminders, and "Next Ready" compact snapshot at `SunHat/Views/Dashboard/DashboardView.swift:38-75`.
- Services: `BackgroundWeatherManager` schedules/handles refresh at `SunHat/Services/Weather/BackgroundWeatherManager.swift:77-123`.
- Data: active reminders are filtered through `canTrigger` at `SunHat/Services/Weather/BackgroundWeatherManager.swift:148-180`.
- Weather evaluation: current weather is fetched and checked via `WeatherData.evaluateCondition` at `SunHat/Services/Weather/BackgroundWeatherManager.swift:192-205`.
- Notification: immediate `UNNotificationRequest` is created at `SunHat/Services/Weather/BackgroundWeatherManager.swift:207-244`.
- Persistence: `reminder.trigger(with:)` updates cooldown/history at `SunHat/Models/WeatherReminder.swift:239-261`; daily delivery count is recorded by `UserPreferences.recordNotificationDelivered` at `SunHat/Models/UserPreferences.swift:99-109`.

Primary workflow 3: inspect weather and readiness.
- Trigger: user opens Home or Weather tab.
- Dashboard: `DashboardViewModel.refreshWeatherData` obtains a current/manual location, fetches weather, loads reminders, computes local alerts at `SunHat/ViewModels/DashboardViewModel.swift:117-168` and `SunHat/ViewModels/DashboardViewModel.swift:402-473`.
- Weather tab: `WeatherViewModel.loadAllData` resolves location, fetches current weather, derives hourly/weekly/historical/trigger prediction sections at `SunHat/ViewModels/WeatherViewModel.swift:140-167`.
- Caveat: the Weather tab weekly path can fabricate fallback data when `WeatherModelActor.fetchForecastData` returns empty.

Secondary workflows:
- Onboarding and app state: `OnboardingCoordinator` persists completion and first-reminder state in `UserDefaults` at `SunHat/Services/Background/OnboardingCoordinator.swift:13-30`.
- Settings and preferences: `SettingsViewModel` loads/creates `UserPreferences` and writes notification, quiet hours, appearance, and units at `SunHat/ViewModels/SettingsViewModel.swift:78-162`.
- Data/privacy: `DataPrivacyViewModel` summarizes, exports, and deletes user data at `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:64-163` and `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:210-438`.
- App Intents: shortcuts open the app to home/reminders/settings/create at `SunHat/AppIntents/SunHatShortcuts.swift:36-157`.
- Spotlight: reminders and locations are indexed at `SunHat/Services/Search/SunHatSearchIndexer.swift:18-75`.

Auth flows:
- No account authentication, token refresh, or logout flow exists in the current repo.
- No Keychain usage was found.
- External service auth is limited to WeatherKit entitlement and optional OpenWeatherMap API key injection into `WeatherService.configure` at `SunHat/Services/Weather/WeatherService.swift:30-34`.

## 5. Who It's For (Roles/Personas inferred)

Personas:
- Outdoor planner: wants reminders tied to temperature, rain, wind, and sky condition rather than calendar time.
- Home/garden user: examples and categories include gardening, pets, watering, frost/heat alerts, and outdoor activities.
- Privacy-sensitive user: app copy and settings emphasize local storage, manual location option, data export/delete, no tracking, and privacy policy/contact paths.
- Power user: advanced trigger model supports ranges, exact temperatures, consecutive days, averages, seasonal markers, historical comparison, composite humidity/wind/precipitation, quiet hours, daily notification limits, and shortcuts.

Roles:
- Single-user app only. No admin/member roles.
- System roles are permission states: location authorization, notification authorization, background refresh availability, and WeatherKit entitlement/provisioning.

## 6. Module & Function Catalog

Entrypoints and lifecycle:
- `SunHatApp` (`SunHat/sunhat.swift:46-180`): creates SwiftData container, configures services, injects model container.
- `SunHatAppDelegate` (`SunHat/sunhat.swift:15-44`): notification delegate and category registration.
- `ContentView` (`SunHat/Views/Dashboard/ContentView.swift:11-46`): splash, onboarding/main routing.
- `MainTabView` (`SunHat/Views/Dashboard/MainTabView.swift:12-178`): tabs, create sheet, App Intent handoff, Spotlight handoff, lifecycle prompts.

Models:
- `WeatherReminder` (`SunHat/Models/WeatherReminder.swift:11-294`): reminder state, trigger cooldown, lifecycle history.
- `TriggerCondition` (`SunHat/Models/TriggerCondition.swift:11-104`): persistent weather condition definition.
- `WeatherData` and `ForecastDay` (`SunHat/Models/WeatherData.swift:11-146`): current/cache and forecast persistence.
- `LocationData`, `SavedLocation`, `LocationHistory` (`SunHat/Models/LocationData.swift`, `SunHat/Models/SavedLocation.swift`): location persistence.
- `UserPreferences` (`SunHat/Models/UserPreferences.swift:12-167`): units, notification policy, location mode, sync placeholders.
- `NotificationConfig` (`SunHat/Resources/Configuration/NotificationConfig.swift:12-107`): per-reminder notification content and delivery preferences.
- `NextReadyReminderSnapshot` (`SunHat/Models/NextReadyReminderSnapshot.swift:11-70`): compact DTO for dashboard and future widget/watch surfaces.

Services:
- `WeatherService` (`SunHat/Services/Weather/WeatherService.swift:15-88`): main facade and published weather state.
- `WeatherServiceActor` (`SunHat/Services/Weather/WeatherService.swift:97-384`): provider/cache/rate-limit work, currently main-actor isolated.
- `AppleWeatherKitAPI` (`SunHat/Services/Weather/WeatherAPI.swift:24-268`): WeatherKit adapter and forecast mapping.
- `OpenWeatherMapAPI` (`SunHat/Services/Weather/WeatherAPI.swift:272-469`): backup REST adapter.
- `BackgroundWeatherManager` (`SunHat/Services/Weather/BackgroundWeatherManager.swift:17-280`): background refresh and notification check path.
- `TriggerEngine` (`SunHat/Services/Trigger/TriggerEngine.swift:93-350` plus extensions): actor-based trigger evaluation.
- `TriggerEngineManager` and `TriggerNotificationManager` (`SunHat/Services/Trigger/TriggerEngineManager.swift:16-539`): trigger orchestration, notification sends/actions.
- `WeatherModelActor` (`SunHat/Services/Data/WeatherModelActor.swift:16-439`): SwiftData model actor and DTO extraction.
- `LocationPermissionManager` (`SunHat/Services/Location/LocationPermissionManager.swift:14-360`): CoreLocation authorization/current/manual location.
- `SunHatSearchIndexer` (`SunHat/Services/Search/SunHatSearchIndexer.swift:12-103`): Spotlight integration.
- `SunHatIntentHandoff` (`SunHat/Services/Routing/SunHatIntentHandoff.swift:18-40`): App Intent destination storage.
- `AppLifecyclePromptCoordinator` (`SunHat/Services/Engagement/AppLifecyclePromptCoordinator.swift:14-184`): review/notification/feedback prompts.

View models:
- `DashboardViewModel` (`SunHat/ViewModels/DashboardViewModel.swift:16-510`): home weather/reminders/alerts state.
- `WeatherViewModel` (`SunHat/ViewModels/WeatherViewModel.swift:15-510`): detailed weather state, forecast and prediction derivation.
- `FirstReminderCreationViewModel` (`SunHat/ViewModels/FirstReminderCreationViewModel.swift:15-366`): new reminder creation flow.
- `SettingsViewModel` (`SunHat/ViewModels/SettingsViewModel.swift:16-420`): settings persistence, permission status, support links.
- `DataPrivacyViewModel` (`SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:14-450`): export/delete/privacy operations.
- `LocationPickerViewModel` (`SunHat/ViewModels/LocationPickerViewModel.swift:12-147`): MapKit search and current-location lookup.

## 7. Critical Path Walkthroughs (top 3 workflows)

### 7.1 Create Weather Reminder

1. User selects `New Task`; `MainTabView.tabSelection` intercepts `.add` and sets `showingCreate = true` (`SunHat/Views/Dashboard/MainTabView.swift:27-41`).
2. Sheet presents `StreamlinedReminderCreationView` (`SunHat/Views/Dashboard/MainTabView.swift:74-80`).
3. View configures its view model with the environment `ModelContext` and loads default/current weather in `onAppear` (`SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:91-95`).
4. `FirstReminderCreationViewModel.loadWeather` resolves current/manual location and fetches one live `WeatherService.fetchWeatherData` response (`SunHat/ViewModels/FirstReminderCreationViewModel.swift:145-173`).
5. Forecast is mapped through `mapForecast` and trigger likelihood is calculated in memory (`SunHat/ViewModels/FirstReminderCreationViewModel.swift:182-289`).
6. On create, view calls `createReminder` and then dismisses only on success (`SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:210-218`).
7. `createReminder` builds `WeatherReminder`, `TriggerCondition`, optional `LocationData`, saves SwiftData, and indexes Spotlight (`SunHat/ViewModels/FirstReminderCreationViewModel.swift:291-364`).

Concurrency boundaries:
- The view model is `@MainActor`.
- Weather fetch crosses into `WeatherService`, also `@MainActor`, then into a main-actor `WeatherServiceActor`.
- Save uses the view's `ModelContext` on the main actor.

### 7.2 Background Weather Refresh and Notification

1. `SunHatApp.init` configures `BackgroundWeatherManager` with the shared container and starts async configuration of `WeatherService` and `TriggerEngineManager` (`SunHat/sunhat.swift:159-167`).
2. `BackgroundWeatherManager` registers BGTaskScheduler in its singleton init (`SunHat/Services/Weather/BackgroundWeatherManager.swift:32-65`).
3. On background task launch, `handleBackgroundTask` starts a cancellable work task, calls `WeatherService.shared.handleBackgroundRefresh`, then checks triggers (`SunHat/Services/Weather/BackgroundWeatherManager.swift:101-123`).
4. `checkTriggeredConditions` fetches preferences, gates on `allowsNotificationDelivery`, fetches reminders, filters by `canTrigger`, evaluates conditions, sends notifications, calls `reminder.trigger`, records daily count, then saves (`SunHat/Services/Weather/BackgroundWeatherManager.swift:125-190`).
5. `evaluateReminderCondition` fetches current weather and calls `WeatherData.evaluateCondition` (`SunHat/Services/Weather/BackgroundWeatherManager.swift:192-205`).
6. `sendNotificationForReminder` creates immediate `UNNotificationRequest` and updates notification delivery metrics (`SunHat/Services/Weather/BackgroundWeatherManager.swift:207-244`).

Concurrency boundaries:
- Manager is `@MainActor`.
- It creates a new `ModelContext(modelContainer)` for the task.
- Weather fetch stays on the main actor because `WeatherService` and `WeatherServiceActor` are main-actor isolated.

Caching:
- Weather cache TTL is 15 minutes (`SunHat/Services/Weather/WeatherService.swift:103`), but background refresh forces provider fetch by calling `performFetch(... forceRefresh: true)` at `SunHat/Services/Weather/WeatherService.swift:328-330`.

### 7.3 Weather Dashboard / Weather Tab Readiness

1. `DashboardView.onAppear` calls `viewModel.configure(modelContext:)` (`SunHat/Views/Dashboard/DashboardView.swift:89-92`).
2. `DashboardViewModel.configure` creates `WeatherModelActor`, configures `WeatherService`, loads initial data, and starts a five-minute timer (`SunHat/ViewModels/DashboardViewModel.swift:105-115`).
3. `refreshWeatherData` resolves manual/current location, blocks the `(0,0)` fallback, fetches weather, updates UI state, loads reminders and alerts (`SunHat/ViewModels/DashboardViewModel.swift:117-168`).
4. Dashboard renders current weather, compact next-ready reminder snapshot, ready alerts, and active reminders (`SunHat/Views/Dashboard/DashboardView.swift:38-75`).
5. `WeatherView.task` calls `WeatherViewModel.configure(modelContainer:)` (`SunHat/Views/Weather/WeatherView.swift:90-92`).
6. `WeatherViewModel.loadAllData` fetches current weather, computes day length, hourly, weekly, historical, and trigger predictions (`SunHat/ViewModels/WeatherViewModel.swift:140-167`).
7. The current `loadWeekly` path is unreliable because the actor returns no forecast days and random fallback data fills the UI (`SunHat/Services/Data/WeatherModelActor.swift:60-66`, `SunHat/ViewModels/WeatherViewModel.swift:249-292`).

## 8. Data Model & Persistence

Persistence technology:
- SwiftData model container is created in `SunHatApp.sharedModelContainer` with all app models in one schema (`SunHat/sunhat.swift:51-76`).
- Store is in the App Group container `group.org.wesley.sunhat`; CloudKit is explicitly disabled via `cloudKitDatabase: .none` (`SunHat/sunhat.swift:66-73`).
- Store recovery quarantines `.store`/`.sqlite` files and retries before falling back to in-memory mode (`SunHat/sunhat.swift:75-99`, `SunHat/sunhat.swift:119-156`).

Main entities:
- `WeatherReminder`: title, description, category, priority, active/completed/paused state, schedule/snooze/cooldown fields, relationships to trigger, notification config, location, history.
- `TriggerCondition`: temperature mode, range/exact values, consecutive/average/seasonal/historical/composite settings, sky filter fields, evaluation counters.
- `WeatherData`: current conditions, forecast relationship, location relationship, provider/accuracy/cache timestamps.
- `ForecastDay`: daily forecast values.
- `LocationData`: app weather location, relationship to reminders/weather data.
- `SavedLocation` and `LocationHistory`: user saved/manual location surfaces.
- `UserPreferences`: notification policy, units, manual location preferences, sync placeholders.
- `NotificationConfig`: per-reminder notification copy, cooldown, actions, critical-alert placeholder fields.
- `ReminderHistory`: lifecycle history records.

Relationships:
- `WeatherReminder.triggerCondition`, `.notificationConfig`, `.location`, `.history` are optional/list relationships (`SunHat/Models/WeatherReminder.swift:69-73`).
- `LocationData.weatherReminders` and `.weatherData` reverse relationships exist (`SunHat/Models/LocationData.swift:55-56`).
- `WeatherData.forecastDays` and `ForecastDay.weatherData` represent forecast children (`SunHat/Models/WeatherData.swift:81-82`, `SunHat/Models/WeatherData.swift:146`).

Migration strategy:
- No explicit SwiftData migration plan or versioned schema migration was found.
- CloudKit fields exist in models and docs, but CloudKit sync is disabled in code.

Integrity pitfalls:
- App Group store is extension-ready, but all `@Model` classes currently live in the app target, not a shared framework.
- Cache/history fetches are broad and filtered in memory, increasing scaling risk as weather rows grow.
- `deleteAllUserData` manually deletes each model type (`SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:313-371`); schema additions must update this function or privacy deletion will become incomplete.

## 9. Concurrency, Performance, and Security Controls

Concurrency:
- App uses Swift 6.2 and has a clean build with no compiler warning lines.
- UI-bound classes are generally `@MainActor`.
- Several newer view models already use `@Observable`: `SettingsViewModel`, `LocationPickerViewModel`, `DataPrivacyViewModel`.
- Heavier Combine-backed view models remain `ObservableObject`: `DashboardViewModel`, `WeatherViewModel`, `OnboardingCoordinator`, `TriggerEngineManager`.
- `TriggerEngine` is an actor and uses Sendable DTOs for model data (`SunHat/Services/Trigger/TriggerEngine.swift:93-130`, `SunHat/Services/Data/WeatherModelActor.swift:443-581`).
- `WeatherServiceActor` is not actually a Swift actor and is `@MainActor`; provider/network/cache work should move off the main actor.

Performance:
- Weather cache lookup and historical lookup fetch all rows before filtering (`SunHat/Services/Weather/WeatherService.swift:212-236`, `SunHat/Services/Data/WeatherModelActor.swift:117-139`).
- Dashboard uses a five-minute `Timer` (`SunHat/ViewModels/DashboardViewModel.swift:85-87`, `SunHat/ViewModels/DashboardViewModel.swift:201-207`); this is simple but should be reconsidered for scene phase, battery, and background state.
- Background refresh forces provider fetches per unique exact coordinate string (`SunHat/Services/Weather/WeatherService.swift:364-379`), so location normalization/caching matters for quota.
- WeatherKit quota risk is real if polling remains frequent; cache and backoff policies should be made explicit before scale.

Security and privacy:
- No auth tokens or Keychain secrets found.
- Optional OpenWeatherMap key is injected at runtime, not hardcoded in source (`SunHat/Services/Weather/WeatherService.swift:30-34`, `SunHat/Services/Weather/WeatherAPI.swift:272-280`).
- `APIKeys.plist.example` exists, but no live secret file surfaced in the scanned file list.
- Export files are written with atomic complete file protection and deleted after share completion when possible (`SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:394-438`).
- Privacy manifest states no tracking and location collection for app functionality.
- Logger lines include coordinates in debug/info paths (`SunHat/Services/Weather/WeatherService.swift:132-137`, `SunHat/Services/Location/LocationPermissionManager.swift:294-318`). In production, exact coordinates should be redacted or logged only at privacy-safe levels.

Correctness:
- The create flow correctly avoids fabricated weather.
- The Weather tab still fabricates weekly forecast fallback values.
- Notification policy is centralized in `UserPreferences.allowsNotificationDelivery` and used by both notification paths.
- Device verification remains required for BGTaskScheduler behavior and actual notification delivery.

## 10. Observability, Logging, and Error Handling

Observability:
- Uses `os.Logger` throughout services and view models.
- No analytics SDK, crash reporting SDK, remote logging, or feature flag service was found.
- `DataAnalyticsView` exposes analytics/crash report toggles in UI code, but no corresponding analytics/crash SDK was found (`SunHat/Views/Settings/DataAnalyticsView.swift`).

Error handling strengths:
- Weather failures surface in Dashboard as "Weather unavailable" with an error message (`SunHat/Views/Dashboard/DashboardView.swift:259-284`).
- Reminder save failure keeps the sheet open and shows an alert (`SunHat/ViewModels/FirstReminderCreationViewModel.swift:351-360`, `SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:99-109`).
- Settings URL failures surface through injected `SettingsOpening` (`SunHat/ViewModels/SettingsViewModel.swift:313-323`).
- Data export/delete failures set visible `errorMessage` (`SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:102-163`).

Error handling gaps:
- App lifecycle feedback submission ignores mail-open failure (`SunHat/Services/Engagement/AppLifecyclePromptCoordinator.swift:113-131`).
- Notification "view" action logs only and does not route to the reminder detail (`SunHat/Services/Trigger/TriggerEngineManager.swift:517-521`).
- Background task failure observability is only local logs; no durable diagnostic state for support/debugging.

## 11. Build/Run/Deploy & Configuration

Build/run:
- Direct Xcode project, no generated `project.yml`.
- Debug simulator build passed on `iPhone 17 Pro` simulator OS 26.5.
- Release build script mutates `buildnumber.txt` during Release/Archive (`SunHat.xcodeproj/project.pbxproj:87-107`).

Deployment:
- Automatic signing with development team `HD39MR492X`.
- Bundle ID: `org.wesley.sunhat`.
- Entitlements: WeatherKit and App Group.
- `CURRENT_PROJECT_VERSION = 5`, `MARKETING_VERSION = 1.0`.

Configuration injection:
- Info.plist is explicit at `SunHat/Info.plist`.
- Entitlements are explicit at `SunHat/SunHat.entitlements`.
- Privacy manifest is explicit at `SunHat/PrivacyInfo.xcprivacy`.
- Optional backup weather provider key is not wired from a live secret file in the inspected startup path; `WeatherService.configure` accepts an optional key.

CI:
- No `.github/workflows` or other CI configs were found.
- No SwiftLint/SwiftFormat config was found.

External gates not proven by local build:
- WeatherKit capability provisioning for release App ID.
- Actual background refresh execution on physical hardware.
- Notification delivery with app backgrounded.
- App Store Connect privacy labels and metadata.
- Support/privacy/feedback inbox delivery.

## 12. Tests & Quality Signals

Current quality signals:
- Debug build passed with no compiler warnings.
- Unit target passed: 231 tests, 48 suites.
- Tests cover weather mapping, weather service configuration, reminder creation, user preferences, notification policy, background manager registration/fallback, settings dependency seams, data privacy, dashboard data, next-ready snapshot, and WeatherViewModel dependency injection.

Test framework inventory:
- Swift Testing used heavily in `SunHatTests`.
- XCTest performance tests remain in `DashboardPerformanceTests` and `WeatherServicePerformanceTests`.
- UI tests use XCTest/XCUITest in `SunHatUITests`.

Coverage gaps:
- UI tests were not run in this audit.
- Physical-device background notification loop is not verified.
- No deterministic test currently fails for `WeatherViewModel.loadWeekly` fabricated fallback data.
- No integration test asserts one canonical notification path and no duplicate delivery between `BackgroundWeatherManager` and `TriggerEngineManager`.
- No tests around Spotlight deletion/update when reminders are edited/deleted beyond index-on-create evidence.
- No migration tests because there is no explicit versioned schema migration.
- No CI gate enforces build/test/lint on push.

## 13. Issues & Risks (Prioritized)

### P1. Weather tab fabricates weekly forecast values

- Problem: Detailed Weather tab weekly forecast displays synthetic data whenever actor forecast data is unavailable.
- Evidence: `WeatherModelActor.fetchForecastData` returns `[]` at `SunHat/Services/Data/WeatherModelActor.swift:60-66`; `WeatherViewModel.loadWeekly` fills missing days with `Double.random` and `Int.random` at `SunHat/ViewModels/WeatherViewModel.swift:249-292`.
- Impact: User can see fake forecast values in a weather app. This undermines trust and can influence reminder decisions.
- Recommended fix: Remove random fallback. Feed Weather tab from `WeatherService.fetchWeatherData(...).forecastDays`, or implement `WeatherModelActor.fetchForecastData` against cached/live weather. Show unavailable/partial state when no forecast exists.
- Effort: M.
- July 2026 modernization angle: use deterministic model-backed state and clear unavailable UI; do not synthesize forecast data for production weather surfaces.

### P2. Background trigger ownership is split

- Problem: Two managers can own background trigger evaluation and notification delivery.
- Evidence: Weather refresh path sends notifications at `SunHat/Services/Weather/BackgroundWeatherManager.swift:101-244`; trigger-evaluation path sends notifications at `SunHat/Services/Trigger/TriggerEngineManager.swift:104-256`.
- Impact: Duplicate logic, possible duplicate notifications, harder device verification, and unclear source of truth for cooldown/policy behavior.
- Recommended fix: Pick one canonical evaluator. Prefer `TriggerEngine` for condition logic and one notification manager for delivery. Make `BackgroundWeatherManager` fetch/cache/weather scheduling only, or fold it into a single background orchestration service.
- Effort: L.
- July 2026 modernization angle: use one structured-concurrency pipeline with explicit policy gates and persistence side effects.

### P3. Weather network/cache work remains main-actor isolated

- Problem: `WeatherServiceActor` is a class annotated `@MainActor`, not an actor, and it performs provider fetch, cache scan, cache insert/delete, and cleanup.
- Evidence: Declaration at `SunHat/Services/Weather/WeatherService.swift:97-104`; fetch/cache work at `SunHat/Services/Weather/WeatherService.swift:132-267`.
- Impact: Main-actor contention and poor scalability as weather/cache work grows.
- Recommended fix: Convert to a real actor or split provider fetch/rate limiting into a non-main actor, with SwiftData writes through a `@ModelActor` or main-context handoff where required.
- Effort: L.
- July 2026 modernization angle: Swift 6.2 actor isolation should make expensive IO and data processing explicit and off the UI actor.

### P4. Weather cache/history lookups fetch too broadly

- Problem: Cache and historical lookups fetch all `WeatherData` rows and filter in memory.
- Evidence: Cache lookup at `SunHat/Services/Weather/WeatherService.swift:212-236`; historical lookup at `SunHat/Services/Data/WeatherModelActor.swift:117-139`.
- Impact: Performance degradation as the local store grows; possible jank because one path is main-actor isolated.
- Recommended fix: Add queryable rounded/geohash location fields or normalized location keys and use SwiftData predicates/sort limits. Add retention policy tests.
- Effort: M.
- July 2026 modernization angle: use SwiftData predicates and indexed/canonical keys rather than broad Core Data-backed fetches.

### P5. Physical-device background delivery remains unverified

- Problem: The most important product loop cannot be proven by simulator/unit tests alone.
- Evidence: Repo TODO explicitly says device verification is pending at `TODO.md:30`; local audit only verified build/unit tests.
- Impact: App Store readiness and user trust remain blocked until the actual background notification behavior is confirmed.
- Recommended fix: Install a signed build on hardware, create a currently true reminder, background the app, and record notification delivery. Capture logs and update readiness docs.
- Effort: M.
- July 2026 modernization angle: BGTaskScheduler behavior is system-mediated; product readiness needs device evidence, not only static config.

### P6. App Intents only open screens

- Problem: Shortcuts do not perform data-layer actions.
- Evidence: Intents store destinations only at `SunHat/AppIntents/SunHatShortcuts.swift:56-103`; `SunHatIntentHandoff` writes a `UserDefaults` pending destination at `SunHat/Services/Routing/SunHatIntentHandoff.swift:18-40`.
- Impact: Siri/Shortcuts integration is shallow. Users cannot pause, complete, or create reminders hands-free despite intent names implying management.
- Recommended fix: Add `AppEntity` for reminders and App Intents for pause/resume/complete/create with explicit confirmation and model access via shared service.
- Effort: L.
- July 2026 modernization angle: App Intents should expose app actions/content, not only deep-link navigation.

### P7. Inline localization blocks future growth

- Problem: No strings catalog or pluralization resources were found.
- Evidence: repo scan found no `.strings`, `.stringsdict`, or `.xcstrings` under `SunHat`.
- Impact: Localization and App Store market expansion will be expensive; plural/dynamic wording may be incorrect.
- Recommended fix: Introduce `Localizable.xcstrings`, move high-traffic strings first, then settings/onboarding/export copy.
- Effort: M.
- July 2026 modernization angle: use string catalogs as the default for SwiftUI text-heavy apps.

### P8. Privacy export/delete is manually maintained

- Problem: Export/delete code hand-enumerates models and fields.
- Evidence: JSON/CSV generation at `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:210-310`; deletion list at `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift:313-371`.
- Impact: Schema drift can make exports incomplete or deletion incomplete.
- Recommended fix: Add tests that compare schema model list to privacy export/delete coverage. Prefer Codable export DTOs per entity.
- Effort: M.
- July 2026 modernization angle: privacy operations should be test-backed and schema-aware.

### P9. UIKit haptics remain in SwiftUI views

- Problem: SwiftUI flows use imperative UIKit feedback generators.
- Evidence: creation success haptic at `SunHat/Views/Reminders/StreamlinedReminderCreationView.swift:210-218`; additional haptics surfaced in onboarding/location/reminder section search.
- Impact: Imperative haptics are harder to gate by state and accessibility settings.
- Recommended fix: Migrate simple state-driven cases to `.sensoryFeedback(_:trigger:)`; keep UIKit only where a declarative trigger is awkward.
- Effort: S.
- July 2026 modernization angle: SwiftUI sensory feedback has been available since iOS 17 and is preferred for state-driven feedback.

### P10. No CI gate

- Problem: No repository CI workflow was found.
- Evidence: scan found no `.github/workflows` files and no lint/format configs.
- Impact: Clean local build/test status can regress before merge/release.
- Recommended fix: Add a minimal GitHub Actions or Xcode Cloud workflow: build `SunHat`, test `SunHatUnitTests`, optionally build UI tests, archive on release branches.
- Effort: M.
- July 2026 modernization angle: Swift 6 concurrency and App Intents metadata extraction should be continuously checked.

## 14. Improvement Plan (Next steps)

Do first, safety/maintainability:
1. Remove Weather tab fabricated weekly forecast fallback and test the empty/unavailable state.
2. Device-verify the background weather condition -> notification loop.
3. Collapse background notification delivery to one canonical service.
4. Add a schema-aware privacy export/delete coverage test.
5. Update stale docs to match current trigger persistence and compact dashboard wiring.

Architecture/performance:
1. Convert `WeatherServiceActor` into a real actor or split provider/rate-limit/cache work off `@MainActor`.
2. Replace broad weather cache/history fetches with predicate-backed normalized location keys.
3. Extract a shared `SunHatKit` module for models/DTOs/trigger snapshot production before adding widgets/watch.
4. Move Weather tab trigger prediction heuristics into `TriggerEngine` or a domain service.
5. Add explicit WeatherKit quota/backoff policy around foreground/background/widget fetches.

Testing:
1. Add unit tests for Weather tab weekly forecast when no forecast data exists.
2. Add integration tests ensuring only one notification path sends for a triggered reminder.
3. Add model schema coverage tests for data export/delete.
4. Stabilize and run a small UI smoke suite: launch, tabs, create sheet, settings, Weather tab.
5. Add a CI workflow for build + unit tests.

Suggested PR breakdown:
1. PR 1: Weather tab no-fabrication fix plus tests.
2. PR 2: Background notification ownership decision and duplicate-delivery test.
3. PR 3: Weather service actor/cache query refactor.
4. PR 4: Privacy export/delete schema coverage.
5. PR 5: CI workflow and docs refresh.
6. PR 6: App Intents v2 with real reminder entities/actions.
7. PR 7: SunHatKit extraction.

## 15. Future Features Roadmap

Weather reliability and explainability:
1. Trigger explanation timeline: show why each reminder is or is not ready; changes in `TriggerEngine`, `DashboardView`, `DetailedReminderView`.
2. Confidence history: persist recent evaluations and display trend; changes in SwiftData schema, `TriggerEngine`, dashboard.
3. Weather provider health screen: WeatherKit status, cache age, last refresh, background status; changes in settings and weather services.
4. Quota-aware refresh modes: user-selectable normal/low-power refresh cadence; changes in preferences and background scheduling.

Ambient surfaces:
5. WidgetKit small/Lock Screen widgets using `NextReadyReminderSnapshot`; requires `SunHatKit`.
6. watchOS complication and glanceable app; requires `SunHatKit` plus WatchConnectivity snapshot transfer.
7. Live Activity only for short "approaching trigger" windows; requires canonical ETA/distance-to-trigger.
8. StandBy/iPad dashboard mode for next ready reminders; changes in SwiftUI views.

Shortcuts and system integration:
9. AppEntity-backed reminder shortcuts for pause/resume/complete.
10. Siri create-reminder flow with parameters for title, location, temperature, and sky condition.
11. Spotlight deep links to exact reminder detail, not only Reminders tab.
12. Focus Filter or Control Center control for pausing weather reminders.

Data and privacy:
13. Codable export DTOs with import/restore.
14. CloudKit sync opt-in after migration/versioning plan.
15. Data retention controls for weather cache/history.

Weather intelligence:
16. Native weather alerts if WeatherKit alert data is available for target regions.
17. Forecast-based "likely later today" suggestions.
18. Seasonal reminder templates for frost, heat, rain gaps, wind, UV.
19. Multi-location monitoring with per-location refresh grouping.

Product polish:
20. String catalog localization.
21. Dynamic Type visual QA for forecast chips, dashboard hero, and reminder cards.
22. In-app diagnostic export for background task and notification logs.
23. Richer onboarding that creates a sample reminder without fake weather.
24. Settings search using native searchable patterns.

## 16. Appendix: File/Path Index (group files by purpose)

Project and config:
- `SunHat.xcodeproj/project.pbxproj`: targets, build settings, signing, build-number script.
- `SunHat/Info.plist`: permissions, BGTaskScheduler identifiers, background mode.
- `SunHat/SunHat.entitlements`: WeatherKit and App Group.
- `SunHat/PrivacyInfo.xcprivacy`: privacy manifest.
- `buildnumber.txt`: Release/archive build-number source.

Entrypoints:
- `SunHat/sunhat.swift`: app, app delegate, container, store recovery.
- `SunHat/Views/Dashboard/ContentView.swift`: splash/onboarding/main routing.
- `SunHat/Views/Dashboard/MainTabView.swift`: app tab shell and create action.

Models:
- `SunHat/Models/WeatherReminder.swift`
- `SunHat/Models/TriggerCondition.swift`
- `SunHat/Models/WeatherData.swift`
- `SunHat/Models/LocationData.swift`
- `SunHat/Models/SavedLocation.swift`
- `SunHat/Models/UserPreferences.swift`
- `SunHat/Models/NextReadyReminderSnapshot.swift`
- `SunHat/Resources/Configuration/NotificationConfig.swift`

Services:
- `SunHat/Services/Weather/WeatherService.swift`
- `SunHat/Services/Weather/WeatherAPI.swift`
- `SunHat/Services/Weather/BackgroundWeatherManager.swift`
- `SunHat/Services/Trigger/TriggerEngine.swift`
- `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift`
- `SunHat/Services/Trigger/TriggerEngine+SeasonalAnalysis.swift`
- `SunHat/Services/Trigger/TriggerEngine+TrendAnalysis.swift`
- `SunHat/Services/Trigger/TriggerEngine+Performance.swift`
- `SunHat/Services/Trigger/TriggerEngineManager.swift`
- `SunHat/Services/Data/WeatherModelActor.swift`
- `SunHat/Services/Location/LocationPermissionManager.swift`
- `SunHat/Services/Search/SunHatSearchIndexer.swift`
- `SunHat/Services/Routing/SunHatIntentHandoff.swift`
- `SunHat/Services/Settings/SettingsOpening.swift`
- `SunHat/Services/Settings/NotificationPermissionProviding.swift`
- `SunHat/Services/Engagement/AppLifecyclePromptCoordinator.swift`

View models:
- `SunHat/ViewModels/DashboardViewModel.swift`
- `SunHat/ViewModels/WeatherViewModel.swift`
- `SunHat/ViewModels/FirstReminderCreationViewModel.swift`
- `SunHat/ViewModels/DetailedReminderViewModel.swift`
- `SunHat/ViewModels/LocationManagementViewModel.swift`
- `SunHat/ViewModels/LocationPickerViewModel.swift`
- `SunHat/ViewModels/SettingsViewModel.swift`
- `SunHat/ViewModels/Settings/DataPrivacyViewModel.swift`
- `SunHat/ViewModels/Settings/NotificationPreferencesViewModel.swift`
- `SunHat/ViewModels/UserPreferencesViewModel.swift`

Views:
- `SunHat/Views/Dashboard/*`: home/dashboard, tab shell, forecast ribbon, weather dial, metric rows.
- `SunHat/Views/Weather/*`: detailed weather tab, charts, alerts, forecast detail.
- `SunHat/Views/Reminders/*`: creation, list, detail, cards, filter chips.
- `SunHat/Views/Location/*`: permission, picker, manual entry, saved locations.
- `SunHat/Views/Settings/*`: settings, privacy, notifications, about/help/contact.
- `SunHat/Views/Onboarding/*`: welcome, preferences, location/notification permission, celebration.
- `SunHat/Views/Components/*`: reusable glass/card/product components.
- `SunHat/Views/Engagement/AppFeedbackFormView.swift`: feedback sheet.

System surfaces:
- `SunHat/AppIntents/SunHatShortcuts.swift`: App Shortcuts.
- `SunHat/Services/Search/SunHatSearchIndexer.swift`: Spotlight.
- `SunHat/Services/Notifications/SunHatNotificationCategoryRegistry.swift`: notification categories/actions.

Design and utilities:
- `SunHat/Utilities/Theme/*`: palettes, surfaces, typography.
- `SunHat/Utilities/Motion/SunHatMotion.swift`: animation/reduce-motion helpers.
- `SunHat/Utilities/AppSupportLinks.swift`: support/privacy/terms/email URLs.
- `SunHat/Resources/Fonts/*`: bundled Inter font files, though docs indicate system typography is preferred.

Tests:
- `SunHatTests/*`: unit/integration/performance tests.
- `SunHatUITests/*`: UI smoke/performance tests.

Docs and planning:
- `CLAUDE.md`: repo guidance.
- `TODO.md`: launch blockers and known gaps.
- `IMPROVEMENT_PLAN.md`: phased roadmap, partially stale.
- `WIDGET_SETUP.md`: future widget/shared framework instructions.
- `NATIVE_IOS_FEATURE_PROGRESS.md`: native feature verification notes.
- `audit/*`: prior audit/design verification artifacts.
