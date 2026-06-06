//
//  SunHatApp.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

@main
struct SunHatApp: App {
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
        ])
        // CloudKit sync is disabled for now - can be re-enabled in the future
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.org.wesley.sunhat"),
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let container = sharedModelContainer
        BackgroundWeatherManager.shared.configure(modelContainer: container)
        Task {
            // Configure the weather service before any background refresh can run,
            // so BackgroundWeatherManager's refresh path never hits an unconfigured actor.
            await WeatherService.shared.configure(modelContainer: container)
            await TriggerEngineManager.shared.configure(modelContainer: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
