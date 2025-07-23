//
//  NotificationPermissionView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import UserNotifications
import Combine

struct NotificationPermissionView: View {
    @StateObject private var notificationManager = NotificationPermissionManager()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var showHeader = false
    @State private var showMockNotifications = false
    @State private var showExplanation = false
    @State private var showButtons = false
    @State private var isRequestingPermission = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                        .padding(.top, geometry.safeAreaInsets.top + 10)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header section
                            headerSection
                                .padding(.top, 30)
                            
                            // Mock notifications section
                            mockNotificationsSection
                                .padding(.top, 40)
                            
                            // Explanation section
                            explanationSection
                                .padding(.top, 40)
                            
                            // Action buttons
                            actionButtonsSection
                                .padding(.top, 50)
                                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 40))
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear {
            startAnimationSequence()
            notificationManager.setupNotificationCategories()
        }
        .alert("Notification Access", isPresented: $notificationManager.showPermissionDeniedAlert) {
            Button("Settings") {
                notificationManager.openAppSettings()
            }
            Button("Continue Without", role: .cancel) {
                coordinator.nextStep()
            }
        } message: {
            Text("To receive timely weather reminders, hatti needs notification access. You can enable this in Settings or continue without notifications.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notification permission request")
        .accessibilityHint("Step 3 of 5 in the onboarding process")
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < 3 ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == 2 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: index == 2)
                }
            }
            
            Text("Step 3 of 5")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress: Step 3 of 5")
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // Notification bell with animated rings
            ZStack {
                // Animated notification rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.clear],
                                startPoint: .center,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100 + CGFloat(index * 25), height: 100 + CGFloat(index * 25))
                        .scaleEffect(showHeader ? 1.0 : 0.3)
                        .opacity(showHeader ? 0.6 : 0.0)
                        .animation(
                            .easeOut(duration: 1.0 + Double(index) * 0.2).delay(0.2 + Double(index) * 0.15),
                            value: showHeader
                        )
                }
                
                // Main notification bell
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 5)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 35, weight: .medium))
                        .foregroundColor(.white)
                }
                .scaleEffect(showHeader ? 1.0 : 0.5)
                .opacity(showHeader ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.1), value: showHeader)
            }
            .accessibilityHidden(true)
            
            // Title and subtitle
            VStack(spacing: 12) {
                Text("Stay in the Loop")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 34, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Get notified when weather conditions are perfect for your activities")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .opacity(showHeader ? 1.0 : 0.0)
            .offset(y: showHeader ? 0 : 20)
            .animation(.easeOut(duration: 0.8).delay(0.6), value: showHeader)
        }
    }
    
    // MARK: - Mock Notifications Section
    
    private var mockNotificationsSection: some View {
        VStack(spacing: 20) {
            Text("Here's what you'll receive:")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .opacity(showMockNotifications ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(1.0), value: showMockNotifications)
            
            VStack(spacing: 12) {
                MockNotificationCard(
                    type: .weatherTrigger,
                    animationDelay: 1.2
                )
                
                MockNotificationCard(
                    type: .dailySummary,
                    animationDelay: 1.4
                )
                
                MockNotificationCard(
                    type: .severalWeather,
                    animationDelay: 1.6
                )
            }
            .opacity(showMockNotifications ? 1.0 : 0.0)
            .offset(y: showMockNotifications ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(1.2), value: showMockNotifications)
        }
    }
    
    // MARK: - Explanation Section
    
    private var explanationSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                NotificationBenefit(
                    icon: "target",
                    title: "Perfect Timing",
                    description: "Notifications arrive exactly when weather conditions match your preferences",
                    color: .blue,
                    animationDelay: 1.8
                )
                
                NotificationBenefit(
                    icon: "moon.zzz",
                    title: "Respect Your Schedule",
                    description: "Smart delivery times that won't disturb your sleep or quiet hours",
                    color: .purple,
                    animationDelay: 2.0
                )
                
                NotificationBenefit(
                    icon: "slider.horizontal.3",
                    title: "Fully Customizable",
                    description: "Choose which reminders to receive and when you want them",
                    color: .green,
                    animationDelay: 2.2
                )
                
                NotificationBenefit(
                    icon: "shield.lefthalf.filled",
                    title: "Privacy Protected",
                    description: "All notifications are generated locally on your device",
                    color: .orange,
                    animationDelay: 2.4
                )
            }
            .opacity(showExplanation ? 1.0 : 0.0)
            .offset(y: showExplanation ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(1.8), value: showExplanation)
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary button - Enable Notifications
            Button(action: {
                requestNotificationPermission()
            }) {
                HStack(spacing: 12) {
                    if isRequestingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "bell.badge.fill")
                            .font(.title3)
                    }
                    
                    Text(isRequestingPermission ? "Requesting Permission..." : "Enable Notifications")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: isRequestingPermission ? 
                            [Color.gray, Color.gray.opacity(0.8)] :
                            [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isRequestingPermission)
            .accessibilityLabel("Enable notifications")
            .accessibilityHint("Grants permission to receive weather-based reminder notifications")
            
            // Secondary button - Continue Without
            Button(action: {
                coordinator.nextStep()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.body)
                    Text("Continue Without Notifications")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Continue without notifications")
            .accessibilityHint("Skip notification permissions and proceed to the next step")
            
            // Privacy notice
            privacyNotice
        }
        .opacity(showButtons ? 1.0 : 0.0)
        .offset(y: showButtons ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(2.6), value: showButtons)
    }
    
    private var privacyNotice: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("About notifications")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text("You can always change notification settings later in the app or device Settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("About notifications: You can always change notification settings later in the app or device Settings.")
    }
    
    // MARK: - Helper Methods
    
    private func startAnimationSequence() {
        guard !reduceMotion else {
            // Show all content immediately for reduced motion
            showHeader = true
            showMockNotifications = true
            showExplanation = true
            showButtons = true
            return
        }
        
        withAnimation {
            showHeader = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showMockNotifications = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showExplanation = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation {
                showButtons = true
            }
        }
    }
    
    private func requestNotificationPermission() {
        guard !isRequestingPermission else { return }
        
        isRequestingPermission = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        notificationManager.requestNotificationPermission { [self] granted in
            DispatchQueue.main.async {
                isRequestingPermission = false
                
                if granted {
                    // Success haptic
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // Proceed to next step
                    coordinator.nextStep()
                } else {
                    // Handle denial through the notification manager's alert
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.warning)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.05),
                Color.black
            ] : [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.93, green: 0.96, blue: 1.0),
                Color(red: 0.97, green: 0.98, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Supporting Views

struct MockNotificationCard: View {
    let type: MockNotificationType
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)
            
            // Notification content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("hatti")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(type.time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(type.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(type.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mock notification: \(type.title). \(type.body)")
    }
}

struct NotificationBenefit: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(x: isVisible ? 0 : -30)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Mock Notification Types

enum MockNotificationType {
    case weatherTrigger
    case dailySummary
    case severalWeather
    
    var title: String {
        switch self {
        case .weatherTrigger:
            return "Perfect gardening weather! 🌱"
        case .dailySummary:
            return "Daily weather summary"
        case .severalWeather:
            return "Severe weather alert"
        }
    }
    
    var body: String {
        switch self {
        case .weatherTrigger:
            return "It's 68°F and sunny - ideal conditions for your outdoor gardening reminder."
        case .dailySummary:
            return "Today's high: 72°F. Your running reminder is set for 6 PM when it cools to 65°F."
        case .severalWeather:
            return "Heavy rain expected at 3 PM. Your hiking reminder has been automatically postponed."
        }
    }
    
    var time: String {
        switch self {
        case .weatherTrigger:
            return "now"
        case .dailySummary:
            return "8:00 AM"
        case .severalWeather:
            return "2:45 PM"
        }
    }
}

// MARK: - Notification Permission Manager

@MainActor
final class NotificationPermissionManager: NSObject, ObservableObject {
    @Published var showPermissionDeniedAlert = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        checkNotificationStatus()
    }
    
    func setupNotificationCategories() {
        let weatherTriggerActions = [
            UNNotificationAction(
                identifier: "VIEW_DETAILS",
                title: "View Details",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "SNOOZE_1H",
                title: "Snooze 1 Hour",
                options: []
            )
        ]
        
        let weatherTriggerCategory = UNNotificationCategory(
            identifier: NotificationCategory.weatherTrigger.rawValue,
            actions: weatherTriggerActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let dailySummaryActions = [
            UNNotificationAction(
                identifier: "VIEW_FORECAST",
                title: "View Forecast",
                options: [.foreground]
            )
        ]
        
        let dailySummaryCategory = UNNotificationCategory(
            identifier: NotificationCategory.dailySummary.rawValue,
            actions: dailySummaryActions,
            intentIdentifiers: [],
            options: []
        )
        
        let severeWeatherActions = [
            UNNotificationAction(
                identifier: "VIEW_ALERT",
                title: "View Alert",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "POSTPONE_REMINDER",
                title: "Postpone Reminder",
                options: []
            )
        ]
        
        let severeWeatherCategory = UNNotificationCategory(
            identifier: NotificationCategory.severeWeather.rawValue,
            actions: severeWeatherActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let reminderCompletedActions = [
            UNNotificationAction(
                identifier: "MARK_DONE",
                title: "Mark Done",
                options: []
            ),
            UNNotificationAction(
                identifier: "RESCHEDULE",
                title: "Reschedule",
                options: [.foreground]
            )
        ]
        
        let reminderCompletedCategory = UNNotificationCategory(
            identifier: NotificationCategory.reminderCompleted.rawValue,
            actions: reminderCompletedActions,
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            weatherTriggerCategory,
            dailySummaryCategory,
            severeWeatherCategory,
            reminderCompletedCategory
        ])
    }
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound, .provisional]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.checkNotificationStatus()
                
                if granted {
                    completion(true)
                } else {
                    self?.showPermissionDeniedAlert = true
                    completion(false)
                }
            }
        }
    }
    
    func checkNotificationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        Task { @MainActor in
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Notification Categories

enum NotificationCategory: String, CaseIterable {
    case weatherTrigger = "WEATHER_TRIGGER"
    case dailySummary = "DAILY_SUMMARY"
    case severeWeather = "SEVERE_WEATHER"
    case reminderCompleted = "REMINDER_COMPLETED"
    
    var displayName: String {
        switch self {
        case .weatherTrigger:
            return "Weather Triggers"
        case .dailySummary:
            return "Daily Summaries"
        case .severeWeather:
            return "Severe Weather Alerts"
        case .reminderCompleted:
            return "Reminder Completions"
        }
    }
    
    var description: String {
        switch self {
        case .weatherTrigger:
            return "Notifications when weather conditions match your reminders"
        case .dailySummary:
            return "Daily weather summaries and upcoming reminders"
        case .severeWeather:
            return "Important alerts about severe weather affecting your reminders"
        case .reminderCompleted:
            return "Confirmations when weather-based reminders are completed"
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationPermissionView()
        .environmentObject(OnboardingCoordinator())
}

#Preview("Dark Mode") {
    NotificationPermissionView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}