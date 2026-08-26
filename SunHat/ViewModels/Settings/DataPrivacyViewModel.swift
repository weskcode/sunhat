//
//  DataPrivacyViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os.log

@MainActor
@Observable
final class DataPrivacyViewModel {
    static let privacyDeletedModelTypeNames = SunHatModelSchema.modelTypeNames
    static let privacyExportedModelTypeNames: Set<String> = [
        "WeatherReminder",
        "TriggerCondition",
        "LocationData",
        "WeatherData",
        "ForecastDay",
        "NotificationConfig",
        "ReminderHistory",
        "UserPreferences",
        "SavedLocation",
        "LocationHistory"
    ]
    
    // MARK: - Published Properties

    // Sync status (CloudKit disabled - prepared for future use)
    var syncEnabled: Bool = false
    var isSyncing: Bool = false
    var deleteConfirmationText: String = ""
    var isExporting: Bool = false
    var isDeleting: Bool = false
    
    // Data summary
    var dataSummary: DataSummary?
    
    // Status messages
    var statusMessage: String = ""
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var deleteConfirmationValid: Bool {
        deleteConfirmationText.uppercased() == "DELETE"
    }
    
    var syncStatusDescription: String {
        "Your data is stored locally on this device. iCloud sync will be available in a future update."
    }
    
    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private let settingsOpener: SettingsOpening
    private let locationPermissionManager: LocationPermissionManager
    private let notificationDataCleaner: any NotificationDataClearing
    private let runtimeDataCleaner: any PrivacyRuntimeDataClearing

    // MARK: - Initialization

    init(
        settingsOpener: SettingsOpening = ApplicationSettingsOpener(),
        locationPermissionManager: LocationPermissionManager = .shared,
        notificationDataCleaner: any NotificationDataClearing = SystemNotificationDataCleaner(),
        runtimeDataCleaner: any PrivacyRuntimeDataClearing = SystemPrivacyRuntimeDataCleaner()
    ) {
        self.settingsOpener = settingsOpener
        self.locationPermissionManager = locationPermissionManager
        self.notificationDataCleaner = notificationDataCleaner
        self.runtimeDataCleaner = runtimeDataCleaner
    }

    /// Must be called with the app's shared model context before any data
    /// operation — summary, export, and delete must all hit the same
    /// app-group store the rest of the app reads and writes.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    func loadDataSummary() async {
        guard let context = modelContext else {
            errorMessage = DataPrivacyError.noModelContext.errorDescription
            return
        }
        
        do {
            // Count reminders
            let reminderDescriptor = FetchDescriptor<WeatherReminder>()
            let reminders = try context.fetch(reminderDescriptor)
            
            // Count locations
            let locationDescriptor = FetchDescriptor<LocationData>()
            let locations = try context.fetch(locationDescriptor)
            
            // Count weather records
            let weatherDescriptor = FetchDescriptor<WeatherData>()
            let weatherRecords = try context.fetch(weatherDescriptor)
            
            // Calculate data size estimation
            let estimatedSize = estimateDataSize(
                reminders: reminders.count,
                locations: locations.count,
                weatherRecords: weatherRecords.count
            )
            
            dataSummary = DataSummary(
                reminderCount: reminders.count,
                locationCount: locations.count,
                weatherRecordCount: weatherRecords.count,
                totalDataSize: formatDataSize(estimatedSize)
            )
            
        } catch {
            errorMessage = "Failed to load data summary: \(error.localizedDescription)"
        }
    }
    
    func exportDataAsJSON() async {
        isExporting = true
        errorMessage = nil
        
        do {
            let exportData = try await generateExportData()
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            
            let fileName = "SunHat_Export_\(DateFormatter.exportFormat.string(from: Date())).json"
            
            await saveAndShareFile(data: jsonData, fileName: fileName, contentType: .json)
            
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
        }
        
        isExporting = false
    }
    
    func exportDataAsCSV() async {
        isExporting = true
        errorMessage = nil
        
        do {
            let csvData = try await generateCSVExport()
            let fileName = "SunHat_Export_\(DateFormatter.exportFormat.string(from: Date())).csv"
            
            await saveAndShareFile(data: csvData, fileName: fileName, contentType: .commaSeparatedText)
            
        } catch {
            errorMessage = "Failed to export CSV: \(error.localizedDescription)"
        }
        
        isExporting = false
    }
    
    func deleteAllUserData() async {
        guard deleteConfirmationValid else { return }

        isDeleting = true
        errorMessage = nil

        do {
            guard let context = modelContext else {
                throw DataPrivacyError.noModelContext
            }

            // Delete all data types
            try await deleteAllData(from: context)

            // Reset app to initial state
            try await resetAppState()

            statusMessage = "All data has been successfully deleted"

        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
        }

        isDeleting = false
        deleteConfirmationText = ""
    }
    
    // MARK: - Sync Methods (CloudKit disabled - prepared for future use)

    func enableSync() async {
        // CloudKit sync is currently disabled
        // This method is preserved for future CloudKit integration
        statusMessage = "iCloud sync will be available in a future update."
    }

    func disableSync() async {
        // CloudKit sync is currently disabled
        syncEnabled = false
        statusMessage = "Data is stored locally on this device."
    }

    func forceSyncNow() async {
        // CloudKit sync is currently disabled
        statusMessage = "Sync is currently unavailable. Data is stored locally."
    }
    
    func contactPrivacyOfficer() {
        let email = AppSupportLinks.privacyEmail
        let subject = "Privacy Inquiry - SunHat App"
        let body = """
        Hello,
        
        I am contacting you regarding my privacy rights under GDPR/CCPA.
        
        My request:
        
        
        Thank you,
        """
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            Task {
                let opened = await settingsOpener.open(url)
                if opened == false {
                    errorMessage = "Couldn't open Mail. Set up a mail account, or email \(email) directly."
                }
            }
        }
    }

    // MARK: - Private Methods

    private func generateExportData() async throws -> [String: Any] {
        guard let context = modelContext else {
            throw DataPrivacyError.noModelContext
        }
        
        var exportData: [String: Any] = [:]
        
        // Export metadata
        exportData["export_info"] = [
            "app": "SunHat",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "format_version": "1.0"
        ]
        
        // Export user preferences
        if let preferences = try await fetchUserPreferences() {
            exportData["user_preferences"] = [
                "temperature_unit": preferences.temperatureUnit.rawValue,
                "notification_timing": preferences.defaultNotificationTiming.rawValue,
                "quiet_hours_enabled": preferences.quietHoursEnabled,
                "quiet_hours_start": ISO8601DateFormatter().string(from: preferences.quietHoursStart),
                "quiet_hours_end": ISO8601DateFormatter().string(from: preferences.quietHoursEnd),
                "weekend_notifications": preferences.allowWeekendNotifications,
                "max_daily_notifications": preferences.maximumDailyNotifications,
                "notification_grouping": preferences.notificationGrouping.rawValue,
                "lock_screen_behavior": preferences.lockScreenBehavior.rawValue,
                "critical_alerts": preferences.criticalAlertsEnabled,
                "vibration_pattern": preferences.vibrationPattern.rawValue,
                "notification_sounds": preferences.notificationSounds,
                "activity_interests": preferences.selectedActivityInterests
            ]
        }
        
        // Export reminders
        let reminderDescriptor = FetchDescriptor<WeatherReminder>()
        let reminders = try context.fetch(reminderDescriptor)
        
        exportData["reminders"] = reminders.map { reminder in
            return [
                "id": reminder.id.uuidString,
                "title": reminder.title,
                "description": reminder.reminderDescription,
                "category": reminder.category.rawValue,
                "is_active": reminder.isCurrentlyActive,
                "created_at": ISO8601DateFormatter().string(from: reminder.createdDate),
                "updated_at": ISO8601DateFormatter().string(from: reminder.lastModified),
                "trigger_condition": reminder.triggerCondition?.exportData ?? [:],
                "location": reminder.location?.exportData ?? [:],
                "notification_config": reminder.notificationConfig?.exportData ?? [:]
            ]
        }

        let triggerDescriptor = FetchDescriptor<TriggerCondition>()
        let triggerConditions = try context.fetch(triggerDescriptor)
        exportData["trigger_conditions"] = triggerConditions.map { condition in
            condition.exportData
        }

        let notificationConfigDescriptor = FetchDescriptor<NotificationConfig>()
        let notificationConfigs = try context.fetch(notificationConfigDescriptor)
        exportData["notification_configs"] = notificationConfigs.map { config in
            config.exportData
        }

        let reminderHistoryDescriptor = FetchDescriptor<ReminderHistory>()
        let reminderHistories = try context.fetch(reminderHistoryDescriptor)
        exportData["reminder_history"] = reminderHistories.map { history in
            history.exportData
        }
        
        // Export locations
        let locationDescriptor = FetchDescriptor<LocationData>()
        let locations = try context.fetch(locationDescriptor)
        
        exportData["locations"] = locations.map { location in
            return location.exportData
        }

        let savedLocationDescriptor = FetchDescriptor<SavedLocation>()
        let savedLocations = try context.fetch(savedLocationDescriptor)
        exportData["saved_locations"] = savedLocations.map { location in
            location.exportData
        }

        let locationHistoryDescriptor = FetchDescriptor<LocationHistory>()
        let locationHistories = try context.fetch(locationHistoryDescriptor)
        exportData["location_history"] = locationHistories.map { history in
            history.exportData
        }
        
        // Export weather data (recent only, last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let weatherDescriptor = FetchDescriptor<WeatherData>()
        let allWeatherRecords = try context.fetch(weatherDescriptor)
        let weatherRecords = allWeatherRecords.filter { $0.timestamp >= thirtyDaysAgo }
        
        exportData["weather_data"] = weatherRecords.map { weather in
            return weather.exportData
        }

        let forecastDayDescriptor = FetchDescriptor<ForecastDay>()
        let forecastDays = try context.fetch(forecastDayDescriptor)
        exportData["forecast_days"] = forecastDays.map { forecast in
            forecast.exportData
        }
        
        return exportData
    }
    
    private func generateCSVExport() async throws -> Data {
        guard let context = modelContext else {
            throw DataPrivacyError.noModelContext
        }
        
        var csvContent = "Type,ID,Title,Description,Category,Active,Created,Updated\n"
        
        // Export reminders
        let reminderDescriptor = FetchDescriptor<WeatherReminder>()
        let reminders = try context.fetch(reminderDescriptor)
        
        for reminder in reminders {
            let row = [
                "Reminder",
                reminder.id.uuidString,
                escapeCSVField(reminder.title),
                escapeCSVField(reminder.reminderDescription),
                reminder.category.rawValue,
                reminder.isCurrentlyActive ? "Yes" : "No",
                DateFormatter.csvFormat.string(from: reminder.createdDate),
                DateFormatter.csvFormat.string(from: reminder.lastModified)
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func deleteAllData(from context: ModelContext) async throws {
        // Delete all reminders
        let reminderDescriptor = FetchDescriptor<WeatherReminder>()
        let reminders = try context.fetch(reminderDescriptor)
        for reminder in reminders {
            context.delete(reminder)
        }

        // Delete trigger conditions explicitly — a condition created without (or detached
        // from) a parent reminder is not covered by the reminder cascade above.
        let conditionDescriptor = FetchDescriptor<TriggerCondition>()
        let conditions = try context.fetch(conditionDescriptor)
        for condition in conditions {
            context.delete(condition)
        }

        // Delete forecast days explicitly for the same reason (orphans are not covered
        // by the WeatherData cascade).
        let forecastDescriptor = FetchDescriptor<ForecastDay>()
        let forecastDays = try context.fetch(forecastDescriptor)
        for forecastDay in forecastDays {
            context.delete(forecastDay)
        }


        // Delete all locations
        let locationDescriptor = FetchDescriptor<LocationData>()
        let locations = try context.fetch(locationDescriptor)
        for location in locations {
            context.delete(location)
        }
        
        // Delete all weather data
        let weatherDescriptor = FetchDescriptor<WeatherData>()
        let weatherRecords = try context.fetch(weatherDescriptor)
        for record in weatherRecords {
            context.delete(record)
        }
        
        // Delete user preferences
        let preferencesDescriptor = FetchDescriptor<UserPreferences>()
        let preferences = try context.fetch(preferencesDescriptor)
        for preference in preferences {
            context.delete(preference)
        }
        
        // Delete notification configs
        let configDescriptor = FetchDescriptor<NotificationConfig>()
        let configs = try context.fetch(configDescriptor)
        for config in configs {
            context.delete(config)
        }
        
        // Delete history
        let historyDescriptor = FetchDescriptor<ReminderHistory>()
        let histories = try context.fetch(historyDescriptor)
        for history in histories {
            context.delete(history)
        }

        // Delete saved locations
        let savedLocationDescriptor = FetchDescriptor<SavedLocation>()
        let savedLocations = try context.fetch(savedLocationDescriptor)
        for savedLocation in savedLocations {
            context.delete(savedLocation)
        }

        // Delete location history
        let locationHistoryDescriptor = FetchDescriptor<LocationHistory>()
        let locationHistories = try context.fetch(locationHistoryDescriptor)
        for locationHistory in locationHistories {
            context.delete(locationHistory)
        }

        try context.save()
        SunHatSearchIndexer.deleteAll()
    }
    
    private func resetAppState() async throws {
        // Reset app to initial onboarding state
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasCreatedFirstReminder")
        UserDefaults.standard.removeObject(forKey: "lastLaunchVersion")

        // Manual coordinates are persisted outside SwiftData by the location
        // service, so they need an explicit privacy-deletion boundary.
        locationPermissionManager.clearStoredLocationData()

        // Notification Center is a separate data store that can retain deleted
        // reminder titles, identifiers, and actions until explicitly cleared.
        try await notificationDataCleaner.clearAllNotificationData()

        // Clear non-persistent caches and one-shot routing/evaluation state that
        // can still contain locations or deleted reminder identifiers.
        await runtimeDataCleaner.clearPrivacyRuntimeData()
        
        // Clear any cached data
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func fetchUserPreferences() async throws -> UserPreferences? {
        guard let context = modelContext else {
            throw DataPrivacyError.noModelContext
        }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        let preferences = try context.fetch(descriptor)
        return preferences.first
    }
    
    private func saveAndShareFile(data: Data, fileName: String, contentType: UTType) async {
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SunHatPrivacyExports", isDirectory: true)
        let fileURL = exportDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(
                at: exportDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )

            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    
                    // Handle iPad presentation
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    rootVC.present(activityVC, animated: true)
                } else {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save export file: \(error.localizedDescription)"
            }
        }
    }
    
    private func estimateDataSize(reminders: Int, locations: Int, weatherRecords: Int) -> Int {
        // Rough estimation of data size in bytes
        let reminderSize = reminders * 1024 // ~1KB per reminder
        let locationSize = locations * 512   // ~0.5KB per location
        let weatherSize = weatherRecords * 2048 // ~2KB per weather record
        
        return reminderSize + locationSize + weatherSize
    }
    
    private func formatDataSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}

// MARK: - Supporting Types

struct DataSummary {
    let reminderCount: Int
    let locationCount: Int
    let weatherRecordCount: Int
    let totalDataSize: String
}

enum DataPrivacyError: LocalizedError, Sendable {
    case noModelContext
    case cloudKitUnavailable
    case exportFailed
    case deletionFailed
    
    nonisolated var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Unable to access app data"
        case .cloudKitUnavailable:
            return "iCloud is not available"
        case .exportFailed:
            return "Failed to export data"
        case .deletionFailed:
            return "Failed to delete data"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let exportFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let csvFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

// MARK: - Export Data Extensions

extension TriggerCondition {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "type": triggerType.rawValue,
            "target_temperature": targetTemperature,
            "comparison_type": comparisonType.rawValue,
            "use_feels_like": useFeelsLike,
            "tolerance": temperatureTolerance,
            "min_temperature": minTemperature ?? 0,
            "max_temperature": maxTemperature ?? 0
        ]
    }
}

extension LocationData {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "display_name": displayName,
            "city": city,
            "state": state,
            "latitude": latitude,
            "longitude": longitude,
            "country": country,
            "timezone": timeZoneIdentifier
        ]
    }
}

extension SavedLocation {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "display_name": displayName,
            "name": name,
            "address": address,
            "city": city,
            "state": state,
            "country": country,
            "latitude": latitude,
            "longitude": longitude,
            "date_added": ISO8601DateFormatter().string(from: dateAdded),
            "last_used": ISO8601DateFormatter().string(from: lastUsed),
            "use_count": useCount,
            "is_favorite": isFavorite,
            "source": source.rawValue
        ]
    }
}

extension LocationHistory {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "accuracy": accuracy,
            "source": source.rawValue
        ]
    }
}

extension WeatherData {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "temperature": temperature,
            "feels_like": feelsLike,
            "humidity": humidity,
            "pressure": pressure,
            "visibility": visibility,
            "uv_index": uvIndex,
            "description": weatherDescription,
            "latitude": locationLatitude,
            "longitude": locationLongitude,
            "forecast_days": forecastDays.map { $0.exportData }
        ]
    }
}

extension ForecastDay {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "date": ISO8601DateFormatter().string(from: date),
            "high_temperature": highTemperature,
            "low_temperature": lowTemperature,
            "average_temperature": averageTemperature,
            "condition": weatherCondition.rawValue,
            "description": weatherDescription,
            "precipitation_probability": precipitationProbability,
            "precipitation_amount": precipitationAmount,
            "precipitation_type": precipitationType.rawValue,
            "wind_speed": windSpeed,
            "humidity": humidity,
            "uv_index": uvIndex,
            "cloud_cover": cloudCover
        ]
    }
}

extension NotificationConfig {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "message": message,
            "delivery_time": deliveryTime.rawValue,
            "priority": priority.rawValue,
            "cooldown_hours": cooldownPeriodHours,
            "critical_alert": criticalAlert
        ]
    }
}

extension ReminderHistory {
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "action": action.rawValue,
            "details": details,
            "weather_conditions": weatherConditionsAtTime,
            "temperature": temperatureAtTime ?? NSNull(),
            "user_response": userResponse.rawValue,
            "response_time": responseTime.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
        ]
    }
}
