//
//  WelcomeView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showingOnboarding = false
    @State private var animationStep = 0
    @State private var isAnimating = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    // Animation states for staggered entrance
    @State private var showHeroText = false
    @State private var showComparisonCards = false
    @State private var showActionButtons = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section
                        heroSection
                            .padding(.top, geometry.safeAreaInsets.top + 40)
                        
                        // Comparison Cards Section
                        comparisonSection
                            .padding(.top, 60)
                        
                        // Action Buttons Section
                        actionButtonsSection
                            .padding(.top, 60)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 40))
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            if !reduceMotion {
                startOnboardingAnimation()
            } else {
                // Show all content immediately for reduced motion
                showHeroText = true
                showComparisonCards = true
                showActionButtons = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to TempTrigger")
        .accessibilityHint("Smart weather-based reminder app onboarding screen")
        .dynamicTypeSize(.large ... .accessibility5)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            // Weather icon with animated glow
            weatherIconWithGlow
                .scaleEffect(showHeroText ? 1.0 : 0.8)
                .opacity(showHeroText ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.2), value: showHeroText)
            
            // Main headline
            VStack(spacing: 16) {
                Text("Smart reminders")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 36, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundStyle(differentiateWithoutColor ? Color.primary : primaryTextGradient)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("triggered by weather,")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 36, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundStyle(differentiateWithoutColor ? Color.primary : primaryTextGradient)
                    .multilineTextAlignment(.center)
                
                Text("not time")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 36, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundStyle(differentiateWithoutColor ? Color.blue : accentGradient)
                    .multilineTextAlignment(.center)
            }
            .opacity(showHeroText ? 1.0 : 0.0)
            .offset(y: showHeroText ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(0.5), value: showHeroText)
            
            // Subtitle
            Text("Perfect conditions for your outdoor activities, gardening, and daily tasks")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .opacity(showHeroText ? 1.0 : 0.0)
                .offset(y: showHeroText ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: showHeroText)
                .accessibilityLabel("Perfect conditions for your outdoor activities, gardening, and daily tasks")
        }
    }
    
    // MARK: - Weather Icon with Glow
    
    private var weatherIconWithGlow: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.3),
                            Color.orange.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.6 : 0.8)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Main weather icon
            ZStack {
                // Sun
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 20.0).repeatForever(autoreverses: false), value: isAnimating)
                
                // Cloud overlay for partly cloudy effect
                Image(systemName: "cloud.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.gray.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(x: 15, y: 10)
                    .opacity(0.9)
            }
            .shadow(color: .orange.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            if !reduceMotion {
                isAnimating = true
            }
        }
        .accessibilityLabel("Weather icon")
        .accessibilityHidden(true) // Decorative element
        .accessibilityRespondsToInversion(false)
    }
    
    // MARK: - Comparison Section
    
    private var comparisonSection: some View {
        VStack(spacing: 32) {
            // Section header
            VStack(spacing: 12) {
                Text("See the difference")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Weather-smart reminders vs traditional time-based alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showComparisonCards ? 1.0 : 0.0)
            .offset(y: showComparisonCards ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showComparisonCards)
            
            // Comparison cards
            VStack(spacing: 20) {
                ForEach(Array(comparisonExamples.enumerated()), id: \.offset) { index, example in
                    ComparisonCard(
                        example: example,
                        index: index
                    )
                    .opacity(showComparisonCards ? 1.0 : 0.0)
                    .offset(x: showComparisonCards ? 0 : -50)
                    .animation(.easeOut(duration: 0.6).delay(0.4 + Double(index) * 0.15), value: showComparisonCards)
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Get Started button
            Button(action: {
                withAnimation(.easeInOut(duration: reduceMotion ? 0.1 : 0.3)) {
                    coordinator.nextStep()
                }
            }) {
                HStack(spacing: 12) {
                    Text("Get Started")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Get Started")
            .accessibilityHint("Begin setting up your weather-based reminders")
            
            // Skip button (only show for returning users)
            if coordinator.isReturningUser {
                Button(action: {
                    coordinator.skipOnboarding()
                }) {
                Text("Skip for now")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Skip for now")
                .accessibilityHint("Skip onboarding and go directly to the app")
            }
        }
        .opacity(showActionButtons ? 1.0 : 0.0)
        .offset(y: showActionButtons ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(0.6), value: showActionButtons)
    }
    
    // MARK: - Helper Methods
    
    private func startOnboardingAnimation() {
        withAnimation {
            showHeroText = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showComparisonCards = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showActionButtons = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.1),
                Color.black
            ] : [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.90, green: 0.95, blue: 1.0),
                Color(red: 0.95, green: 0.97, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var primaryTextGradient: LinearGradient {
        LinearGradient(
            colors: [Color.primary, Color.primary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue, Color.blue.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Comparison Examples Data

private let comparisonExamples: [ComparisonExample] = [
    ComparisonExample(
        title: "Gardening Reminder",
        weatherBased: WeatherBasedReminder(
            condition: "When it's above 60°F",
            description: "Perfect planting weather!",
            icon: "leaf.fill",
            color: .green
        ),
        timeBased: TimeBasedReminder(
            time: "Every Saturday 9 AM",
            description: "Check garden (even if it's 30°F)",
            icon: "clock.fill",
            color: .gray
        )
    ),
    ComparisonExample(
        title: "Outdoor Exercise",
        weatherBased: WeatherBasedReminder(
            condition: "When it's 65-80°F",
            description: "Ideal running conditions",
            icon: "figure.run",
            color: .blue
        ),
        timeBased: TimeBasedReminder(
            time: "Daily at 6 PM",
            description: "Go for a run (rain or shine)",
            icon: "clock.fill",
            color: .gray
        )
    ),
    ComparisonExample(
        title: "Pool Maintenance",
        weatherBased: WeatherBasedReminder(
            condition: "First day above 75°F",
            description: "Time to open the pool!",
            icon: "figure.pool.swim",
            color: .cyan
        ),
        timeBased: TimeBasedReminder(
            time: "April 15th",
            description: "Open pool (might still be cold)",
            icon: "calendar",
            color: .gray
        )
    )
]

// MARK: - Supporting Data Structures

struct ComparisonExample {
    let title: String
    let weatherBased: WeatherBasedReminder
    let timeBased: TimeBasedReminder
}

struct WeatherBasedReminder {
    let condition: String
    let description: String
    let icon: String
    let color: Color
}

struct TimeBasedReminder {
    let time: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - Preview

#Preview {
    WelcomeView()
}