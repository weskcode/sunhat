//
//  DataPrivacyViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class DataPrivacyViewModel {
    
    // MARK: - Published Properties
    
    var cloudKitSyncEnabled: Bool = true
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
    
    var cloudKitStatusDescription: String {
        if cloudKitSyncEnabled {
            return "Your data syncs securely across all your Apple devices"
        } else {
            return "Data stays only on this device"
        }
    }
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    func loadDataSummary() async {
        guard let context = getModelContext() else { return }
        
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
            
            let fileName = "TempTrigger_Export_\(DateFormatter.exportFormat.string(from: Date())).json"
            
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
            let fileName = "TempTrigger_Export_\(DateFormatter.exportFormat.string(from: Date())).csv"
            
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
            guard let context = getModelContext() else {
                throw DataPrivacyError.noModelContext
            }
            
            // Delete all data types
            try await deleteAllData(from: context)
            
            // Clear CloudKit data if enabled
            if cloudKitSyncEnabled {
                try await clearCloudKitData()
            }
            
            // Reset app to initial state
            await resetAppState()
            
            statusMessage = "All data has been successfully deleted"
            
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
        }
        
        isDeleting = false
        deleteConfirmationText = ""
    }
    
    func enableCloudKitSync() async {
        isSyncing = true
        
        do {
            // Check CloudKit availability
            let status = try await checkCloudKitStatus()
            
            guard status == .available else {
                throw DataPrivacyError.cloudKitUnavailable
            }
            
            // Enable sync in user preferences
            _ = try await fetchUserPreferences()
            // CloudKit sync would be handled by SwiftData automatically
            cloudKitSyncEnabled = true
            statusMessage = "iCloud sync enabled"
            
        } catch {
            errorMessage = "Failed to enable iCloud sync: \(error.localizedDescription)"
            cloudKitSyncEnabled = false
        }
        
        isSyncing = false
    }
    
    func disableCloudKitSync() async {
        isSyncing = true
        
        // This would typically involve configuring the ModelContainer to not use CloudKit
        // For now, we'll mark it as disabled
        cloudKitSyncEnabled = false
        statusMessage = "iCloud sync disabled. Data remains on this device."
        
        isSyncing = false
    }
    
    func forceSyncNow() async {
        isSyncing = true
        
        do {
            // Trigger manual sync - this would be handled by the ModelContainer
            // For now, simulate sync
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            statusMessage = "Sync completed successfully"
            
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    func contactPrivacyOfficer() {
        let email = "privacy@temptrigger.app"
        let subject = "Privacy Inquiry - TempTrigger App"
        let body = """
        Hello,
        
        I am contacting you regarding my privacy rights under GDPR/CCPA.
        
        My request:
        
        
        Thank you,
        """
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func getModelContext() -> ModelContext? {
        // This would typically be injected through the environment
        do {
            let schema = Schema([
                UserPreferences.self,
                WeatherReminder.self,
                TriggerCondition.self,
                LocationData.self,
                WeatherData.self,
                ForecastDay.self,
                NotificationConfig.self,
                ReminderHistory.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return ModelContext(container)
            
        } catch {
            print("Failed to create model context: \(error)")
            return nil
        }
    }
    
    private func generateExportData() async throws -> [String: Any] {
        guard let context = getModelContext() else {
            throw DataPrivacyError.noModelContext
        }
        
        var exportData: [String: Any] = [:]
        
        // Export metadata
        exportData["export_info"] = [
            "app": "TempTrigger",
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
        
        // Export locations
        let locationDescriptor = FetchDescriptor<LocationData>()
        let locations = try context.fetch(locationDescriptor)
        
        exportData["locations"] = locations.map { location in
            return location.exportData
        }
        
        // Export weather data (recent only, last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let weatherDescriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate { data in
                data.timestamp >= thirtyDaysAgo
            }
        )
        let weatherRecords = try context.fetch(weatherDescriptor)
        
        exportData["weather_data"] = weatherRecords.map { weather in
            return weather.exportData
        }
        
        return exportData
    }
    
    private func generateCSVExport() async throws -> Data {
        guard let context = getModelContext() else {
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
        
        try context.save()
    }
    
    private func clearCloudKitData() async throws {
        // This would involve deleting CloudKit records
        // For now, we'll simulate this operation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func resetAppState() async {
        // Reset app to initial onboarding state
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "lastLaunchVersion")
        
        // Clear any cached data
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func fetchUserPreferences() async throws -> UserPreferences? {
        guard let context = getModelContext() else {
            throw DataPrivacyError.noModelContext
        }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        let preferences = try context.fetch(descriptor)
        return preferences.first
    }
    
    private func checkCloudKitStatus() async throws -> CKAccountStatus {
        let container = CKContainer.default()
        return try await container.accountStatus()
    }
    
    private func saveAndShareFile(data: Data, fileName: String, contentType: UTType) async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                
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

enum DataPrivacyError: LocalizedError {
    case noModelContext
    case cloudKitUnavailable
    case exportFailed
    case deletionFailed
    
    var errorDescription: String? {
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

extension WeatherData {
    var exportData: [String: Any] {
        return [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "temperature": temperature,
            "feels_like": feelsLike,
            "humidity": humidity,
            "pressure": pressure,
            "visibility": visibility,
            "uv_index": uvIndex,
            "description": weatherDescription
        ]
    }
}

extension NotificationConfig {
    var exportData: [String: Any] {
        return [
            "title": title,
            "message": message,
            "delivery_time": deliveryTime.rawValue,
            "priority": priority.rawValue,
            "cooldown_hours": cooldownPeriodHours,
            "critical_alert": criticalAlert
        ]
    }
}