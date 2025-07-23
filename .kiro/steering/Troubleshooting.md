---
inclusion: always
---

# Troubleshooting & Development Guidelines

## Common Build Issues

### WeatherKit Entitlement
- Ensure `hatti.entitlements` contains WeatherKit capability
- Verify Apple Developer account has WeatherKit enabled
- Check bundle ID matches registered app identifier

### Swift 6 Concurrency
- All UI updates must use `@MainActor`
- Use `async/await` instead of completion handlers
- Implement `Sendable` for data passed between actors
- Avoid `@escaping` closures in favor of structured concurrency

### SwiftData Migration
- Model changes require migration strategies
- Use `@Model` macro for all persistent entities
- Relationships must be properly configured with inverse properties

## Performance Optimization

### Background Processing
- Limit background weather fetches to essential updates only
- Use `BGTaskScheduler` for efficient background execution
- Implement exponential backoff for failed API requests
- Cache weather data to reduce API calls

### Memory Management
- Use weak references in Combine subscriptions
- Dispose of unused location monitoring sessions
- Implement proper cleanup in view model deinitializers

## API Integration Patterns

### Weather Service Error Handling
```swift
// Always implement fallback strategies
do {
    let weather = try await weatherService.fetchWeather()
} catch WeatherError.rateLimited {
    // Use cached data or alternative provider
} catch WeatherError.networkUnavailable {
    // Queue for retry with exponential backoff
}
```

### Location Services
- Request minimal location accuracy needed
- Stop location updates when not actively needed
- Handle permission changes gracefully
- Implement location caching for frequently used spots

## Testing Strategies

### Unit Testing
- Mock weather services for consistent test results
- Test trigger conditions with various weather scenarios
- Verify notification scheduling logic
- Test background processing without actual background execution

### UI Testing
- Use accessibility identifiers for reliable element selection
- Test permission flows with simulator settings
- Verify onboarding flow completion
- Test reminder creation and editing workflows

## Debugging Tips

### Weather API Issues
- Check API key validity and rate limits
- Verify location coordinates are valid
- Log weather responses for debugging trigger failures
- Test with multiple weather providers

### Notification Problems
- Verify notification permissions are granted
- Check notification scheduling timing
- Test with different device notification settings
- Validate notification content and actions

### Background Execution
- Use Xcode's background app refresh simulation
- Monitor background task completion
- Check system logs for background processing errors
- Verify background modes are properly configured

## Code Quality Standards

### Architecture Compliance
- Follow MVVM pattern strictly
- Keep business logic in service layers
- Use dependency injection for testability
- Maintain clear separation of concerns

### Swift Style Guidelines
- Use descriptive variable and function names
- Implement proper error handling with custom error types
- Follow Swift API design guidelines
- Use extensions to organize code functionality

### Documentation Requirements
- Document complex trigger logic algorithms
- Explain weather API integration patterns
- Provide examples for custom trigger conditions
- Document background processing workflows

## Common Pitfalls

### Concurrency Issues
- Avoid mixing old-style completion handlers with async/await
- Don't access UI elements from background threads
- Use proper actor isolation for shared state
- Implement thread-safe data structures

### Weather Data Handling
- Don't assume weather data is always available
- Handle timezone differences in weather forecasts
- Account for weather API response delays
- Implement proper data validation

### User Experience
- Provide clear feedback for permission requests
- Handle offline scenarios gracefully
- Implement proper loading states
- Ensure accessibility compliance

## Emergency Fixes

### Critical Issues
- Weather service failures: Implement immediate fallback to cached data
- Notification failures: Provide manual trigger options
- Location access denied: Offer manual location entry
- Background processing suspended: Queue operations for foreground execution

### Quick Diagnostics
- Check device logs for weather API errors
- Verify notification permissions in Settings
- Test location services with different accuracy settings
- Monitor memory usage during background processing

OS App Development Rules for AI – SwiftUI (Swift 6+, iOS 17+)
	1.	PROJECT SETUP & ARCHITECTURE

	•	Use Swift 6 and target iOS 17 or newer.
	•	Follow MVVM or Clean Architecture for separation of concerns.
	•	Use @main and the App protocol as the app entry point.
	•	Organize files by feature or module (e.g., Features/Home, Features/Settings).
	•	Prefer Swift Package Manager (SPM) for dependencies.

	2.	SWIFTUI BEST PRACTICES

	•	Use property wrappers correctly:
	•	@State for local UI state
	•	@Binding for two-way communication
	•	@ObservedObject for child view models
	•	@EnvironmentObject for global/shared state
	•	Break large views into smaller subcomponents.
	•	Use .task for async loading instead of .onAppear.
	•	Use NavigationStack, NavigationLink, and navigationDestination (iOS 16+).
	•	Avoid deprecated APIs like NavigationView.
	•	Create reusable styling with custom view modifiers.

	3.	CONCURRENCY (SWIFT 6)

	•	Use @MainActor for view models and UI-related code.
	•	Prefer Task and await over GCD (DispatchQueue).
	•	Avoid incorrect use of @Sendable; respect actor isolation.
	•	Use Task.detached(priority: .background) for background tasks.

	4.	DATA MANAGEMENT

	•	Use SwiftData or Core Data with proper model definitions.
	•	Annotate models with @Model for SwiftData.
	•	Use @Query and @ModelContext for data access in views.
	•	Encapsulate API or storage logic in async service classes.

	5.	ERROR HANDLING

	•	Use do-catch for async operations.
	•	Display user-friendly errors using .alert and .confirmationDialog.
	•	Log errors with os_log, print, or tools like Firebase Crashlytics.

	6.	APP LIFECYCLE & STATE

	•	Use a central @MainActor AppState: ObservableObject to manage app-wide state.
	•	Detect lifecycle changes using @Environment(.scenePhase).
	•	Integrate push notifications, deep linking, background tasks with UIApplicationDelegateAdaptor if needed.

	7.	ACCESSIBILITY & INTERNATIONALIZATION

	•	Set .accessibilityLabel, .accessibilityValue, and .accessibilityHint for UI elements.
	•	Use Text(verbatim:) or LocalizedStringKey for localization.
	•	Prefer SF Symbols and ensure accessibility compliance.

	8.	UI/UX STANDARDS

	•	Follow Apple’s Human Interface Guidelines (HIG).
	•	Use Spacer(), padding(), frame(), and alignment for layout control.
	•	Use .toolbar with .navigationTitle and toolbarItem placements.
	•	Support Dynamic Type via .font(.body), avoid hardcoded sizes.

	9.	TESTING & DEBUGGING

	•	Use #Preview syntax (iOS 17+) for SwiftUI previews.
	•	Write unit tests using XCTest for services and view models.
	•	Use @Testable import and mock dependencies for testability.
	•	Log behavior in debug builds and use Instruments to profile.
	•	Use Xcode Memory Graph to check for memory leaks.

	10.	APP STORE READINESS

	•	Set up App Icons and Launch Screens via Asset Catalog.
	•	Include usage descriptions in Info.plist (e.g., NSCameraUsageDescription).
	•	Ensure compatibility with Light/Dark mode and screen sizes.
	•	Avoid hardcoded UI — use adaptive layout and spacing.
	•	Use TestFlight for testing on multiple devices.

	11.	AI PROMPT COMPLIANCE CHECKLIST
When generating or debugging SwiftUI code, AI should:

	•	Reference Swift 6+ and iOS 17+ APIs.
	•	Check Apple Developer Documentation for function behavior.
	•	Flag deprecated APIs and suggest modern alternatives.
	•	Identify actor-isolation violations and suggest safe workarounds.
	•	Provide minimal, complete, idiomatic, and readable Swift code.
	•	Clearly label any workaround if not a best practice.
	•	Add relevant comments to improve code clarity.