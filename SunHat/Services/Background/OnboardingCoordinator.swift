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
    
    @Published var hasCreatedFirstReminder: Bool {
        didSet {
            UserDefaults.standard.set(hasCreatedFirstReminder, forKey: "hasCreatedFirstReminder")
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
        case preferences = "preferences"

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to SunHat"
            case .location:
                return "Location Access"
            case .permissions:
                return "Enable Notifications"
            case .preferences:
                return "Personalize Your Experience"
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
            case .preferences:
                return "User preferences setup"
            }
        }
    }
    
    init() {
        self.hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        self.hasCreatedFirstReminder = userDefaults.bool(forKey: "hasCreatedFirstReminder")
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

        // Haptic feedback for completion
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    func markFirstReminderCreated() {
        hasCreatedFirstReminder = true

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
        hasCreatedFirstReminder = false
        currentStep = .welcome
        shouldShowWelcome = true
        userDefaults.removeObject(forKey: "isReturningUser")
        userDefaults.removeObject(forKey: "hasCreatedFirstReminder")
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
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        onboardingFlow
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4), value: coordinator.currentStep)
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
            case .preferences:
                UserPreferencesOnboardingView()
                    .transition(reduceMotion ? .opacity : .weatherSlide)
            }
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
