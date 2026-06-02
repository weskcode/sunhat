//
//  UserPreferencesViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import os

@MainActor
@Observable
final class UserPreferencesViewModel {
    var preferences = UserPreferences()
    var selectedActivityInterests: Set<ActivityInterest> = []
    var isSaving = false
    var saveError: String?
    
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "UserPreferencesViewModel")

    init() {
        // Initialize with system defaults
        preferences.temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        
        // Set up activity interests binding
        syncActivityInterests()
    }
    
    func loadPreferences(from modelContext: ModelContext) {
        do {
            let fetchRequest = FetchDescriptor<UserPreferences>()
            let existingPreferences = try modelContext.fetch(fetchRequest)
            
            if let existing = existingPreferences.first {
                // Load existing preferences
                preferences = existing
                logger.info("Loaded existing user preferences")
            } else {
                // Create new preferences with defaults
                preferences = UserPreferences()
                logger.info("Created new user preferences with defaults")
            }
            
            syncActivityInterests()
            
        } catch {
            logger.error("Failed to load user preferences: \(error.localizedDescription)")
            saveError = "Failed to load preferences: \(error.localizedDescription)"
        }
    }
    
    func savePreferences(to modelContext: ModelContext) async {
        isSaving = true
        saveError = nil

        do {
            // Update activity interests
            preferences.selectedActivityInterests = selectedActivityInterests.map { $0.rawValue }
            preferences.updateTimestamp()

            // Save to SwiftData
            try await saveToSwiftData(modelContext: modelContext)

            logger.info("Successfully saved user preferences")

        } catch {
            logger.error("Failed to save user preferences: \(error.localizedDescription)")
            saveError = "Failed to save preferences: \(error.localizedDescription)"
        }

        isSaving = false
    }
    
    private func saveToSwiftData(modelContext: ModelContext) async throws {
        // Check if preferences already exist
        let fetchRequest = FetchDescriptor<UserPreferences>()
        let existingPreferences = try modelContext.fetch(fetchRequest)
        
        if let existing = existingPreferences.first {
            // Update existing preferences
            existing.temperatureUnit = preferences.temperatureUnit
            existing.defaultNotificationTiming = preferences.defaultNotificationTiming
            existing.selectedActivityInterests = preferences.selectedActivityInterests
            existing.quietHoursEnabled = preferences.quietHoursEnabled
            existing.quietHoursStart = preferences.quietHoursStart
            existing.quietHoursEnd = preferences.quietHoursEnd
            existing.allowWeekendNotifications = preferences.allowWeekendNotifications
            existing.maximumDailyNotifications = preferences.maximumDailyNotifications
            existing.updateTimestamp()
            
            preferences = existing
        } else {
            // Insert new preferences
            modelContext.insert(preferences)
        }
        
        try modelContext.save()
        logger.info("Saved preferences to SwiftData")
    }
    
    private func syncActivityInterests() {
        selectedActivityInterests = Set(preferences.selectedActivityInterests.compactMap { ActivityInterest(rawValue: $0) })
    }
    
    // MARK: - Convenience Methods
    
    func toggleActivityInterest(_ interest: ActivityInterest) {
        if selectedActivityInterests.contains(interest) {
            selectedActivityInterests.remove(interest)
        } else {
            selectedActivityInterests.insert(interest)
        }
    }
    
    func resetToDefaults() {
        preferences = UserPreferences()
        selectedActivityInterests = []
        syncActivityInterests()
    }
    
    func exportPreferences() -> [String: Any] {
        return [
            "temperatureUnit": preferences.temperatureUnit.rawValue,
            "defaultNotificationTiming": preferences.defaultNotificationTiming.rawValue,
            "selectedActivityInterests": preferences.selectedActivityInterests,
            "quietHoursEnabled": preferences.quietHoursEnabled,
            "quietHoursStart": ISO8601DateFormatter().string(from: preferences.quietHoursStart),
            "quietHoursEnd": ISO8601DateFormatter().string(from: preferences.quietHoursEnd),
            "allowWeekendNotifications": preferences.allowWeekendNotifications,
            "maximumDailyNotifications": preferences.maximumDailyNotifications,
            "createdAt": ISO8601DateFormatter().string(from: preferences.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: preferences.updatedAt)
        ]
    }
}

// MARK: - UserDefaults Extension for Quick Access

extension UserDefaults {
    private enum Keys {
        static let temperatureUnit = "temperatureUnit"
        static let defaultNotificationTiming = "defaultNotificationTiming"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let lastPreferencesSync = "lastPreferencesSync"
    }
    
    var temperatureUnit: TemperatureUnit {
        get {
            guard let rawValue = string(forKey: Keys.temperatureUnit),
                  let unit = TemperatureUnit(rawValue: rawValue) else {
                return Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
            }
            return unit
        }
        set {
            set(newValue.rawValue, forKey: Keys.temperatureUnit)
        }
    }
    
    var defaultNotificationTiming: NotificationTiming {
        get {
            guard let rawValue = string(forKey: Keys.defaultNotificationTiming),
                  let timing = NotificationTiming(rawValue: rawValue) else {
                return .immediate
            }
            return timing
        }
        set {
            set(newValue.rawValue, forKey: Keys.defaultNotificationTiming)
        }
    }
    
    var quietHoursEnabled: Bool {
        get {
            return bool(forKey: Keys.quietHoursEnabled)
        }
        set {
            set(newValue, forKey: Keys.quietHoursEnabled)
        }
    }
    
    var lastPreferencesSync: Date? {
        get {
            return object(forKey: Keys.lastPreferencesSync) as? Date
        }
        set {
            set(newValue, forKey: Keys.lastPreferencesSync)
        }
    }
}
