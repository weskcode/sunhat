//
//  MainTabView.swift
//  SunHat
//
//  Created by Wesley Keetch on 12/23/25.
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showingCreate = false
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

    private enum AppTab: Hashable {
        case home
        case weather
        case reminders
        case settings
        case add
    }

    // Intercept selection of the `.add` "tab" without ever changing the real
    // selection, so the trailing glass button acts as a button (opens the create
    // sheet) and the current tab stays put. Using a custom binding avoids the
    // re-entrancy of reverting the selection inside `.onChange`.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .add {
                    showingCreate = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                DashboardView()
            }

            Tab("Weather", systemImage: "cloud.sun", value: AppTab.weather) {
                WeatherView()
            }

            Tab("Reminders", systemImage: "list.bullet.rectangle", value: AppTab.reminders) {
                AllRemindersView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }

            // `role: .search` renders as a detached circular glass button on the
            // trailing side of the tab bar (the slot Apple Music uses for search).
            // We repurpose it as "New Task": selecting it opens the create sheet and
            // reverts the selection, so it behaves like a button rather than a tab.
            Tab("New Task", systemImage: "plus", value: AppTab.add, role: .search) {
                Color.clear
            }
        }
        .tint(Color.accentColor)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingCreate) {
            StreamlinedReminderCreationView(onReminderCreated: {
                if !onboardingCoordinator.hasCreatedFirstReminder {
                    onboardingCoordinator.markFirstReminderCreated()
                }
            })
        }
        .task {
            consumePendingIntentDestination()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
            consumePendingIntentDestination()
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            routeSearchActivity(userActivity)
        }
    }

    private func consumePendingIntentDestination() {
        guard let destination = SunHatIntentHandoff.consumePendingDestination() else {
            return
        }

        switch destination {
        case .home:
            selectedTab = .home
        case .reminders, .nextReady:
            selectedTab = .reminders
        case .createReminder:
            showingCreate = true
        case .settings:
            selectedTab = .settings
        }
    }

    private func routeSearchActivity(_ userActivity: NSUserActivity) {
        guard
            let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let destination = SunHatSearchIndexer.destination(for: identifier)
        else {
            return
        }

        switch destination {
        case .reminders:
            selectedTab = .reminders
        case .settings:
            selectedTab = .settings
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: [
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            UserPreferences.self,
            LocationData.self
        ], inMemory: true)
}
