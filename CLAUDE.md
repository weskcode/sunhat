# CLAUDE.md

This file provides guidance to Claude when working with code in this repository.

## Project Overview

This is "SunHat" - a weather-triggered reminder iOS application. The app concept is a location-aware reminder system that triggers notifications based on temperature conditions and weather patterns rather than traditional calendar scheduling.

## Development Environment

- **Platform**: iOS 26.4 (upgraded March 2026)
- **Language**: Swift 6.2 (Xcode 26.4, approachable concurrency)
- **UI Framework**: SwiftUI with iOS 26.4 Liquid Glass design language
- **Architecture**: MVVM (Model-View-ViewModel) pattern with improved dependency injection
- **Data Layer**: SwiftData for local persistence with iOS 26 optimizations, CloudKit for sync
- **Minimum Target**: iOS 26.4
- **Bundle ID**: org.wesley.sunhat

## Common Development Commands

### Building and Running
```bash
# Open project in Xcode
open SunHat.xcodeproj

# Build the project
xcodebuild -scheme SunHat -configuration Debug build

# Run tests
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' test

# Build for release
xcodebuild -scheme SunHat -configuration Release build
```

### Testing Commands
```bash
# Run unit tests only
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -only-testing:SunHatTests test

# Run UI tests only
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -only-testing:SunHatUITests test

# Run specific test
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -only-testing:SunHatTests/SunHatTests/testExample test
```

Use the existing configured simulator only: `iPhone 17 Pro` (`20465D2E-7941-46FD-BAE2-21335FE5F0B1`). Do not clone or repeatedly launch additional simulators for routine validation.

## Project Architecture

### Current Structure
- **SunHat/sunhat.swift**: Main app entry point with SwiftData ModelContainer setup
- **ContentView.swift**: Root view — routes between splash, onboarding, and main tab bar
- **MainTabView.swift**: iOS 26.4 tab bar with `.tabBarMinimizeBehavior(.onScrollDown)`
- **Views/Components/GlassCard.swift**: Reusable Liquid Glass card/section components
- **Tests**: Unit tests use XCTest plus newer Swift Testing suites; UI tests remain XCTest-based

### Current Architecture (iOS 26.4 Implementation)
The app is a sophisticated weather-triggered reminder system with:

- **MVVM Pattern**: SwiftUI Views + ViewModels + SwiftData Models with improved dependency injection
- **SwiftData**: Local persistence with iOS 26 optimizations (CloudKit sync prepared, currently disabled)
- **Weather Integration**: Apple WeatherKit (primary) with iOS 26 APIs, OpenWeatherMap (backup)
- **Background Processing**: iOS 26 BackgroundTasks framework for weather monitoring
- **Modern Concurrency**: Swift 6.2 async/await, actors, structured concurrency with approachable concurrency
- **Location Services**: iOS 26 CoreLocation with temporary location permission support
- **Liquid Glass UI**: iOS 26.4 `.glassEffect()` on primary card surfaces and interactive elements; all views use `Color(.systemBackground)` (no custom warm-tinted backgrounds)

### Key Data Models
```swift
@Model
class WeatherReminder {
    var id: UUID
    var title: String
    var triggerCondition: TriggerCondition
    var isActive: Bool
    var location: LocationData?
}

@Model
class WeatherData {
    var timestamp: Date
    var temperature: Double
    var feelsLike: Double
    var location: LocationData
    var forecast: [ForecastDay]
}
```

## Development Standards

### iOS 26.4 Liquid Glass UI

**Use `.glassEffect()` for all card surfaces** and `Color(.systemBackground)` for page backgrounds (standard iOS white/dark). No custom warm-tinted or gradient backgrounds. Remaining ~29 `Color(.secondarySystemBackground)` are in secondary/nested contexts — convert case-by-case only where a true top-level card surface is identified (avoid glass-in-glass). `GlassEffectContainer` wrapping and `.searchable` are deferred to visual QA.

```swift
// ✅ iOS 26.4 — correct
someView
    .padding(20)
    .glassEffect(in: .rect(cornerRadius: 20))

// ✅ Tinted glass for secondary panels
innerPanel
    .padding(16)
    .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 12))

// ✅ Reusable GlassCard component
GlassCard { content }
GlassSection(title: "Weather", icon: "cloud.fill") { content }

// ✅ Group glass elements for shared refraction
GlassEffectContainer {
    VStack { cardA; cardB }
}

// Do not use .regularMaterial — use .glassEffect() instead
// .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))  // DEPRECATED
```

**Glass button styles**:
```swift
// System glass button
Button("Action") { ... }
    .buttonStyle(.glass)
    .tint(.blue)

// Glass create task button
GlassCreateTaskButton {
    showingQuickCreate = true
}

// Glass capsule tags
label
    .padding(.horizontal, 14).padding(.vertical, 8)
    .glassEffect(.regular.tint(color.opacity(0.15)), in: .capsule)
```

**Tab bar** — use `.tabBarMinimizeBehavior(.onScrollDown)` on `TabView` to auto-hide on scroll.

### SwiftData Implementation
- Use `@Model` for all persistent entities
- Configure ModelContainer in app entry point (already done)
- CloudKit sync is prepared but disabled — enable via `ModelConfiguration(.cloud)` when ready
- Use `@Query` in views for reactive data binding

### Modern Swift Patterns (iOS 26.4)
- **Concurrency**: Always use async/await, never completion handlers
- **UI Safety**: Use `@MainActor` for UI-bound classes
- **Actor Isolation**: Background actors for data processing
- **Structured Concurrency**: TaskGroup and async let for parallel operations
- **Observation**: Lightweight ViewModels are being migrated incrementally to `@Observable`; Combine-heavy ViewModels can remain `ObservableObject` until their dependencies are isolated.
- **Swift 6.2 Features**: Approachable concurrency, enhanced result builders, macros

### ViewModel Migration Note (`@Observable`)
Some ViewModels still use `ObservableObject` + `@Published` + Combine. Migrate low-risk ViewModels to `@Observable` incrementally:

```swift
// Before
@MainActor
final class SomeViewModel: ObservableObject {
    @Published var value: String = ""
}
// In view: @StateObject private var vm = SomeViewModel()

// After (iOS 17+ / iOS 26 preferred)
@MainActor @Observable
final class SomeViewModel {
    var value: String = ""  // automatically observed
}
// In view: @State private var vm = SomeViewModel()
// Injected: @Environment(SomeViewModel.self) var vm
```

Migration status and priority:
1. `UserPreferencesViewModel` migrated to `@Observable`.
2. Continue with `SettingsViewModel` and `LocationPickerViewModel` when dependencies are ready.
3. Defer `OnboardingCoordinator` until onboarding flow cleanup is stable.
4. Keep `DashboardViewModel` / `WeatherViewModel` on `ObservableObject` for now because they still coordinate heavier service work and Combine-backed services.

### Weather Integration Architecture
- Primary: Apple WeatherKit with iOS 26 APIs — `WeatherProviding` / `WeatherService` + `AppleWeatherKitAPI`
- Backup: OpenWeatherMap API
- Cache with SwiftData for offline capability
- Background refresh via iOS 26 BackgroundTasks (`BGContinuedProcessingTask`)
- `async/await` throughout — no completion handlers

### Testing Requirements
- Unit tests in `SunHatTests/` for business logic; write new unit/integration tests with Swift Testing where practical
- UI tests in `SunHatUITests/` for user workflows; Swift Testing does not support UI tests
- Mock weather data for consistent testing
- Test both online and offline scenarios
- Specific iOS 26.4 test coverage:
  - Temporary location permission flows
  - Background weather refresh with async/await
  - Liquid Glass rendering (accessibility audit)
  - Enhanced WeatherKit data mapping

## Feature Implementation Notes

The app implements sophisticated weather triggers including:
- Temperature-based conditions (exact, ranges, "feels like")
- Pattern recognition (consecutive days, averages)
- Seasonal intelligence and transitions
- Composite triggers (temperature + humidity + wind)
- Predictive triggers based on forecasts

## Performance Considerations

- **Battery Optimization**: Intelligent background refresh intervals (5-minute minimum)
- **Memory Management**: Efficient SwiftData queries with predicates
- **Network Efficiency**: Request batching and response caching
- **UI Responsiveness**: Background processing with `@MainActor` UI updates
- **Liquid Glass Performance**: Group related glass surfaces in `GlassEffectContainer` for shared GPU compositing

## Privacy Requirements

- **Location Privacy**: Optional precise location, city-level default with iOS 26 temporary permission support
- **Data Minimization**: Store only necessary weather data locally
- **No Data Sharing**: Zero personal weather data shared externally
- **Compliance**: GDPR and CCPA ready implementation

## Current Implementation Status

As of June 2026:
- ✅ Deployment target: iOS 26.4, Swift 6.2
- ✅ **Liquid Glass**: `.glassEffect()` on card surfaces; all page backgrounds use `Color(.systemBackground)` (standard iOS); remaining ~29 `secondarySystemBackground` are secondary/nested fills left deliberately
- ✅ **Native settings**: Apple-native `SettingsView` with icon chips, real notification toggle, enforced quiet hours and master switch
- ✅ **Glass tab bar**: `MainTabView` with `.tabBarMinimizeBehavior(.onScrollDown)`
- ✅ **Glass create button**: a `Tab("New Task", systemImage: "plus", role: .search)` renders as the detached circular glass button on the trailing side of the tab bar (the slot Apple Music uses for search). `MainTabView` intercepts its selection in `.onChange` — reverts the selection and presents the create sheet — so it acts as a button, not a tab. (Earlier `tabViewBottomAccessory` and over-content FAB approaches were rejected.)
- ✅ **Glass buttons**: Welcome screen "Get Started" uses `.buttonStyle(.glass)`
- ✅ **Glass tags**: Onboarding activity tags use capsule glass tints
- ✅ **GlassCard component**: Reusable `GlassCard`, `GlassSection`, `GlassMetricBadge`
- ✅ **System typography**: Global Inter/custom display typography has been retired in favor of semantic system styles
- ✅ **Native empty states**: Key empty states use `ContentUnavailableView`
- ✅ **Streamlined creation**: Normal navigation uses the streamlined reminder creator
- ✅ **Compact surface**: `NextReadyReminderSnapshot` (`Codable`) / `NextReadyReminderCompactView` / `NextReadyReminderSelector` are wired into `DashboardView` and unit-tested; still needs the `SunHatKit` shared-framework move before it can also back a widget/watch surface
- ✅ Complete location services integration with iOS 26 APIs
- ✅ Enhanced WeatherKit support with extended weather data
- ✅ Background weather updates using iOS 26 async patterns
- ✅ **Background task plist**: `BGTaskSchedulerPermittedIdentifiers` and `fetch` background mode configured
- ✅ **ModelContainer injection**: `BackgroundWeatherManager` and `TriggerEngineManager` use the shared container from app entry point
- ✅ **Zero `DispatchQueue.main.asyncAfter`** in production code — all replaced with cancellable `Task.sleep`
- ✅ Dependency seams: `WeatherProviding`, `LocationManaging`, `SettingsOpening`, `NotificationPermissionProviding` protocols
- ✅ Observation migration: `UserPreferencesViewModel`, `SettingsViewModel`, `LocationPickerViewModel` use `@Observable`
- ✅ Unit verification: `SunHatTests` passed with 230 tests on June 12, 2026
- 🔲 Actual WidgetKit/watchOS targets (shared compact view exists; targets are not present yet)
- ✅ Launch smoke verification on the configured simulator (boots to dashboard, light/dark render, relaunch stable, live error states — June 12, 2026); 🔲 interactive tap-through QA still pending
- 🔲 Continue ViewModel migration from `ObservableObject` → `@Observable`
- 🔲 CloudKit sync re-enablement (prepared, needs provisioning)
