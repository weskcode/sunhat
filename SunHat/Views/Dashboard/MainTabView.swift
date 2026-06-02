//
//  MainTabView.swift
//  SunHat
//
//  Created by Wesley Keetch on 12/23/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    private enum AppTab: Hashable {
        case home
        case reminders
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == .home ? "house.fill" : "house")
                }
                .tag(AppTab.home)

            NavigationStack {
                AllRemindersView()
            }
            .tabItem {
                Label("Reminders", systemImage: selectedTab == .reminders ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
            }
            .tag(AppTab.reminders)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == .settings ? "gearshape.fill" : "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            UserPreferences.self,
            LocationData.self
        ], inMemory: true)
}
