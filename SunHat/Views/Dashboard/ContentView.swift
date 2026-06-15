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
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if onboardingCoordinator.hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(onboardingCoordinator)
                } else {
                    OnboardingContainerView()
                        .environmentObject(onboardingCoordinator)
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            } catch is CancellationError {
                // View disappeared before the splash finished.
            } catch {
                showSplash = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WeatherReminder.self, inMemory: true)
}
