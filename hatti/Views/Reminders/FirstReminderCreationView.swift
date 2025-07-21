//
//  FirstReminderCreationView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation

struct FirstReminderCreationView: View {
    @StateObject private var viewModel = FirstReminderCreationViewModel()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
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
                    // Progress indicator
                    progressIndicator
                        .padding(.top, geometry.safeAreaInsets.top + 10)
                    
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
        .accessibilityLabel("First reminder creation")
        .accessibilityHint("Step 4 of 5 in the onboarding process")
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < 4 ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == 3 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: index == 3)
                }
            }
            
            Text("Step 4 of 5")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress: Step 4 of 5")
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
                        Text("Choose Your First Reminder")
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
                        Text("Your First Reminder")
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
                        
                        Text("Create My First Reminder")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                showCelebration = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                coordinator.nextStep()
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

// MARK: - Creation Steps

enum CreationStep {
    case templates
    case builder
    case preview
}

// MARK: - Supporting Views

struct TemplateCard: View {
    let template: ReminderTemplate
    let isSelected: Bool
    let animationDelay: Double
    let onTap: () -> Void
    
    @State private var isVisible = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 16) {
                // Enhanced icon with selection animation
                ZStack {
                    // Selection ring
                    if isSelected {
                        Circle()
                            .stroke(template.color, lineWidth: 3)
                            .frame(width: 70, height: 70)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                    }
                    
                    Circle()
                        .fill(
                            isSelected ? 
                            template.color.opacity(0.2) : 
                            template.color.opacity(0.1)
                        )
                        .frame(width: 60, height: 60)
                        .shadow(
                            color: isSelected ? template.color.opacity(0.3) : .clear,
                            radius: isSelected ? 8 : 0,
                            x: 0,
                            y: isSelected ? 4 : 0
                        )
                        .animation(.easeInOut(duration: 0.3), value: isSelected)
                    
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(template.color)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                }
                .accessibilityHidden(true)
                
                // Content
                VStack(spacing: 8) {
                    Text(template.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    // Example trigger
                    HStack {
                        Image(systemName: "thermometer.medium")
                            .font(.caption)
                            .foregroundColor(template.color)
                        
                        Text(template.exampleTrigger)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(template.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(template.color.opacity(0.1))
                    )
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? template.color : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isVisible ? 1.0 : 0.8))
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.title). \(template.description). Example: \(template.exampleTrigger)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Selected template" : "Tap to select this template")
    }
}

struct BuilderSection<Content: View>: View {
    let icon: String
    let title: String
    let animationDelay: Double
    let content: Content
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(icon: String, title: String, animationDelay: Double, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
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
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
                
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

// MARK: - Reminder Templates

let reminderTemplates: [ReminderTemplate] = [
    ReminderTemplate(
        id: UUID(),
        title: "Daily Walk",
        description: "Get reminded to walk when the weather is perfect",
        icon: "figure.walk",
        color: .green,
        activity: .walking,
        condition: .temperatureRange,
        minTemperature: 65,
        maxTemperature: 75,
        exampleTrigger: "65-75°F"
    ),
    ReminderTemplate(
        id: UUID(),
        title: "Outdoor Exercise",
        description: "Perfect timing for your outdoor workout routine",
        icon: "figure.run",
        color: .blue,
        activity: .exercise,
        condition: .temperatureRange,
        minTemperature: 60,
        maxTemperature: 80,
        exampleTrigger: "60-80°F"
    ),
    ReminderTemplate(
        id: UUID(),
        title: "Gardening",
        description: "Ideal conditions for tending to your garden",
        icon: "leaf.fill",
        color: .green,
        activity: .gardening,
        condition: .temperatureRange,
        minTemperature: 55,
        maxTemperature: 85,
        exampleTrigger: "55-85°F, no rain"
    ),
    ReminderTemplate(
        id: UUID(),
        title: "Photography",
        description: "Beautiful lighting for outdoor photography",
        icon: "camera.fill",
        color: .purple,
        activity: .photography,
        condition: .partlyCloudy,
        minTemperature: 50,
        maxTemperature: 90,
        exampleTrigger: "Partly cloudy"
    ),
    ReminderTemplate(
        id: UUID(),
        title: "Picnic Planning",
        description: "Perfect weather for outdoor dining",
        icon: "basket.fill",
        color: .orange,
        activity: .picnic,
        condition: .sunny,
        minTemperature: 70,
        maxTemperature: 85,
        exampleTrigger: "Sunny, 70-85°F"
    ),
    ReminderTemplate(
        id: UUID(),
        title: "Custom Activity",
        description: "Create your own weather-based reminder",
        icon: "plus.circle.fill",
        color: .gray,
        activity: .custom,
        condition: .temperatureRange,
        minTemperature: 65,
        maxTemperature: 75,
        exampleTrigger: "Your choice"
    )
]

// MARK: - Weather Slide Transition (if not already defined)

extension AnyTransition {
    static var weatherSlideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - Preview

#Preview {
    FirstReminderCreationView()
        .environmentObject(OnboardingCoordinator())
}

#Preview("Dark Mode") {
    FirstReminderCreationView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    FirstReminderCreationView()
        .environmentObject(OnboardingCoordinator())
        .environment(\.sizeCategory, .accessibilityExtraLarge)
}