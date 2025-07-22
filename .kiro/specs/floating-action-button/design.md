# Design Document

## Overview

The floating action button (FAB) feature will provide a persistent, easily accessible entry point for quick weather-triggered reminder creation throughout the TempTrigger (Hatti) app. The design leverages existing SwiftUI 6.0 components and follows the established MVVM architecture patterns in the codebase, particularly building upon the existing `Models/WeatherReminder.swift`, `Models/TriggerCondition.swift`, and button styles from `Utilities/Helpers/ButtonStyles.swift`.

The FAB will use a radial expansion pattern optimized for one-handed use, with smooth SwiftUI 6.0 animations using Swift 6 structured concurrency and haptic feedback integration. The implementation will be modular and reusable across different views in the app, integrating seamlessly with the existing SwiftData persistence layer and automatic CloudKit synchronization. It follows the iOS 18.0+ minimum target and leverages the established Services/Weather/ architecture.

## Architecture

### Component Structure

```
FloatingActionButton (Main Container)
├── FABButton (Core button component)
├── FABOptionsMenu (Expandable options container)
│   ├── FABTemplateOption (Template buttons)
│   └── FABCustomOption (Custom reminder button)
├── FABViewModel (State management)
└── FABHapticManager (Haptic feedback coordination)
```

### Integration Points

- **SwiftData Models**: Leverages existing `Models/WeatherReminder.swift`, `Models/TriggerCondition.swift`, and `Models/LocationData.swift` models with @Model decorators
- **ViewModels**: Integrates with `ViewModels/ComprehensiveReminderCreationViewModel.swift` patterns for MVVM state management using Combine publishers
- **Button Styles**: Extends the existing `Utilities/Helpers/ButtonStyles.swift` with new FAB-specific styles following SwiftUI 6.0 patterns
- **Navigation**: Integrates with existing SwiftUI NavigationStack patterns for custom reminder creation in Views/Reminders/
- **Location Services**: Uses existing `Models/LocationData.swift` and Core Location integration for automatic location assignment
- **Weather Services**: Connects with `Services/Weather/WeatherAPI.swift` for real-time weather context using Apple WeatherKit and OpenWeatherMap backup
- **Background Processing**: Integrates with BackgroundTasks framework for weather monitoring as established in the tech stack

## Components and Interfaces

### 1. FloatingActionButton (Main Component)

```swift
struct FloatingActionButton: View {
    @StateObject private var viewModel = FABViewModel()
    @State private var isExpanded = false
    @State private var showCustomCreation = false
    
    var body: some View
    // Handles main FAB display, expansion, and coordination
}
```

**Key Properties:**
- `isExpanded`: Controls the expansion state of the FAB
- `showCustomCreation`: Manages navigation to full reminder creation
- `position`: Configurable positioning (bottom-right by default)

### 2. FABViewModel (State Management)

```swift
@MainActor
final class FABViewModel: ObservableObject {
    @Published var selectedTemplate: WeatherReminderTemplate?
    @Published var isCreatingReminder = false
    @Published var currentLocation: LocationData?
    
    private var modelContext: ModelContext?
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    func configure(modelContext: ModelContext)
    func createQuickReminder(from template: WeatherReminderTemplate) async -> Bool
    func handleTemplateSelection(_ template: WeatherReminderTemplate)
    private func buildTriggerCondition(from template: WeatherReminderTemplate) -> TriggerCondition
    
    // Follows Swift 6 concurrency patterns with structured concurrency
    // Integrates with existing WeatherAPI.swift for weather context
    // Uses Combine for reactive state management like ComprehensiveReminderCreationViewModel
}
```

**Responsibilities:**
- Weather template selection logic
- Quick WeatherReminder creation with SwiftData persistence
- Integration with existing reminder creation flow
- State management for animations
- Location services integration
- CloudKit synchronization through SwiftData

### 3. FABButton (Core Button)

```swift
struct FABButton: View {
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View
    // Main circular button with rotation animation
}
```

**Features:**
- Smooth rotation animation (+ to × transition)
- Gradient background with shadow
- Accessibility support
- Haptic feedback integration

### 4. FABOptionsMenu (Expandable Menu)

```swift
struct FABOptionsMenu: View {
    let isExpanded: Bool
    let templates: [WeatherReminderTemplate]
    let onTemplateSelect: (WeatherReminderTemplate) -> Void
    let onCustomSelect: () -> Void
    
    var body: some View
    // Radial or vertical layout of weather-based options
}
```

**Layout Strategy:**
- **iPhone SE/Mini**: Vertical stack layout for easier thumb reach
- **Standard iPhones**: Radial arc layout for visual appeal
- **Plus/Pro Max**: Radial layout with larger touch targets

### 5. FABTemplateOption (Template Buttons)

```swift
struct FABTemplateOption: View {
    let template: WeatherReminderTemplate
    let animationDelay: Double
    let onSelect: () -> Void
    
    var body: some View
    // Individual weather template option with temperature range and activity icon
}
```

**Features:**
- Staggered entrance animations
- Template-specific colors and icons
- Compact design for space efficiency
- Clear visual hierarchy

## Data Models

### WeatherReminderTemplate

```swift
struct WeatherReminderTemplate: Identifiable {
    let id = UUID()
    let title: String
    let category: ReminderCategory
    let triggerType: TriggerType
    let temperatureRange: ClosedRange<Double>?
    let exactTemperature: Double?
    let icon: String
    let color: Color
    let description: String
}
```

### FABConfiguration

```swift
struct FABConfiguration {
    let position: FABPosition
    let templates: [WeatherReminderTemplate]
    let animationDuration: Double
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
}

enum FABPosition {
    case bottomRight
    case bottomLeft
    case bottomCenter
}
```

### QuickReminderRequest

```swift
struct QuickReminderRequest {
    let template: WeatherReminderTemplate
    let location: LocationData?
    let createdAt: Date
    let triggerCondition: TriggerCondition
}
```

## Error Handling

### Error Types

```swift
enum FABError: LocalizedError {
    case templateNotFound
    case locationUnavailable
    case reminderCreationFailed(Error)
    case permissionDenied
    
    var errorDescription: String? {
        // User-friendly error messages
    }
}
```

### Error Handling Strategy

1. **Template Selection Errors**: Graceful fallback to custom creation
2. **Location Errors**: Prompt user for manual location or use last known
3. **Creation Errors**: Show inline error message with retry option
4. **Permission Errors**: Guide user to settings with clear instructions

### Error Recovery

- **Automatic Retry**: For transient network/location errors
- **Fallback Options**: Alternative creation paths when primary fails
- **User Guidance**: Clear messaging for user-actionable errors

## Testing Strategy

### Unit Tests

1. **FABViewModel Tests**
   - Template selection logic
   - Quick reminder creation
   - Error handling scenarios
   - State management

2. **Animation Tests**
   - Expansion/collapse timing
   - Staggered option animations
   - Accessibility motion reduction

3. **Haptic Feedback Tests**
   - Correct feedback types for actions
   - Accessibility considerations
   - Performance impact

### Integration Tests

1. **Template Integration**
   - Verify template data loading
   - Test template-to-reminder conversion
   - Validate existing template compatibility

2. **Navigation Integration**
   - Custom reminder flow navigation
   - Back navigation handling
   - State preservation

3. **Location Integration**
   - Automatic location assignment
   - Location permission handling
   - Fallback location strategies

### UI Tests

1. **Accessibility Testing**
   - VoiceOver navigation
   - Dynamic Type support
   - Reduced motion compliance
   - Color contrast validation

2. **Device Testing**
   - iPhone SE to Pro Max compatibility
   - One-handed use validation
   - Touch target size verification
   - Safe area handling

3. **Animation Testing**
   - Smooth 60fps performance
   - Proper animation interruption
   - Memory usage during animations

### Performance Testing

1. **Animation Performance**
   - Frame rate monitoring during expansion
   - Memory usage during complex animations
   - Battery impact assessment

2. **Haptic Performance**
   - Feedback timing accuracy
   - System resource usage
   - User preference compliance

## Implementation Phases

### Phase 1: Core FAB Structure
- Basic FAB button with expand/collapse
- Simple vertical layout for options
- Basic template integration
- Fundamental haptic feedback

### Phase 2: Enhanced Animations
- Smooth SwiftUI transitions
- Staggered option animations
- Advanced button transformations
- Performance optimization

### Phase 3: Advanced Features
- Radial layout for larger devices
- Custom reminder integration
- Enhanced error handling
- Accessibility improvements

### Phase 4: Polish and Optimization
- Advanced haptic patterns
- Performance fine-tuning
- Comprehensive testing
- Documentation completion

## Accessibility Considerations

### VoiceOver Support
- Descriptive labels for all interactive elements
- Logical navigation order
- State announcements for expansion/collapse
- Template descriptions for context

### Dynamic Type
- Scalable text in option labels
- Flexible layout for larger text sizes
- Maintained touch targets at all sizes

### Reduced Motion
- Alternative animations for motion-sensitive users
- Instant state changes when motion is reduced
- Maintained functionality without animations

### Color and Contrast
- High contrast mode support
- Color-independent information conveyance
- Template differentiation beyond color

## Performance Considerations

### Animation Optimization
- Use of SwiftUI's built-in animation system
- Efficient view updates with @State and @Published
- Minimal view hierarchy for smooth animations

### Memory Management
- Lazy loading of template options
- Efficient image and icon caching
- Proper cleanup of animation resources

### Battery Impact
- Optimized haptic feedback usage
- Efficient animation timing
- Minimal background processing

## Security and Privacy

### Location Privacy
- Respect existing location permission settings
- Clear user communication about location usage
- Graceful degradation without location access

### Data Handling
- No sensitive data storage in FAB component
- Secure template data handling
- Proper cleanup of temporary creation data