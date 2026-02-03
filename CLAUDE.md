# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "SunHat" - a weather-triggered reminder iOS application. The app concept is a location-aware reminder system that triggers notifications based on temperature conditions and weather patterns rather than traditional calendar scheduling.

## Development Environment

- **Platform**: iOS 26.0+ (fully upgraded to iOS 26)
- **Language**: Swift 6.0+ (latest as of December 2025)
- **UI Framework**: SwiftUI 6.0 with iOS 26 enhancements
- **Architecture**: MVVM (Model-View-ViewModel) pattern with improved dependency injection
- **Data Layer**: SwiftData for local persistence with iOS 26 optimizations, CloudKit for sync
- **Minimum Target**: iOS 26.0
- **Bundle ID**: org.wesley.sunhat

## Common Development Commands

### Building and Running
```bash
# Open project in Xcode
open SunHat.xcodeproj

# Build the project
xcodebuild -scheme SunHat -configuration Debug build

# Run tests
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.0' test

# Build for release
xcodebuild -scheme SunHat -configuration Release build
```

### Testing Commands
```bash
# Run unit tests only
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.0' -only-testing:SunHatTests test

# Run UI tests only
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.0' -only-testing:SunHatUITests test

# Run specific test
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 18,OS=26.0' -only-testing:SunHatTests/SunHatTests/testExample test
```

## Project Architecture

### Current Structure
- **SunHatApp.swift**: Main app entry point with SwiftData ModelContainer setup
- **ContentView.swift**: Primary UI with NavigationSplitView and basic CRUD operations
- **Item.swift**: SwiftData model for basic timestamp storage
- **Tests**: Standard XCTest setup for unit and UI testing

### Current Architecture (iOS 26 Implementation)
The app has evolved into a sophisticated weather-triggered reminder system with:

- **MVVM Pattern**: SwiftUI Views + ViewModels + SwiftData Models with improved dependency injection
- **SwiftData + CloudKit**: Automatic cross-device sync for reminders with iOS 26 optimizations
- **Weather Integration**: Apple WeatherKit (primary) with iOS 26 APIs, OpenWeatherMap (backup)
- **Background Processing**: iOS 26 BackgroundTasks framework for weather monitoring
- **Modern Concurrency**: Swift 6.0 async/await, actors, structured concurrency with iOS 26 enhancements
- **Location Services**: iOS 26 CoreLocation with temporary location permission support

### Key Data Models (Planned)
```swift
@Model
class WeatherReminder {
    var id: UUID
    var title: String
    var triggerCondition: TriggerCondition
    var isActive: Bool
    var location: LocationData?
    // CloudKit sync automatic with SwiftData
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

### SwiftData Implementation
- Use `@Model` for all persistent entities
- Configure ModelContainer in app entry point (already done)
- Leverage automatic CloudKit sync for cross-device functionality
- Use `@Query` in views for reactive data binding

### Modern Swift Patterns (iOS 26)
- **Concurrency**: Always use async/await, never completion handlers
- **UI Safety**: Use `@MainActor` for UI-bound classes with iOS 26 improvements
- **Actor Isolation**: Background actors for data processing with iOS 26 actor enhancements
- **Structured Concurrency**: TaskGroup and async let for parallel operations
- **Observation Framework**: Use `@Observable` macro for state management
- **Swift 6.0 Features**: Leverage macros, opaque types, and enhanced result builders

### Weather Integration Architecture (iOS 26)
- Primary: Apple WeatherKit for native integration with iOS 26 APIs
  - Uses `WeatherService` protocol with `AppleWeatherKitAPI` implementation
  - Supports iOS 26 enhanced weather data including extended forecasts and detailed conditions
  - Implements `fetchExtendedWeatherData(for:)` for iOS 26+ features
- Backup: OpenWeatherMap for reliability with updated API endpoints
  - Maintains backward compatibility while supporting iOS 26 data structures
- Cache with SwiftData for offline capability with iOS 26 optimizations
  - Automatic CloudKit sync for cross-device weather data
  - Efficient querying with `@Query` and predicates
- Background refresh using iOS 26 BackgroundTasks framework
  - Async/await patterns with `scheduleBackgroundRefreshAsync()`
  - Proper error handling for iOS 26 background task failures
- Support for new iOS 26 weather data types and condition mappings
  - Enhanced weather condition detection for trigger logic
  - Improved temperature and humidity data precision

### Testing Requirements
- Unit tests in `SunHatTests/` for business logic with iOS 26 specific test cases
- UI tests in `SunHatUITests/` for user workflows including iOS 26 permission flows
- Mock weather data for consistent testing with iOS 26 WeatherKit enhancements
- Test both online and offline scenarios with iOS 26 background task patterns
- Specific iOS 26 test coverage:
  - Temporary location permission flows
  - Background weather refresh with async/await patterns
  - Enhanced WeatherKit data mapping and error handling
  - Location accuracy authorization scenarios

## Feature Implementation Notes

The app will implement sophisticated weather triggers including:
- Temperature-based conditions (exact, ranges, "feels like")
- Pattern recognition (consecutive days, averages)
- Seasonal intelligence and transitions
- Composite triggers (temperature + humidity + wind)
- Predictive triggers based on forecasts

## Performance Considerations

- **Battery Optimization**: Intelligent background refresh intervals
- **Memory Management**: Efficient SwiftData queries with predicates
- **Network Efficiency**: Request batching and response caching
- **UI Responsiveness**: Background processing with main thread UI updates

## Privacy Requirements

- **Location Privacy**: Optional precise location, city-level default with iOS 26 temporary permission support
- **Data Minimization**: Store only necessary weather data locally with iOS 26 location accuracy reduction options
- **No Data Sharing**: Zero personal weather data shared externally
- **Compliance**: GDPR and CCPA ready implementation with iOS 26 privacy enhancements

## Documentation

For detailed migration information, see the [iOS 26 Migration Guide](SunHat/Documentation/iOS-26-Migration-Guide.md) which contains:
- Complete list of all changes made during the iOS 26 upgrade
- Breaking changes and migration strategies
- Testing strategy and validation approach
- Performance considerations for iOS 26

## Current Implementation Status

As of December 2025, the app has been successfully upgraded to iOS 26 with:
- ✅ Complete location services integration with iOS 26 APIs
- ✅ Enhanced WeatherKit support with extended weather data
- ✅ Background weather updates using iOS 26 async patterns
- ✅ Full test coverage including iOS 26 specific scenarios
- ✅ Comprehensive documentation of all changes

This project represents a fully upgraded iOS 26 weather-intelligent reminder system following modern iOS development patterns and Apple's design guidelines as of December 2025. The app leverages the latest iOS 26 APIs, Swift 6.0 features, and enhanced architecture patterns for optimal performance and user experience.