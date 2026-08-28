//
//  NotificationPreferencesViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
@preconcurrency import UserNotifications
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
    private let settingsOpener: SettingsOpening
    private let notificationPermissions: NotificationPermissionProviding

    // MARK: - Initialization

    init(
        settingsOpener: SettingsOpening = ApplicationSettingsOpener(),
        notificationPermissions: NotificationPermissionProviding = UserNotificationPermissionProvider()
    ) {
        self.settingsOpener = settingsOpener
        self.notificationPermissions = notificationPermissions
    }

    /// Must be called with the app's shared model context so preference
    /// reads and writes hit the same app-group store as the rest of the app.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
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
            errorMessage = String(localized: "Failed to load notification settings: \(error.localizedDescription)", comment: "Error shown in Settings when saved notification preferences could not be read")
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
            errorMessage = String(localized: "Failed to save notification settings: \(error.localizedDescription)", comment: "Error shown in Settings when notification preferences could not be saved")
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
            return String(localized: "\(startTime) - \(endTime)", comment: "Quiet hours time range, e.g. '10:00 PM - 7:00 AM'")
        } else {
            return String(localized: "Disabled", comment: "Quiet hours state when the user has turned them off")
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
        guard let context = modelContext else {
            throw NotificationError.noModelContext
        }

        let descriptor = FetchDescriptor<UserPreferences>()
        let preferences = try context.fetch(descriptor)
        return preferences.first
    }

    private func saveUserPreferences(_ preferences: UserPreferences) async throws {
        guard let context = modelContext else {
            throw NotificationError.noModelContext
        }

        context.insert(preferences)
        try context.save()
    }

    private func requestNotificationPermissions() async {
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]

        if criticalAlertsEnabled {
            options.insert(.criticalAlert)
        }

        do {
            let granted = try await notificationPermissions.requestAuthorization(options: options)
            if !granted {
                errorMessage = String(localized: "Notification permissions are required for weather alerts", comment: "Error shown when the user denies notification permission needed for reminders")
            }
        } catch {
            errorMessage = String(localized: "Failed to request notification permissions: \(error.localizedDescription)", comment: "Error shown when the system permission request itself fails")
        }
    }
    
    private func updateNotificationCategories() async {
        let center = UNUserNotificationCenter.current()
        SunHatNotificationCategoryRegistry.register(
            includeCriticalAlerts: criticalAlertsEnabled,
            center: center
        )
    }
}

// MARK: - Error Types

enum NotificationError: LocalizedError, Sendable {
    case noModelContext
    case permissionDenied
    case invalidSettings
    
    nonisolated var errorDescription: String? {
        switch self {
        case .noModelContext:
            return String(localized: "Unable to access app data", comment: "Notification error when the local data store is unavailable")
        case .permissionDenied:
            return String(localized: "Notification permissions were denied", comment: "Notification error when the system permission was denied")
        case .invalidSettings:
            return String(localized: "Invalid notification settings", comment: "Notification error for malformed preferences")
        }
    }
}

// MARK: - Extensions

extension NotificationPreferencesViewModel {
    
    func testNotification(for type: String) async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Test Notification", comment: "Title of a sample notification the user triggers to preview notification style")
        content.body = String(localized: "This is how your \(type) notifications will appear", comment: "Body of a sample notification; 'type' is a reminder category name such as Exercise or Gardening")
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
            errorMessage = String(localized: "Failed to send test notification: \(error.localizedDescription)", comment: "Error shown when the sample notification could not be scheduled")
        }
    }
    
    func checkNotificationPermissions() async -> UNAuthorizationStatus {
        await notificationPermissions.authorizationStatus()
    }
    
    func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            Task {
                let opened = await settingsOpener.open(settingsUrl)
                if opened == false {
                    errorMessage = String(localized: "Couldn't open Settings. Open the Settings app manually to change SunHat's notification permissions.", comment: "Error shown when deep-linking to the iOS Settings app fails")
                }
            }
        }
    }
}
