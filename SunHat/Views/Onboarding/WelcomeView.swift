//
//  WelcomeView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    // Animation states for staggered entrance
    @State private var showHeroText = false
    @State private var showUseCases = false
    @State private var showActionButtons = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                            .padding(.top, geometry.safeAreaInsets.top + 8)
                        
                        useCaseSection
                            .padding(.top, 34)
                        
                        actionButtonsSection
                            .padding(.top, 34)
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
                showUseCases = true
                showActionButtons = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to SunHat")
        .accessibilityHint("Smart weather-based reminder app onboarding screen")
        .dynamicTypeSize(.large ... .accessibility5)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 20) {
            weatherIconWithGlow
                .scaleEffect(showHeroText ? 1.0 : 0.8)
                .opacity(showHeroText ? 1.0 : 0.0)
                .animation(entranceAnimation(delay: 0.1), value: showHeroText)
            
            VStack(spacing: 10) {
                Text("Weather-aware")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .bold()
                    .foregroundStyle(
                        differentiateWithoutColor
                            ? AnyShapeStyle(Color.primary)
                            : AnyShapeStyle(primaryTextGradient)
                    )
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("reminders")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .bold()
                    .foregroundStyle(
                        differentiateWithoutColor
                            ? AnyShapeStyle(Color.primary)
                            : AnyShapeStyle(primaryTextGradient)
                    )
                    .multilineTextAlignment(.center)
                
                Text("ready with the forecast")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .bold()
                    .foregroundStyle(
                        differentiateWithoutColor
                            ? AnyShapeStyle(Color.blue)
                            : AnyShapeStyle(accentGradient)
                    )
                    .multilineTextAlignment(.center)
            }
            .opacity(showHeroText ? 1.0 : 0.0)
            .offset(y: showHeroText ? 0 : 30)
            .animation(entranceAnimation(delay: 0.2), value: showHeroText)
            
            Text("SunHat watches weather, location, and timing so reminders feel contextual instead of scheduled.")
                .font(AppFontStyle.callout.font)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .opacity(showHeroText ? 1.0 : 0.0)
                .offset(y: showHeroText ? 0 : 20)
                .animation(entranceAnimation(delay: 0.3), value: showHeroText)
                .accessibilityLabel("SunHat watches weather, location, and timing so reminders feel contextual instead of scheduled.")
        }
    }
    
    // MARK: - Weather Icon with Glow
    
    private var weatherIconWithGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.18),
                            Color.cyan.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 132, height: 132)
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                .opacity(isAnimating ? 0.62 : 0.78)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            ZStack {
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
                    .animation(
                        reduceMotion ? nil : .linear(duration: 20.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
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
            .frame(width: 104, height: 104)
            .sunHatSurface(tint: .orange, cornerRadius: 52, prominence: 0.56)
        }
        .onAppear {
            if !reduceMotion {
                isAnimating = true
            }
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Use Case Section

    private let useCaseTags: [(String, String, Color)] = [
        ("Garden", "leaf.fill", .green),
        ("Trail Run", "figure.run", .blue),
        ("Pool Day", "figure.pool.swim", .cyan),
        ("Photo Walk", "camera.fill", .purple),
        ("Picnic", "basket.fill", .pink)
    ]

    private var useCaseSection: some View {
        VStack(spacing: 18) {
            Text("Built for conditional plans")
                .font(.headline)
                .bold()
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 10) {
                ForEach(useCaseTags, id: \.0) { tag in
                    HStack(spacing: 6) {
                        Image(systemName: tag.1)
                            .font(.caption)
                            .foregroundStyle(tag.2)

                        Text(tag.0)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(tag.2.opacity(0.26), lineWidth: 1)
                            )
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(tag.0)
                }
            }

            // Single example notification
            exampleNotificationCard
        }
        .opacity(showUseCases ? 1.0 : 0.0)
        .offset(y: showUseCases ? 0 : 20)
        .animation(entranceAnimation(delay: 0.15), value: showUseCases)
    }

    // MARK: - Example Notification Card

    private var exampleNotificationCard: some View {
        HStack(spacing: 12) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("SunHat")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("now")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.secondary)
                }

                Text("Perfect gardening weather!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("It's 72°F and sunny, ideal for your outdoor plans.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .sunHatSurface(tint: .orange, cornerRadius: 18, prominence: 0.72)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: Perfect gardening weather! It's 72°F and sunny, ideal for your outdoor plans.")
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
                        .font(AppFontStyle.title3.font)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(AppFontStyle.title3.font)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.45, blue: 0.68),
                            Color(red: 0.10, green: 0.62, blue: 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
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
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Skip for now")
                .accessibilityHint("Skip onboarding and go directly to the app")
            }
        }
        .opacity(showActionButtons ? 1.0 : 0.0)
                .offset(y: showActionButtons ? 0 : 30)
        .animation(entranceAnimation(delay: 0.3), value: showActionButtons)
    }
    
    // MARK: - Helper Methods
    
    private func startOnboardingAnimation() {
        showHeroText = true
        showUseCases = true
        showActionButtons = true
    }

    private func entranceAnimation(delay: TimeInterval) -> Animation? {
        SunHatMotion.reveal(reduceMotion: reduceMotion, delay: delay)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: some View {
        SunHatAtmosphereBackground(condition: .partlyCloudy, intensity: 0.62)
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
            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
