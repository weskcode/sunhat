//
//  OnboardingCoordinator.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import Combine
import UserNotifications

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    @Published var shouldShowWelcome: Bool = false
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isReturningUser: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    enum OnboardingStep: String, CaseIterable {
        case welcome = "welcome"
        case location = "location"
        case permissions = "permissions"
        case setup = "setup"
        case preferences = "preferences"
        case complete = "complete"
        
        var title: String {
            switch self {
            case .welcome:
                return "Welcome to SunHat"
            case .location:
                return "Location Access"
            case .permissions:
                return "Enable Notifications"
            case .setup:
                return "Create Your First Reminder"
            case .preferences:
                return "Personalize Your Experience"
            case .complete:
                return "You're All Set!"
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .welcome:
                return "Welcome screen for SunHat app"
            case .location:
                return "Location permission setup"
            case .permissions:
                return "Notification permissions setup"
            case .setup:
                return "First reminder creation"
            case .preferences:
                return "User preferences setup"
            case .complete:
                return "Onboarding completion"
            }
        }
    }
    
    init() {
        self.hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        self.isReturningUser = userDefaults.bool(forKey: "isReturningUser")
        
        // Show welcome screen for new users or if explicitly requested
        if !hasCompletedOnboarding {
            shouldShowWelcome = true
        }
    }
    
    func startOnboarding() {
        currentStep = .welcome
        shouldShowWelcome = true
        
        // Mark as returning user for future launches
        userDefaults.set(true, forKey: "isReturningUser")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        shouldShowWelcome = false
        currentStep = .complete
        
        // Haptic feedback for completion
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func skipOnboarding() {
        hasCompletedOnboarding = true
        shouldShowWelcome = false
        
        // Light haptic feedback for skip
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func nextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex < OnboardingStep.allCases.count - 1 else {
            completeOnboarding()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep = OnboardingStep.allCases[currentIndex + 1]
        }
        
        // Haptic feedback for progression
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep = OnboardingStep.allCases[currentIndex - 1]
        }
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        currentStep = .welcome
        shouldShowWelcome = true
        userDefaults.removeObject(forKey: "isReturningUser")
    }
    
    var progress: Double {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep) else {
            return 0.0
        }
        return Double(currentIndex) / Double(OnboardingStep.allCases.count - 1)
    }
    
    var isLastStep: Bool {
        currentStep == OnboardingStep.allCases.last
    }
    
    var isFirstStep: Bool {
        currentStep == OnboardingStep.allCases.first
    }
}

// MARK: - Onboarding Container View

struct OnboardingContainerView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    
    var body: some View {
        Group {
            if coordinator.shouldShowWelcome {
                onboardingFlow
                    .transition(reduceMotion ? .opacity : .weatherSlide)
            } else {
                // Main app content would go here
                ContentView()
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.5), value: coordinator.shouldShowWelcome)
        .environmentObject(coordinator)
    }
    
    private var onboardingFlow: some View {
        Group {
            switch coordinator.currentStep {
            case .welcome:
                WelcomeView()
                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
            case .location:
                LocationPermissionView()
                    .transition(reduceMotion ? .opacity : .weatherSlide)
            case .permissions:
                NotificationPermissionView()
                    .transition(reduceMotion ? .opacity : .weatherSlide)
            case .setup:
                FirstReminderCreationView()
                    .transition(reduceMotion ? .opacity : .weatherSlide)
            case .preferences:
                UserPreferencesOnboardingView()
                    .transition(reduceMotion ? .opacity : .weatherSlide)
            case .complete:
                CompletionView()
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4), value: coordinator.currentStep)
    }
}

// MARK: - Placeholder Views for Future Implementation

// NOTE: PermissionsView has been replaced by NotificationPermissionView
// The comprehensive notification permission screen is now implemented in NotificationPermissionView.swift

struct SetupView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Create Your First Reminder")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            Text("Let's set up a simple weather reminder")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Reminder") {
                coordinator.nextStep()
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Button("Skip") {
                coordinator.nextStep()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("First reminder setup")
    }
}

struct CompletionView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .accessibilityHidden(true)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            Text("SunHat is ready to send you smart weather reminders")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Get Started") {
                coordinator.completeOnboarding()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding complete")
        .accessibilityAction(named: "Complete setup") {
            coordinator.completeOnboarding()
        }
    }
}

// MARK: - Enhanced Welcome View with Accessibility

extension WelcomeView {
    var accessibilityEnhancedBody: some View {
        body
            .accessibilityElement(children: .contain)
            .accessibilityLabel("SunHat welcome screen")
            .accessibilityHint("Introduces smart weather-based reminders with comparison examples")
            .accessibilityAction(named: "Start onboarding") {
                // This should be handled by the coordinator
            }
            .accessibilityAction(named: "Skip onboarding") {
                // This should be handled by the coordinator
            }
            .dynamicTypeSize(.large ... .accessibility5)
    }
}

// MARK: - Accessibility Extensions

extension View {
    func accessibilityWeatherIcon() -> some View {
        self
            .accessibilityHidden(true) // Weather icons are decorative
    }
    
    func accessibilityTemperatureDisplay(_ temperature: String) -> some View {
        self
            .accessibilityLabel("Temperature: \(temperature)")
            .accessibilityValue(temperature)
    }
    
    func accessibilityComparisonCard(title: String, weatherBased: String, timeBased: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) comparison")
            .accessibilityValue("Weather-based: \(weatherBased). Time-based: \(timeBased)")
            .accessibilityHint("Shows the advantage of weather-based reminders")
    }
}

// MARK: - Reduced Motion Support

struct ReducedMotionWrapper<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .animation(reduceMotion ? .none : .default, value: UUID())
    }
}

// MARK: - High Contrast Support

extension Color {
    static func adaptiveForContrast(
        normal: Color,
        highContrast: Color,
        differentiateWithoutColor: Bool
    ) -> Color {
        differentiateWithoutColor ? highContrast : normal
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    OnboardingContainerView()
}

#Preview("Welcome View") {
    WelcomeView()
}

#Preview("Dark Mode") {
    OnboardingContainerView()
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    WelcomeView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
