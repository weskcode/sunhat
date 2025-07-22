# Project Structure & Organization

## Root Directory Structure
```
hatti/                          # Main app target
├── Assets.xcassets/           # App icons, colors, images
├── Models/                    # SwiftData model classes
├── Services/                  # Business logic and API services
├── ViewModels/               # MVVM view models with Combine
├── Views/                    # SwiftUI views organized by feature
├── Utilities/                # Helper classes and extensions
├── Resources/                # Configuration files and assets
├── Info.plist               # App configuration
├── hatti.entitlements       # App capabilities and permissions
└── hattiApp.swift           # App entry point with SwiftData container

hattiTests/                   # Unit tests
hattiUITests/                # UI automation tests
hatti.xcodeproj/             # Xcode project configuration
```

## Models Directory (`hatti/Models/`)
SwiftData model classes representing core data entities:
- `WeatherReminder.swift` - Main reminder entity with relationships
- `TriggerCondition.swift` - Weather trigger logic and conditions
- `LocationData.swift` - Geographic location information
- `WeatherData.swift` - Weather information and forecasts
- `NotificationTiming.swift` - Notification scheduling preferences
- `UserPreferences.swift` - User settings and preferences
- `WeatherTypes.swift` - Enums for weather conditions and types

## Services Directory (`hatti/Services/`)
Business logic organized by domain:

### Weather Services (`Services/Weather/`)
- `WeatherAPI.swift` - Weather data fetching with multiple providers
- `WeatherService.swift` - Main weather service coordinator
- `WeatherError.swift` - Custom error types for weather operations
- `BackgroundWeatherManager.swift` - Background weather monitoring
- `WeatherForecastIntegration.swift` - Forecast analysis and integration

### Trigger Engine (`Services/Trigger/`)
- `TriggerEngine.swift` - Core trigger evaluation logic
- `TriggerEngineManager.swift` - Manages trigger lifecycle
- `TriggerEngine+ForecastAnalysis.swift` - Forecast-based trigger analysis
- `TriggerEngine+TrendAnalysis.swift` - Temperature trend detection
- `TriggerEngine+SeasonalAnalysis.swift` - Seasonal pattern recognition

### Location Services (`Services/Location/`)
- `LocationPermissionManager.swift` - Location permission handling

### Background Services (`Services/Background/`)
- `OnboardingCoordinator.swift` - User onboarding flow management

## ViewModels Directory (`hatti/ViewModels/`)
MVVM view models with reactive programming:
- `DashboardViewModel.swift` - Main dashboard state management
- `FirstReminderCreationViewModel.swift` - Guided first reminder creation
- `ComprehensiveReminderCreationViewModel.swift` - Advanced reminder creation
- `ReminderManagementViewModel.swift` - Reminder CRUD operations
- `WeatherViewModel.swift` - Weather display and interaction
- `LocationManagementViewModel.swift` - Location selection and management
- `SettingsViewModel.swift` - App settings and preferences

### Settings ViewModels (`ViewModels/Settings/`)
- `NotificationPreferencesViewModel.swift` - Notification settings
- `DataPrivacyViewModel.swift` - Privacy and data management

## Views Directory (`hatti/Views/`)
SwiftUI views organized by feature area:

### Dashboard (`Views/Dashboard/`)
- `ContentView.swift` - Root content view
- `DashboardView.swift` - Main dashboard interface

### Reminders (`Views/Reminders/`)
- `FirstReminderCreationView.swift` - Guided first reminder creation
- `ComprehensiveReminderCreationView.swift` - Advanced reminder creation
- `DetailedReminderView.swift` - Individual reminder details
- `AllRemindersView.swift` - Reminder list and management
- `ReminderManagementView.swift` - Reminder editing interface

### Location (`Views/Location/`)
- `LocationManagementView.swift` - Location selection interface
- `LocationPermissionView.swift` - Location permission requests
- `LocationPickerView.swift` - Interactive location picker
- `ManualLocationEntryView.swift` - Manual location input

### Weather (`Views/Weather/`)
- `WeatherView.swift` - Weather information display
- `WeatherAlertsView.swift` - Weather alerts and warnings
- `TemperatureTrendChart.swift` - Temperature visualization

### Onboarding (`Views/Onboarding/`)
- `WelcomeView.swift` - App introduction
- `NotificationPermissionView.swift` - Notification permission request
- `UserPreferencesView.swift` - Initial user preferences setup
- `CelebrationView.swift` - Success celebration with animations

### Settings (`Views/Settings/`)
- `SettingsView.swift` - Main settings interface
- `NotificationPreferencesView.swift` - Notification configuration
- `DataPrivacyView.swift` - Privacy settings and data export

### Components (`Views/Components/`)
Reusable UI components:
- `ReminderSummaryCard.swift` - Reminder display card
- `ConditionBuilderView.swift` - Weather condition builder
- `ComparisonCard.swift` - Weather comparison display
- Various component files for specific features

## Utilities Directory (`hatti/Utilities/`)
Helper classes and extensions:
- `Helpers/ButtonStyles.swift` - Custom SwiftUI button styles
- `Extensions/` - Swift extensions (currently empty)

## Resources Directory (`hatti/Resources/`)
Configuration and resource files:
- `Configuration/APIKeys.plist.example` - API key template
- `Configuration/NotificationConfig.swift` - Notification configuration

## Naming Conventions
- **Files**: PascalCase with descriptive names (e.g., `WeatherReminderCreationView.swift`)
- **Classes**: PascalCase matching filename
- **Properties**: camelCase with clear intent
- **Methods**: camelCase with verb-noun pattern
- **Constants**: UPPER_SNAKE_CASE for static constants

## Architecture Patterns
- **MVVM**: Clear separation between Views, ViewModels, and Models
- **Service Layer**: Business logic encapsulated in service classes
- **Repository Pattern**: Data access abstracted through service interfaces
- **Dependency Injection**: Services injected into ViewModels via initializers
- **Reactive Programming**: Combine publishers for data flow and state management

## File Organization Rules
- Group related functionality in dedicated directories
- Keep view-specific components near their parent views
- Separate business logic from UI code
- Use extensions to organize large files by functionality
- Maintain consistent file naming across similar components