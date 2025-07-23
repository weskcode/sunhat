# Technology Stack & Build System

## iOS Development Stack
- **Language**: Swift 6.0+ with strict concurrency
- **UI Framework**: SwiftUI 6.0 (iOS 18.0+ minimum target)
- **Architecture**: MVVM (Model-View-ViewModel) with Combine for reactive programming
- **Concurrency**: Swift 6 structured concurrency with async/await and actors

## Data & Persistence
- **Local Storage**: SwiftData for modern Core Data replacement
- **Cloud Sync**: CloudKit integration for seamless cross-device synchronization
- **Data Models**: `@Model` classes with automatic persistence and relationships

## Weather & Location Services
- **Primary Weather API**: Apple WeatherKit (requires entitlement)
- **Backup Weather API**: OpenWeatherMap with fallback support
- **Location Services**: Core Location with privacy-focused design
- **Background Processing**: BackgroundTasks framework for weather monitoring

## Key Frameworks & Dependencies
- **WeatherKit**: Apple's official weather service
- **CoreLocation**: Location services and geocoding
- **UserNotifications**: Rich notification system
- **Combine**: Reactive programming and data binding
- **SwiftData**: Modern data persistence
- **CloudKit**: Cloud synchronization

## Build Configuration
- **Xcode Project**: Standard iOS app project with entitlements
- **Deployment Target**: iOS 18.0+
- **Bundle ID**: com.hatti.app (inferred from entitlements)
- **Capabilities**: WeatherKit, CloudKit, Background Modes, Location Services

## Background Modes
- `remote-notification`: Push notification handling
- `background-fetch`: Periodic weather data updates
- `background-processing`: Trigger condition evaluation

## Common Commands

### Building
```bash
# Build for simulator
xcodebuild -project hatti.xcodeproj -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build

# Build for device
xcodebuild -project hatti.xcodeproj -scheme hatti -destination generic/platform=iOS build
```

### Testing
```bash
# Run unit tests
xcodebuild test -project hatti.xcodeproj -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'

# Run specific test class
xcodebuild test -project hatti.xcodeproj -scheme hatti -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:hattiTests/WeatherServiceTests
```

### Code Quality
```bash
# Swift format (if using SwiftFormat)
swiftformat hatti/

# Swift lint (if using SwiftLint)
swiftlint lint hatti/
```

## Development Notes
- Uses modern Swift 6 concurrency patterns with `@MainActor` for UI updates
- Implements Sendable protocols for thread-safe data transfer
- Weather APIs use DTO (Data Transfer Object) pattern for protocol boundaries
- Comprehensive error handling with custom WeatherError types
- Background processing optimized for battery life