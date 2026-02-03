//
//  QuickCreateReminderView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation

/// Enhanced reminder creation view that matches the onboarding experience
/// Uses the same polished multi-step interface with templates and visual builders
struct QuickCreateReminderView: View {
    @StateObject private var viewModel = FirstReminderCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var currentStep: CreationStep = .templates
    @State private var showCelebration = false
    @State private var showStepAnimation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Spacer()

                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .accessibilityLabel("Close")
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                    }

                    // Progress indicator
                    progressIndicator
                        .padding(.top, 10)

                    // Main content
                    ZStack {
                        // Template selection
                        if currentStep == .templates {
                            templateSelectionView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }

                        // Visual builder
                        if currentStep == .builder {
                            visualBuilderView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }

                        // Preview and completion
                        if currentStep == .preview {
                            previewView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: currentStep)

                    Spacer()
                }

                // Celebration overlay
                if showCelebration {
                    CelebrationView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
        }
        .onAppear {
            viewModel.loadWeatherForecast()
            startStepAnimation()
        }
        .onChange(of: currentStep) { _, newStep in
            startStepAnimation()

            if newStep == .preview {
                viewModel.calculateLikelihood()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Create new reminder")
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(stepColor(for: index))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isCurrentStep(index) ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }

            Text(stepTitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress: \(stepTitle)")
    }

    private func stepColor(for index: Int) -> Color {
        switch currentStep {
        case .templates:
            return index == 0 ? .blue : .gray.opacity(0.3)
        case .builder:
            return index <= 1 ? .blue : .gray.opacity(0.3)
        case .preview:
            return .blue
        }
    }

    private func isCurrentStep(_ index: Int) -> Bool {
        switch currentStep {
        case .templates:
            return index == 0
        case .builder:
            return index == 1
        case .preview:
            return index == 2
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case .templates:
            return "Choose Template"
        case .builder:
            return "Customize"
        case .preview:
            return "Preview"
        }
    }

    // MARK: - Template Selection View

    private var templateSelectionView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    // Magic wand icon with sparkle animation
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(showStepAnimation ? 1.2 : 1.0)
                            .opacity(showStepAnimation ? 0.6 : 0.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: showStepAnimation)

                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .purple.opacity(0.4), radius: 20, x: 0, y: 8)

                        // Magic wand with rotation
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 35, weight: .medium))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(showStepAnimation ? 5 : -5))
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showStepAnimation)

                        // Floating sparkles
                        ForEach(0..<6, id: \.self) { index in
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .offset(
                                    x: cos(Double(index) * .pi / 3) * 50,
                                    y: sin(Double(index) * .pi / 3) * 50
                                )
                                .scaleEffect(showStepAnimation ? 1.0 : 0.3)
                                .opacity(showStepAnimation ? 1.0 : 0.0)
                                .animation(
                                    .easeInOut(duration: 1.0)
                                    .delay(0.5 + Double(index) * 0.1)
                                    .repeatForever(autoreverses: true),
                                    value: showStepAnimation
                                )
                        }
                    }
                    .scaleEffect(showStepAnimation ? 1.0 : 0.8)
                    .opacity(showStepAnimation ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showStepAnimation)
                    .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("Create a Weather Reminder")
                            .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 32, relativeTo: .title))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text("Pick a template to get started, or create your own")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(showStepAnimation ? 1.0 : 0.0)
                    .offset(y: showStepAnimation ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: showStepAnimation)
                }
                .padding(.top, 30)
                .padding(.horizontal, 20)

                // Templates
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(reminderTemplates.enumerated()), id: \.offset) { index, template in
                        TemplateCard(
                            template: template,
                            isSelected: viewModel.selectedTemplate?.id == template.id,
                            animationDelay: 0.8 + Double(index) * 0.1
                        ) {
                            selectTemplate(template)
                        }
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)
                .opacity(showStepAnimation ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: showStepAnimation)

                // Continue button with enhanced animation
                if viewModel.selectedTemplate != nil {
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentStep = .builder
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title3)
                                .foregroundColor(.white)

                            Text("Customize This Reminder")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Image(systemName: "arrow.right")
                                .font(.title3)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)
                        .overlay(
                            // Shimmer effect
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(EnhancedButtonStyle())
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }

                Spacer(minLength: 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Visual Builder View

    private var visualBuilderView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentStep = .templates
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Go back to templates")

                        Spacer()
                    }

                    VStack(spacing: 12) {
                        Text("Build Your Reminder")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .accessibilityAddTraits(.isHeader)

                        Text("Customize when and how you'll be reminded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .opacity(showStepAnimation ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: showStepAnimation)

                // Builder sections
                VStack(spacing: 24) {
                    // Activity section
                    BuilderSection(
                        icon: "figure.walk",
                        title: "Activity",
                        animationDelay: 0.4
                    ) {
                        ActivitySelector(
                            selectedActivity: $viewModel.customReminder.activity,
                            customActivity: $viewModel.customReminder.customActivityName
                        )
                    }

                    // Weather condition section
                    BuilderSection(
                        icon: "thermometer.medium",
                        title: "Weather Conditions",
                        animationDelay: 0.6
                    ) {
                        WeatherConditionBuilder(
                            condition: $viewModel.customReminder.condition,
                            minTemp: $viewModel.customReminder.minTemperature,
                            maxTemp: $viewModel.customReminder.maxTemperature
                        )
                    }

                    // Time preferences section
                    BuilderSection(
                        icon: "clock",
                        title: "Time Preferences",
                        animationDelay: 0.8
                    ) {
                        TimePreferencesBuilder(
                            timeRange: $viewModel.customReminder.preferredTimeRange,
                            quietHours: $viewModel.customReminder.respectQuietHours
                        )
                    }

                    // Live preview with real-time weather
                    if viewModel.isReminderValid {
                        VStack(spacing: 16) {
                            LivePreviewCard(reminder: viewModel.customReminder)

                            RealTimeWeatherCard(reminder: viewModel.customReminder)
                        }
                        .padding(.top, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.top, 30)
                .padding(.horizontal, 20)
                .opacity(showStepAnimation ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.4), value: showStepAnimation)

                // Continue button
                if viewModel.isReminderValid {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentStep = .preview
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Preview & Create")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Image(systemName: "arrow.right")
                                .font(.title3)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Preview View

    private var previewView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentStep = .builder
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Go back to builder")

                        Spacer()
                    }

                    VStack(spacing: 12) {
                        Text("Your Reminder")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .accessibilityAddTraits(.isHeader)

                        Text("Here's when it might trigger based on the forecast")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .opacity(showStepAnimation ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: showStepAnimation)

                // Enhanced reminder summary
                ReminderSummaryCard(
                    reminder: viewModel.customReminder,
                    triggerLikelihood: viewModel.triggerLikelihood
                )
                .padding(.top, 30)
                .padding(.horizontal, 20)

                // Enhanced forecast with timeline
                VStack(spacing: 20) {
                    if let likelihood = viewModel.triggerLikelihood {
                        ForecastLikelihoodView(
                            likelihood: likelihood,
                            forecast: viewModel.weatherForecast,
                            animationDelay: 0.6
                        )
                    }

                    if !viewModel.weatherForecast.isEmpty {
                        ForecastTimelineView(
                            forecast: viewModel.weatherForecast,
                            reminder: viewModel.customReminder
                        )
                        .opacity(showStepAnimation ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: showStepAnimation)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                // Create button
                Button(action: {
                    createReminder()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)

                        Text("Create Reminder")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 40)
                .padding(.horizontal, 20)
                .opacity(showStepAnimation ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: showStepAnimation)

                Spacer(minLength: 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helper Methods

    private func startStepAnimation() {
        guard !reduceMotion else {
            showStepAnimation = true
            return
        }

        showStepAnimation = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showStepAnimation = true
            }
        }
    }

    private func selectTemplate(_ template: ReminderTemplate) {
        viewModel.selectTemplate(template)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func createReminder() {
        // Haptic feedback for creation
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)

        // Save the reminder
        viewModel.createReminder()

        // Show celebration with enhanced animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showCelebration = true
        }

        // Complete after celebration with staggered animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                showCelebration = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }

    // MARK: - Computed Properties

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.purple.opacity(0.05),
                Color.black
            ] : [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.94, green: 0.96, blue: 1.0),
                Color(red: 0.97, green: 0.98, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    QuickCreateReminderView()
}
