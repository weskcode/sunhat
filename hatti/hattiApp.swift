//
//  hattiApp.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

@main
struct hattiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self,
            UserPreferences.self,
            SavedLocation.self,
            LocationHistory.self,
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.com.hatti.app"),
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}