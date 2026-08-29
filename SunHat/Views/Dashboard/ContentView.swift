//
//  ContentView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()

    var body: some View {
        // Onboarding completion is read synchronously at OnboardingCoordinator's
        // init (UserDefaults), so there is no real initialization to cover here.
        // No splash gate: content renders immediately for every launch.
        if onboardingCoordinator.hasCompletedOnboarding {
            MainTabView()
                .environmentObject(onboardingCoordinator)
        } else {
            OnboardingContainerView()
                .environmentObject(onboardingCoordinator)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WeatherReminder.self, inMemory: true)
}
