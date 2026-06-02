//
//  WelcomeView.swift
//  SunHat
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
    @State private var showUseCases = false
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
                        
                        // Use Cases Section
                        useCaseSection
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
        VStack(spacing: 24) {
            // Weather icon with animated glow
            weatherIconWithGlow
                .scaleEffect(showHeroText ? 1.0 : 0.8)
                .opacity(showHeroText ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.2), value: showHeroText)
            
            // Main headline
            VStack(spacing: 16) {
                Text("Smart reminders")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        differentiateWithoutColor
                            ? AnyShapeStyle(Color.primary)
                            : AnyShapeStyle(primaryTextGradient)
                    )
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("triggered by weather,")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        differentiateWithoutColor
                            ? AnyShapeStyle(Color.primary)
                            : AnyShapeStyle(primaryTextGradient)
                    )
                    .multilineTextAlignment(.center)
                
                Text("not time")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        differentiateWithoutColor
                            ? AnyShapeStyle(Color.blue)
                            : AnyShapeStyle(accentGradient)
                    )
                    .multilineTextAlignment(.center)
            }
            .opacity(showHeroText ? 1.0 : 0.0)
            .offset(y: showHeroText ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(0.5), value: showHeroText)
            
            // Subtitle
            Text("Perfect conditions for your outdoor activities, gardening, and daily tasks")
                .font(AppFontStyle.title3.font)
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
    }
    
    // MARK: - Use Case Section

    private let useCaseTags: [(String, String, Color)] = [
        ("Gardening", "leaf.fill", .green),
        ("Running", "figure.run", .blue),
        ("Pool Day", "figure.pool.swim", .cyan),
        ("Dog Walking", "dog.fill", .orange),
        ("Photography", "camera.fill", .purple),
        ("Picnic", "basket.fill", .pink)
    ]

    private var useCaseSection: some View {
        VStack(spacing: 24) {
            Text("Works for any outdoor activity")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            // Use case tags
            FlowLayout(spacing: 10) {
                ForEach(useCaseTags, id: \.0) { tag in
                    HStack(spacing: 6) {
                        Image(systemName: tag.1)
                            .font(.caption)
                            .foregroundColor(tag.2)

                        Text(tag.0)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(tag.2.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            .overlay(
                                Capsule()
                                    .stroke(tag.2.opacity(0.2), lineWidth: 1)
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
        .animation(.easeOut(duration: 0.6).delay(0.2), value: showUseCases)
    }

    // MARK: - Example Notification Card

    private var exampleNotificationCard: some View {
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
                    .frame(width: 36, height: 36)

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("SunHat")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("now")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("Perfect gardening weather!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("It's 72°F and sunny — ideal for your outdoor plans.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
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
        showHeroText = true
        showUseCases = true
        showActionButtons = true
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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
