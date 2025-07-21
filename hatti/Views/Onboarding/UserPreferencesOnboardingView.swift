//
//  UserPreferencesOnboardingView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct UserPreferencesOnboardingView: View {
    @StateObject private var viewModel = UserPreferencesViewModel()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    
    @State private var showContent = false
    @State private var isSaving = false
    
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
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Header
                            headerSection
                                .padding(.top, 20)
                            
                            // Preferences sections
                            preferencesContent
                                .padding(.top, 24)
                            
                            // Finish button
                            finishButton
                                .padding(.top, 32)
                                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24))
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadPreferences(from: modelContext)
            startAnimation()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("User preferences setup")
        .accessibilityHint("Final step of onboarding - step 5 of 6")
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < 5 ? Color.blue : Color.blue.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == 4 ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: index == 4)
                }
            }
            
            Text("Step 5 of 6")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress: Step 5 of 6")
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Settings icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)
                
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.8).delay(0.2), value: showContent)
            .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("Personalize TempTrigger")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 24 : 28, relativeTo: .title2))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Set up your preferences to get the perfect weather reminders")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 15)
            .animation(.easeOut(duration: 0.8).delay(0.4), value: showContent)
        }
    }
    
    // MARK: - Preferences Content
    
    private var preferencesContent: some View {
        VStack(spacing: 20) {
            // Temperature unit selection
            MinimalPreferenceSection(
                icon: "thermometer.medium",
                title: "Temperature Unit",
                animationDelay: 0.6
            ) {
                CompactTemperatureSelector(
                    selectedUnit: $viewModel.preferences.temperatureUnit
                )
            }
            
            // Activity interests
            MinimalPreferenceSection(
                icon: "heart.fill",
                title: "Activity Interests",
                subtitle: "What would you like weather reminders for?",
                animationDelay: 0.8
            ) {
                CompactActivitySelector(
                    selectedInterests: $viewModel.selectedActivityInterests
                )
            }
            
            // Notification timing
            MinimalPreferenceSection(
                icon: "bell.badge",
                title: "Notification Timing",
                animationDelay: 1.0
            ) {
                CompactTimingSelector(
                    selectedTiming: $viewModel.preferences.defaultNotificationTiming
                )
            }
            
            // Quiet hours
            MinimalPreferenceSection(
                icon: "moon.zzz",
                title: "Quiet Hours",
                subtitle: "Avoid notifications during sleep time",
                animationDelay: 1.2
            ) {
                CompactQuietHoursToggle(
                    enabled: $viewModel.preferences.quietHoursEnabled,
                    startTime: $viewModel.preferences.quietHoursStart,
                    endTime: $viewModel.preferences.quietHoursEnd
                )
            }
        }
        .opacity(showContent ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.8).delay(0.6), value: showContent)
    }
    
    // MARK: - Finish Button
    
    private var finishButton: some View {
        Button(action: {
            finishSetup()
        }) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                }
                
                Text(isSaving ? "Saving..." : "Finish Setup")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: isSaving ? 
                        [Color.gray.opacity(0.8), Color.gray.opacity(0.6)] :
                        [Color.green, Color.green.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isSaving ? .clear : .green.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSaving)
        .opacity(showContent ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.8).delay(1.4), value: showContent)
        .accessibilityLabel("Finish setup and save preferences")
        .accessibilityHint("Complete onboarding and save your personalized settings")
    }
    
    // MARK: - Helper Methods
    
    private func startAnimation() {
        guard !reduceMotion else {
            showContent = true
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
            }
        }
    }
    
    private func finishSetup() {
        guard !isSaving else { return }
        
        isSaving = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            await viewModel.savePreferences(to: modelContext)
            
            DispatchQueue.main.async {
                isSaving = false
                
                // Success haptic
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
                // Move to completion step
                coordinator.nextStep()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.04),
                Color.black
            ] : [
                Color(red: 0.98, green: 0.99, blue: 1.0),
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Minimal Preference Section

struct MinimalPreferenceSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let animationDelay: Double
    let content: Content
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(icon: String, title: String, subtitle: String? = nil, animationDelay: Double, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.animationDelay = animationDelay
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            // Section content
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 15)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

// MARK: - Compact Temperature Selector

struct CompactTemperatureSelector: View {
    @Binding var selectedUnit: TemperatureUnit
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                Button(action: {
                    selectedUnit = unit
                }) {
                    HStack(spacing: 6) {
                        Text(unit.symbol)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(selectedUnit == unit ? .white : .primary)
                        
                        Text(unit.shortName)
                            .font(.caption)
                            .foregroundColor(selectedUnit == unit ? .white.opacity(0.9) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedUnit == unit ? Color.blue : Color(.tertiarySystemBackground))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(unit.displayName)
                .accessibilityAddTraits(selectedUnit == unit ? .isSelected : [])
            }
        }
    }
}

// MARK: - Compact Activity Selector

struct CompactActivitySelector: View {
    @Binding var selectedInterests: Set<ActivityInterest>
    
    // Featured activities for onboarding
    private let featuredActivities: [ActivityInterest] = [
        .gardening, .exercise, .maintenance, .outdoorDining, .walking, .cycling
    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(featuredActivities, id: \.self) { interest in
                CompactActivityButton(
                    interest: interest,
                    isSelected: selectedInterests.contains(interest)
                ) {
                    if selectedInterests.contains(interest) {
                        selectedInterests.remove(interest)
                    } else {
                        selectedInterests.insert(interest)
                    }
                }
            }
        }
    }
}

struct CompactActivityButton: View {
    let interest: ActivityInterest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: interest.icon)
                    .font(.callout)
                    .foregroundColor(isSelected ? .white : interest.color)
                
                Text(interest.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? interest.color : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(interest.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Compact Timing Selector

struct CompactTimingSelector: View {
    @Binding var selectedTiming: NotificationTiming
    
    // Featured timings for onboarding
    private let featuredTimings: [NotificationTiming] = [
        .immediate, .thirtyMinutes, .oneHour
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(featuredTimings, id: \.self) { timing in
                Button(action: {
                    selectedTiming = timing
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(selectedTiming == timing ? Color.blue : Color(.tertiarySystemBackground))
                                .frame(width: 20, height: 20)
                            
                            if selectedTiming == timing {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .accessibilityHidden(true)
                        
                        Text(timing.displayName)
                            .font(.callout)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: timing.icon)
                            .font(.caption)
                            .foregroundColor(selectedTiming == timing ? .blue : .secondary)
                    }
                    .frame(height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(timing.displayName)
                .accessibilityAddTraits(selectedTiming == timing ? .isSelected : [])
            }
        }
    }
}

// MARK: - Compact Quiet Hours Toggle

struct CompactQuietHoursToggle: View {
    @Binding var enabled: Bool
    @Binding var startTime: Date
    @Binding var endTime: Date
    
    var body: some View {
        VStack(spacing: 10) {
            // Toggle
            HStack {
                Text("Enable quiet hours")
                    .font(.callout)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .scaleEffect(0.9)
            }
            
            // Time range (only if enabled)
            if enabled {
                HStack(spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                    
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    
                    Text("to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: enabled)
    }
}

// MARK: - Custom Transitions

extension AnyTransition {
    static var weatherSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - Preview

#Preview {
    UserPreferencesOnboardingView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: [
            UserPreferences.self,
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self
        ], inMemory: true)
}

#Preview("Dark Mode") {
    UserPreferencesOnboardingView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: [
            UserPreferences.self,
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self
        ], inMemory: true)
        .preferredColorScheme(.dark)
}