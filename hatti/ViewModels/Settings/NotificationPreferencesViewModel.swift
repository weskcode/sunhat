//
//  NotificationPreferencesViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import Combine
import UIKit

@MainActor
@Observable
final class NotificationPreferencesViewModel {
    
    // MARK: - Published Properties
    
    var quietHoursEnabled: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var allowWeekendNotifications: Bool = true
    var maximumDailyNotifications: Int = 5
    
    // Advanced notification preferences
    var notificationGrouping: NotificationGrouping = .byType
    var lockScreenBehavior: LockScreenBehavior = .showPreviews
    var criticalAlertsEnabled: Bool = false
    var vibrationPattern: VibrationPattern = .default
    var notificationSounds: [String: String] = [:]
    
    // UI State
    var isLoading: Bool = false
    var errorMessage: String?
    var hasUnsavedChanges: Bool = false
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var userPreferences: UserPreferences?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor changes to mark as unsaved
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let propertyName = child.label,
               !["isLoading", "errorMessage", "hasUnsavedChanges", "modelContext", "userPreferences", "cancellables"].contains(propertyName) {
                // Set up change tracking for relevant properties
                // This would be implemented with proper property observation
            }
        }
    }
    
    // MARK: - Public Methods
    
    func loadSettings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load user preferences from SwiftData
            if let preferences = try await fetchUserPreferences() {
                await updateUI(with: preferences)
                userPreferences = preferences
            } else {
                // Create default preferences
                let defaultPreferences = UserPreferences()
                try await saveUserPreferences(defaultPreferences)
                await updateUI(with: defaultPreferences)
                userPreferences = defaultPreferences
            }
        } catch {
            errorMessage = "Failed to load notification settings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func saveSettings() async {
        guard let preferences = userPreferences else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update preferences model
            updatePreferences(preferences)
            
            // Save to SwiftData
            try await saveUserPreferences(preferences)
            
            // Request notification permissions if needed
            await requestNotificationPermissions()
            
            // Update notification categories
            await updateNotificationCategories()
            
            hasUnsavedChanges = false
            
        } catch {
            errorMessage = "Failed to save notification settings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func resetToDefaults() {
        let defaults = UserPreferences()
        
        quietHoursEnabled = defaults.quietHoursEnabled
        quietHoursStart = defaults.quietHoursStart
        quietHoursEnd = defaults.quietHoursEnd
        allowWeekendNotifications = defaults.allowWeekendNotifications
        maximumDailyNotifications = defaults.maximumDailyNotifications
        
        notificationGrouping = defaults.notificationGrouping
        lockScreenBehavior = defaults.lockScreenBehavior
        criticalAlertsEnabled = defaults.criticalAlertsEnabled
        vibrationPattern = defaults.vibrationPattern
        notificationSounds = defaults.notificationSounds
        
        hasUnsavedChanges = true
    }
    
    func selectedSoundForType(_ type: String) -> NotificationSound {
        if let soundRawValue = notificationSounds[type],
           let sound = NotificationSound(rawValue: soundRawValue) {
            return sound
        }
        return .default
    }
    
    func setSound(_ sound: NotificationSound, for type: String) {
        notificationSounds[type] = sound.rawValue
        hasUnsavedChanges = true
    }
    
    var quietHoursDescription: String {
        if quietHoursEnabled {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let startTime = formatter.string(from: quietHoursStart)
            let endTime = formatter.string(from: quietHoursEnd)
            return "\(startTime) - \(endTime)"
        } else {
            return "Disabled"
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUI(with preferences: UserPreferences) async {
        quietHoursEnabled = preferences.quietHoursEnabled
        quietHoursStart = preferences.quietHoursStart
        quietHoursEnd = preferences.quietHoursEnd
        allowWeekendNotifications = preferences.allowWeekendNotifications
        maximumDailyNotifications = preferences.maximumDailyNotifications
        
        notificationGrouping = preferences.notificationGrouping
        lockScreenBehavior = preferences.lockScreenBehavior
        criticalAlertsEnabled = preferences.criticalAlertsEnabled
        vibrationPattern = preferences.vibrationPattern
        notificationSounds = preferences.notificationSounds
        
        hasUnsavedChanges = false
    }
    
    private func updatePreferences(_ preferences: UserPreferences) {
        preferences.quietHoursEnabled = quietHoursEnabled
        preferences.quietHoursStart = quietHoursStart
        preferences.quietHoursEnd = quietHoursEnd
        preferences.allowWeekendNotifications = allowWeekendNotifications
        preferences.maximumDailyNotifications = maximumDailyNotifications
        
        preferences.notificationGrouping = notificationGrouping
        preferences.lockScreenBehavior = lockScreenBehavior
        preferences.criticalAlertsEnabled = criticalAlertsEnabled
        preferences.vibrationPattern = vibrationPattern
        preferences.notificationSounds = notificationSounds
        
        preferences.updateTimestamp()
    }
    
    private func fetchUserPreferences() async throws -> UserPreferences? {
        guard let context = getModelContext() else {
            throw NotificationError.noModelContext
        }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        let preferences = try context.fetch(descriptor)
        return preferences.first
    }
    
    private func saveUserPreferences(_ preferences: UserPreferences) async throws {
        guard let context = getModelContext() else {
            throw NotificationError.noModelContext
        }
        
        context.insert(preferences)
        try context.save()
    }
    
    private func getModelContext() -> ModelContext? {
        // This would typically be injected through the environment
        // For now, we'll create a temporary context or use app's shared context
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
    
    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        if criticalAlertsEnabled {
            options.insert(.criticalAlert)
        }
        
        do {
            let granted = try await center.requestAuthorization(options: options)
            if !granted {
                errorMessage = "Notification permissions are required for weather alerts"
            }
        } catch {
            errorMessage = "Failed to request notification permissions: \(error.localizedDescription)"
        }
    }
    
    private func updateNotificationCategories() async {
        let center = UNUserNotificationCenter.current()
        
        // Create notification categories for different reminder types
        var categories: Set<UNNotificationCategory> = []
        
        // General weather reminder category
        let generalCategory = UNNotificationCategory(
            identifier: "WEATHER_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "COMPLETE_ACTION",
                    title: "Mark Complete",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "SNOOZE_ACTION",
                    title: "Snooze 2 Hours",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(generalCategory)
        
        // Exercise reminder category
        let exerciseCategory = UNNotificationCategory(
            identifier: "EXERCISE_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "START_WORKOUT",
                    title: "Start Workout",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SKIP_TODAY",
                    title: "Skip Today",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(exerciseCategory)
        
        // Gardening reminder category
        let gardeningCategory = UNNotificationCategory(
            identifier: "GARDENING_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "WATER_PLANTS",
                    title: "Water Plants",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REMIND_LATER",
                    title: "Remind Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(gardeningCategory)
        
        // Maintenance reminder category
        let maintenanceCategory = UNNotificationCategory(
            identifier: "MAINTENANCE_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "START_TASK",
                    title: "Start Task",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "POSTPONE",
                    title: "Postpone",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(maintenanceCategory)
        
        // Critical weather alert category
        if criticalAlertsEnabled {
            let criticalCategory = UNNotificationCategory(
                identifier: "CRITICAL_WEATHER_ALERT",
                actions: [
                    UNNotificationAction(
                        identifier: "VIEW_DETAILS",
                        title: "View Details",
                        options: .foreground
                    ),
                    UNNotificationAction(
                        identifier: "ACKNOWLEDGE",
                        title: "Acknowledge",
                        options: []
                    )
                ],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            categories.insert(criticalCategory)
        }
        
        center.setNotificationCategories(categories)
    }
}

// MARK: - Error Types

enum NotificationError: LocalizedError {
    case noModelContext
    case permissionDenied
    case invalidSettings
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Unable to access app data"
        case .permissionDenied:
            return "Notification permissions were denied"
        case .invalidSettings:
            return "Invalid notification settings"
        }
    }
}

// MARK: - Extensions

extension NotificationPreferencesViewModel {
    
    func testNotification(for type: String) async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is how your \(type) notifications will appear"
        content.sound = .default
        
        // Apply current settings
        if let soundRawValue = notificationSounds[type],
           let sound = NotificationSound(rawValue: soundRawValue),
           let fileName = sound.fileName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))
        }
        
        // Set category based on type
        switch type {
        case "exercise":
            content.categoryIdentifier = "EXERCISE_REMINDER"
        case "gardening":
            content.categoryIdentifier = "GARDENING_REMINDER"
        case "maintenance":
            content.categoryIdentifier = "MAINTENANCE_REMINDER"
        default:
            content.categoryIdentifier = "WEATHER_REMINDER"
        }
        
        let request = UNNotificationRequest(
            identifier: "test-\(type)-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        do {
            try await center.add(request)
        } catch {
            errorMessage = "Failed to send test notification: \(error.localizedDescription)"
        }
    }
    
    func checkNotificationPermissions() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}