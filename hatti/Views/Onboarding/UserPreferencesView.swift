//
//  UserPreferencesView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct UserPreferencesView: View {
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
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            headerSection
                                .padding(.top, 30)
                            
                            // Preferences sections
                            preferencesContent
                                .padding(.top, 30)
                            
                            // Finish button
                            finishButton
                                .padding(.top, 40)
                                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 40))
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear {
            viewModel.loadPreferences(from: modelContext)
            startAnimation()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("User preferences setup")
        .accessibilityHint("Final step of onboarding - step 5 of 5")
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == 4 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: index == 4)
                }
            }
            
            Text("Step 5 of 5")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress: Final step - Step 5 of 5")
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 24) {
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
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 5)
                
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.8).delay(0.2), value: showContent)
            .accessibilityHidden(true)
            
            VStack(spacing: 12) {
                Text("Personalize Your Experience")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 32, relativeTo: .title))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Customize TempTrigger to work perfectly for your lifestyle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.8).delay(0.5), value: showContent)
        }
    }
    
    // MARK: - Preferences Content
    
    private var preferencesContent: some View {
        VStack(spacing: 24) {
            // Temperature unit selection
            PreferenceSection(
                icon: "thermometer.medium",
                title: "Temperature Unit",
                animationDelay: 0.8
            ) {
                TemperatureUnitSelector(
                    selectedUnit: $viewModel.preferences.temperatureUnit
                )
            }
            
            // Notification timing
            PreferenceSection(
                icon: "bell.badge",
                title: "Notification Timing",
                animationDelay: 1.0
            ) {
                NotificationTimingSelector(
                    selectedTiming: $viewModel.preferences.defaultNotificationTiming
                )
            }
            
            // Activity interests
            PreferenceSection(
                icon: "heart.fill",
                title: "Activity Interests",
                subtitle: "Select activities you'd like weather reminders for",
                animationDelay: 1.2
            ) {
                ActivityInterestSelector(
                    selectedInterests: $viewModel.selectedActivityInterests
                )
            }
            
            // Quiet hours
            PreferenceSection(
                icon: "moon.zzz",
                title: "Quiet Hours",
                subtitle: "Avoid notifications during sleep time",
                animationDelay: 1.4
            ) {
                QuietHoursConfiguration(
                    enabled: $viewModel.preferences.quietHoursEnabled,
                    startTime: $viewModel.preferences.quietHoursStart,
                    endTime: $viewModel.preferences.quietHoursEnd
                )
            }
        }
        .opacity(showContent ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.8).delay(0.8), value: showContent)
    }
    
    // MARK: - Finish Button
    
    private var finishButton: some View {
        Button(action: {
            finishSetup()
        }) {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                }
                
                Text(isSaving ? "Saving Preferences..." : "Finish Setup")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: isSaving ? 
                        [Color.gray, Color.gray.opacity(0.8)] :
                        [Color.green, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSaving)
        .opacity(showContent ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.8).delay(1.6), value: showContent)
        .accessibilityLabel("Finish setup")
        .accessibilityHint("Complete onboarding and save your preferences")
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
                
                // Complete onboarding
                coordinator.completeOnboarding()
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

// MARK: - Preference Section

struct PreferenceSection<Content: View>: View {
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
        VStack(spacing: 16) {
            // Section header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Section content
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 20)
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

// MARK: - Temperature Unit Selector

struct TemperatureUnitSelector: View {
    @Binding var selectedUnit: TemperatureUnit
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                Button(action: {
                    selectedUnit = unit
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .font(.title3)
                            .foregroundColor(selectedUnit == unit ? .white : .blue)
                        
                        Text(unit.shortName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedUnit == unit ? .white : .primary)
                        
                        Text(unit.symbol)
                            .font(.caption)
                            .foregroundColor(selectedUnit == unit ? .white.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
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

// MARK: - Notification Timing Selector

struct NotificationTimingSelector: View {
    @Binding var selectedTiming: NotificationTiming
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(NotificationTiming.allCases, id: \.self) { timing in
                Button(action: {
                    selectedTiming = timing
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(selectedTiming == timing ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 24, height: 24)
                            
                            if selectedTiming == timing {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timing.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(timing.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: timing.icon)
                            .font(.body)
                            .foregroundColor(selectedTiming == timing ? .blue : .gray)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("\(timing.displayName). \(timing.description)")
                .accessibilityAddTraits(selectedTiming == timing ? .isSelected : [])
            }
        }
    }
}

// MARK: - Activity Interest Selector

struct ActivityInterestSelector: View {
    @Binding var selectedInterests: Set<ActivityInterest>
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(ActivityInterest.allCases, id: \.self) { interest in
                ActivityInterestButton(
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

struct ActivityInterestButton: View {
    let interest: ActivityInterest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: interest.icon)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : interest.color)
                
                Text(interest.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? interest.color : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(interest.displayName)
        .accessibilityHint(interest.description)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Quiet Hours Configuration

struct QuietHoursConfiguration: View {
    @Binding var enabled: Bool
    @Binding var startTime: Date
    @Binding var endTime: Date
    
    var body: some View {
        VStack(spacing: 16) {
            // Enable/disable toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Quiet Hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Pause notifications during sleep time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $enabled)
                    .labelsHidden()
            }
            
            // Time pickers (only if enabled)
            if enabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("From")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                    
                    HStack {
                        Text("To")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UserPreferencesView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: [UserPreferences.self], inMemory: true)
}

#Preview("Dark Mode") {
    UserPreferencesView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: [UserPreferences.self], inMemory: true)
        .preferredColorScheme(.dark)
}