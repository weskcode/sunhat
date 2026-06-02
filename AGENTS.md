# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

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
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.4' test

# Build for release
xcodebuild -scheme SunHat -configuration Release build
```

### Testing Commands
```bash
# Run unit tests only
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.4' -only-testing:SunHatTests test

# Run UI tests only
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.4' -only-testing:SunHatUITests test

# Run specific test
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.4' -only-testing:SunHatTests/SunHatTests/testExample test
```

## Project Architecture

### Current Structure
- **SunHatApp.swift**: Main app entry point with SwiftData ModelContainer setup
- **ContentView.swift**: Root view — routes between splash, onboarding, and main tab bar
- **MainTabView.swift**: iOS 26.4 tab bar with `.tabBarMinimizeBehavior(.onScrollDown)`
- **Views/Components/GlassCard.swift**: Reusable Liquid Glass card/section components
- **Tests**: Standard XCTest setup for unit and UI testing

### Current Architecture (iOS 26.4 Implementation)
The app is a sophisticated weather-triggered reminder system with:

- **MVVM Pattern**: SwiftUI Views + ViewModels + SwiftData Models with improved dependency injection
- **SwiftData**: Local persistence with iOS 26 optimizations (CloudKit sync prepared, currently disabled)
- **Weather Integration**: Apple WeatherKit (primary) with iOS 26 APIs, OpenWeatherMap (backup)
- **Background Processing**: iOS 26 BackgroundTasks framework for weather monitoring
- **Modern Concurrency**: Swift 6.2 async/await, actors, structured concurrency with approachable concurrency
- **Location Services**: iOS 26 CoreLocation with temporary location permission support
- **Liquid Glass UI**: iOS 26.4 `.glassEffect()` throughout all card surfaces and interactive elements

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

**Always use `.glassEffect()` for card surfaces** — do NOT use `.regularMaterial` or `Color(.secondarySystemBackground)` as card backgrounds.

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

// ❌ Outdated — do not use
.background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
```

**Glass button styles**:
```swift
// System glass button
Button("Action") { ... }
    .buttonStyle(.glass)
    .tint(.blue)

// Glass FAB (floating action button)
Button { ... } label: { Image(systemName: "plus") }
    .buttonStyle(GlassFABStyle(tint: .blue))

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
- **Observation**: ViewModels currently use `ObservableObject` — migrate to `@Observable` as a future refactor (see migration note below)
- **Swift 6.2 Features**: Approachable concurrency, enhanced result builders, macros

### ViewModel Migration Note (`@Observable`)
All ViewModels currently use `ObservableObject` + `@Published` + Combine. They should be migrated to `@Observable` incrementally:

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

Priority order for migration:
1. `UserPreferencesViewModel` (no Combine)
2. `SettingsViewModel` (light Combine)
3. `OnboardingCoordinator` (medium complexity)
4. `DashboardViewModel` / `WeatherViewModel` (heavy Combine — keep Combine internally, expose via `@Observable`)

### Weather Integration Architecture
- Primary: Apple WeatherKit with iOS 26 APIs — `WeatherService` protocol + `AppleWeatherKitAPI`
- Backup: OpenWeatherMap API
- Cache with SwiftData for offline capability
- Background refresh via iOS 26 BackgroundTasks (`BGContinuedProcessingTask`)
- `async/await` throughout — no completion handlers

### Testing Requirements
- Unit tests in `SunHatTests/` for business logic
- UI tests in `SunHatUITests/` for user workflows
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

As of March 2026 (iOS 26.4 upgrade):
- ✅ Deployment target: iOS 26.4, Swift 6.2
- ✅ **Liquid Glass**: All card surfaces use `.glassEffect()` (no more `.regularMaterial`)
- ✅ **Glass tab bar**: `MainTabView` with `.tabBarMinimizeBehavior(.onScrollDown)`
- ✅ **Glass FAB**: Dashboard quick-create button uses `GlassFABStyle`
- ✅ **Glass buttons**: Welcome screen "Get Started" uses `.buttonStyle(.glass)`
- ✅ **Glass tags**: Onboarding activity tags use capsule glass tints
- ✅ **GlassCard component**: Reusable `GlassCard`, `GlassSection`, `GlassMetricBadge`
- ✅ Complete location services integration with iOS 26 APIs
- ✅ Enhanced WeatherKit support with extended weather data
- ✅ Background weather updates using iOS 26 async patterns
- ✅ Full test coverage including iOS 26 specific scenarios
- 🔲 ViewModel migration from `ObservableObject` → `@Observable` (future refactor)
- 🔲 CloudKit sync re-enablement (prepared, needs provisioning)
