//
//  WelcomeView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    @State private var isPresented = false

    var body: some View {
        ZStack {
            welcomeBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 44)

                    WelcomeHero()

                    Spacer(minLength: 36)

                    ExampleReminderCard()

                    Spacer(minLength: 32)

                    actionSection
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .opacity(isPresented ? 1 : 0)
        .offset(y: isPresented || reduceMotion ? 0 : 12)
        .animation(SunHatMotion.reveal(reduceMotion: reduceMotion), value: isPresented)
        .onAppear {
            isPresented = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to SunHat")
        .dynamicTypeSize(...(.accessibility5))
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            Button {
                coordinator.nextStep()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.accentColor)
            .accessibilityHint("Begin setting up weather-based reminders")

            if coordinator.isReturningUser {
                Button("Skip for now") {
                    coordinator.skipOnboarding()
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Go directly to the app")
            }
        }
    }

    private var welcomeBackground: some View {
        Color(.systemBackground)
    }
}

private struct WelcomeHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 24) {
            weatherMark

            VStack(spacing: 12) {
                Text("Weather-aware reminders")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Ready when the forecast is right.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.center)

                Text("SunHat checks the weather, your location, and the time, then reminds you when your plans make sense.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 390)
            }

            Label("Garden  ·  Trail run  ·  Pool day", systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var weatherMark: some View {
        Image(systemName: "cloud.sun.fill")
            .font(.system(size: 48, weight: .medium))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.orange)
            .frame(width: 96, height: 96)
            .background(Color.accentColor, in: .rect(cornerRadius: 24))
            .shadow(color: Color.accentColor.opacity(0.18), radius: 16, y: 8)
            .accessibilityHidden(true)
    }
}

private struct ExampleReminderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("A timely heads-up", systemImage: "bell.badge.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text("Perfect gardening weather")
                .font(.headline)

            Text("It’s 72°F and sunny. A good time to get outside.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example reminder: Perfect gardening weather. It’s 72 degrees and sunny. A good time to get outside.")
    }
}

#Preview {
    WelcomeView()
        .environmentObject(OnboardingCoordinator())
}
