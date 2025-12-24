//
//  MainTabView.swift
//  hatti
//
//  Created by Wesley Keetch on 12/23/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Use existing DashboardView
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            // All Reminders Tab
            NavigationStack {
                AllRemindersView()
            }
            .tabItem {
                Label("Reminders", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
            }
            .tag(1)

            // Weather Tab
            NavigationStack {
                WeatherView()
            }
            .tabItem {
                Label("Weather", systemImage: selectedTab == 2 ? "cloud.sun.fill" : "cloud.sun")
            }
            .tag(2)

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
            }
            .tag(3)
        }
        .tint(.blue)
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
