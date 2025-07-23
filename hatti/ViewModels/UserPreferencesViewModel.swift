//
//  UserPreferencesViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CloudKit
import Combine
import os

@MainActor
final class UserPreferencesViewModel: ObservableObject {
    @Published var preferences = UserPreferences()
    @Published var selectedActivityInterests: Set<ActivityInterest> = []
    @Published var isSaving = false
    @Published var saveError: String?
    
    private let logger = Logger(subsystem: "com.hatti.app", category: "UserPreferencesViewModel")
    private let cloudKitManager = UserPreferencesCloudKitManager()
    
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
            
            // Sync to CloudKit
            try await syncToCloudKit()
            
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
    
    private func syncToCloudKit() async throws {
        try await cloudKitManager.savePreferences(preferences)
        logger.info("Synced preferences to CloudKit")
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

// MARK: - CloudKit Manager

@MainActor
final class UserPreferencesCloudKitManager: ObservableObject {
    private let container: CKContainer
    private let database: CKDatabase
    private let logger = Logger(subsystem: "com.hatti.app", category: "UserPreferencesCloudKitManager")
    
    init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }
    
    func savePreferences(_ preferences: UserPreferences) async throws {
        let record = preferences.cloudKitRecord
        
        do {
            let savedRecord = try await database.save(record)
            preferences.cloudKitRecordID = savedRecord.recordID.recordName
            preferences.lastSyncedAt = Date()
            logger.info("Successfully saved preferences to CloudKit")
        } catch {
            logger.error("Failed to save preferences to CloudKit: \(error.localizedDescription)")
            throw CloudKitError.saveFailed(error)
        }
    }
    
    func fetchPreferences() async throws -> UserPreferences? {
        let query = CKQuery(recordType: "UserPreferences", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        do {
            let (matchResults, _) = try await database.records(matching: query)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    let preferences = UserPreferences.from(cloudKitRecord: record)
                    logger.info("Successfully fetched preferences from CloudKit")
                    return preferences
                case .failure(let error):
                    logger.error("Failed to fetch preference record: \(error.localizedDescription)")
                }
            }
            
            return nil
        } catch {
            logger.error("Failed to fetch preferences from CloudKit: \(error.localizedDescription)")
            throw CloudKitError.fetchFailed(error)
        }
    }
    
    func deletePreferences(_ preferences: UserPreferences) async throws {
        guard let recordID = preferences.cloudKitRecordID else {
            logger.warning("No CloudKit record ID found for preferences")
            return
        }
        
        let recordIDToDelete = CKRecord.ID(recordName: recordID)
        
        do {
            _ = try await database.deleteRecord(withID: recordIDToDelete)
            logger.info("Successfully deleted preferences from CloudKit")
        } catch {
            logger.error("Failed to delete preferences from CloudKit: \(error.localizedDescription)")
            throw CloudKitError.deleteFailed(error)
        }
    }
    
    func checkCloudKitAvailability() async -> Bool {
        do {
            let accountStatus = try await container.accountStatus()
            return accountStatus == .available
        } catch {
            logger.error("Failed to check CloudKit availability: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case accountUnavailable
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save to CloudKit: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch from CloudKit: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete from CloudKit: \(error.localizedDescription)"
        case .accountUnavailable:
            return "CloudKit account is not available"
        case .networkUnavailable:
            return "Network connection is not available"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .saveFailed:
            return "The preferences could not be saved to your iCloud account"
        case .fetchFailed:
            return "Your preferences could not be retrieved from iCloud"
        case .deleteFailed:
            return "The preferences could not be deleted from iCloud"
        case .accountUnavailable:
            return "You are not signed in to iCloud or CloudKit is disabled"
        case .networkUnavailable:
            return "A network connection is required to sync with iCloud"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .fetchFailed, .deleteFailed:
            return "Check your internet connection and try again"
        case .accountUnavailable:
            return "Sign in to iCloud in Settings and enable CloudKit for this app"
        case .networkUnavailable:
            return "Connect to the internet and try again"
        }
    }
}

// MARK: - Preferences Sync Service

@MainActor
final class PreferencesSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let cloudKitManager = UserPreferencesCloudKitManager()
    private let logger = Logger(subsystem: "com.hatti.app", category: "PreferencesSyncService")
    
    func syncPreferences(modelContext: ModelContext) async {
        isSyncing = true
        syncError = nil
        
        do {
            // Check CloudKit availability
            let isAvailable = await cloudKitManager.checkCloudKitAvailability()
            guard isAvailable else {
                throw CloudKitError.accountUnavailable
            }
            
            // Fetch local preferences
            let fetchRequest = FetchDescriptor<UserPreferences>()
            let localPreferences = try modelContext.fetch(fetchRequest)
            
            if let local = localPreferences.first {
                // Sync local to CloudKit
                try await cloudKitManager.savePreferences(local)
                lastSyncDate = Date()
                logger.info("Successfully synced preferences to CloudKit")
            } else {
                // Try to fetch from CloudKit
                if let cloudPreferences = try await cloudKitManager.fetchPreferences() {
                    modelContext.insert(cloudPreferences)
                    try modelContext.save()
                    lastSyncDate = Date()
                    logger.info("Successfully synced preferences from CloudKit")
                }
            }
            
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    func forceSyncToCloud(preferences: UserPreferences) async {
        isSyncing = true
        syncError = nil
        
        do {
            try await cloudKitManager.savePreferences(preferences)
            lastSyncDate = Date()
            logger.info("Force sync to CloudKit completed")
        } catch {
            logger.error("Force sync failed: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }
        
        isSyncing = false
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
