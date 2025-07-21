# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Project Overview

This is "hatti", which will become "TempTrigger" - a weather-triggered reminder iOS application. The app concept is a location-aware reminder system that triggers notifications based on temperature conditions and weather patterns rather than traditional calendar scheduling.

## Development Environment

- **Platform**: iOS 18.0+ (targeting iOS 26 design language)
- **Language**: Swift 6.0+
- **UI Framework**: SwiftUI 6.0
- **Architecture**: MVVM (Model-View-ViewModel) pattern
- **Data Layer**: SwiftData for local persistence, CloudKit for sync
- **Minimum Target**: iOS 18.0
- **Bundle ID**: org.wesley.hatti

## Common Development Commands

### Building and Running
```bash
# Open project in Xcode
open hatti.xcodeproj

# Build the project
xcodebuild -scheme hatti -configuration Debug build

# Run tests
xcodebuild -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 15' test

# Build for release
xcodebuild -scheme hatti -configuration Release build
```

### Testing Commands
```bash
# Run unit tests only
xcodebuild -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:hattiTests test

# Run UI tests only  
xcodebuild -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:hattiUITests test

# Run specific test
xcodebuild -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:hattiTests/hattiTests/testExample test
```

## Project Architecture

### Current Structure
- **hattiApp.swift**: Main app entry point with SwiftData ModelContainer setup
- **ContentView.swift**: Primary UI with NavigationSplitView and basic CRUD operations
- **Item.swift**: SwiftData model for basic timestamp storage
- **Tests**: Standard XCTest setup for unit and UI testing

### Planned Architecture (from hatti-plan.md)
The app will evolve into a sophisticated weather-triggered reminder system with:

- **MVVM Pattern**: SwiftUI Views + ViewModels + SwiftData Models
- **SwiftData + CloudKit**: Automatic cross-device sync for reminders
- **Weather Integration**: Apple WeatherKit (primary), OpenWeatherMap (backup)
- **Background Processing**: BackgroundTasks framework for weather monitoring
- **Modern Concurrency**: Swift 6.0 async/await, actors, structured concurrency

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

### Modern Swift Patterns
- **Concurrency**: Always use async/await, never completion handlers
- **UI Safety**: Use `@MainActor` for UI-bound classes
- **Actor Isolation**: Background actors for data processing
- **Structured Concurrency**: TaskGroup and async let for parallel operations

### Weather Integration Architecture
- Primary: Apple WeatherKit for native integration
- Backup: OpenWeatherMap for reliability
- Cache with SwiftData for offline capability
- Background refresh using BackgroundTasks framework

### Testing Requirements
- Unit tests in `hattiTests/` for business logic
- UI tests in `hattiUITests/` for user workflows
- Mock weather data for consistent testing
- Test both online and offline scenarios

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

- **Location Privacy**: Optional precise location, city-level default
- **Data Minimization**: Store only necessary weather data locally
- **No Data Sharing**: Zero personal weather data shared externally
- **Compliance**: GDPR and CCPA ready implementation

This project represents the initial foundation that will evolve into a comprehensive weather-intelligent reminder system following modern iOS development patterns and Apple's design guidelines.
