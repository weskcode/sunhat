//
//  SettingsViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation
import CloudKit
import StoreKit
import Combine
import os.log

@MainActor
final class SettingsViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    // CloudKit sync
    @Published var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    @Published var userAccountInfo = "Not signed in"
    
    // Notifications
    @Published var notificationsEnabled = false
    @Published var defaultNotificationTiming: NotificationTiming = .immediate
    @Published var quietHoursEnabled = true
    @Published var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @Published var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @Published var allowWeekendNotifications = true
    @Published var maximumDailyNotifications = 5
    
    // Location
    @Published var locationEnabled = false
    @Published var currentLocationName = "Unknown"
    @Published var backgroundLocationEnabled = false
    
    // Preferences
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    @Published var selectedAppearance: AppearanceMode = .system
    
    // UI State
    @Published var showResetConfirmation = false
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var userPreferences: UserPreferences?
    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "SettingsViewModel")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
        setupInitialValues()
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadUserPreferences()
        checkNotificationStatus()
        checkCloudKitStatus()
        checkLocationStatus()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    private func setupInitialValues() {
        // Set default values based on system locale
        temperatureUnit = Locale.current.usesMetricSystem ? .celsius : .fahrenheit
        
        // Load appearance preference from UserDefaults
        if let savedAppearance = UserDefaults.standard.object(forKey: "AppAppearance") as? String,
           let appearance = AppearanceMode(rawValue: savedAppearance) {
            selectedAppearance = appearance
        }
    }
    
    // MARK: - Data Loading
    
    private func loadUserPreferences() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        
        do {
            let preferences = try modelContext.fetch(descriptor)
            
            if let existing = preferences.first {
                userPreferences = existing
                applyPreferences(existing)
            } else {
                createDefaultPreferences()
            }
        } catch {
            logger.error("Failed to load user preferences: \(error)")
            createDefaultPreferences()
        }
    }
    
    private func createDefaultPreferences() {
        guard let modelContext = modelContext else { return }
        
        let preferences = UserPreferences()
        userPreferences = preferences
        modelContext.insert(preferences)
        
        do {
            try modelContext.save()
            applyPreferences(preferences)
        } catch {
            logger.error("Failed to create default preferences: \(error)")
        }
    }
    
    private func applyPreferences(_ preferences: UserPreferences) {
        temperatureUnit = preferences.temperatureUnit
        defaultNotificationTiming = preferences.defaultNotificationTiming
        quietHoursEnabled = preferences.quietHoursEnabled
        quietHoursStart = preferences.quietHoursStart
        quietHoursEnd = preferences.quietHoursEnd
        allowWeekendNotifications = preferences.allowWeekendNotifications
        maximumDailyNotifications = preferences.maximumDailyNotifications
        lastSyncTime = preferences.lastSyncedAt
    }
    
    private func savePreferences() {
        guard let preferences = userPreferences else { return }
        
        preferences.temperatureUnit = temperatureUnit
        preferences.defaultNotificationTiming = defaultNotificationTiming
        preferences.quietHoursEnabled = quietHoursEnabled
        preferences.quietHoursStart = quietHoursStart
        preferences.quietHoursEnd = quietHoursEnd
        preferences.allowWeekendNotifications = allowWeekendNotifications
        preferences.maximumDailyNotifications = maximumDailyNotifications
        preferences.updateTimestamp()
        
        do {
            try modelContext?.save()
            logger.debug("User preferences saved successfully")
        } catch {
            logger.error("Failed to save preferences: \(error)")
        }
    }
    
    // MARK: - CloudKit Methods
    
    private func checkCloudKitStatus() {
        Task {
            do {
                let status = try await CKContainer.default().accountStatus()
                await MainActor.run {
                    self.cloudKitStatus = status
                    self.updateUserAccountInfo()
                }
            } catch {
                logger.error("Failed to check CloudKit status: \(error)")
            }
        }
    }
    
    private func updateUserAccountInfo() {
        switch cloudKitStatus {
        case .available:
            userAccountInfo = "Signed in to iCloud"
        case .noAccount:
            userAccountInfo = "Not signed in to iCloud"
        case .restricted:
            userAccountInfo = "iCloud restricted"
        case .couldNotDetermine:
            userAccountInfo = "iCloud status unknown"
        case .temporarilyUnavailable:
            userAccountInfo = "iCloud temporarily unavailable"
        @unknown default:
            userAccountInfo = "iCloud status unknown"
        }
    }
    
    func forceSyncNow() async {
        guard cloudKitStatus == .available else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Simulate CloudKit sync operation
            try await Task.sleep(for: .seconds(2))
            
            lastSyncTime = Date()
            userPreferences?.lastSyncedAt = Date()
            savePreferences()
            
            logger.info("CloudKit sync completed successfully")
        } catch {
            logger.error("CloudKit sync failed: \(error)")
        }
    }
    
    // MARK: - Notification Methods
    
    private func checkNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestNotificationPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                await MainActor.run {
                    self.notificationsEnabled = granted
                }
            } catch {
                logger.error("Failed to request notification permission: \(error)")
            }
        }
    }
    
    // MARK: - Location Methods
    
    private func checkLocationStatus() {
        let status = locationManager.authorizationStatus
        updateLocationStatus(status)
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            updateCurrentLocation()
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func updateLocationStatus(_ status: CLAuthorizationStatus) {
        locationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
        backgroundLocationEnabled = status == .authorizedAlways
    }
    
    private func updateCurrentLocation() {
        // In a real app, this would get the actual location name
        // For now, use a placeholder
        currentLocationName = "Current Location"
    }
    
    // MARK: - Appearance Methods
    
    func applyAppearance() {
        UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "AppAppearance")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch selectedAppearance {
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        }
    }
    
    // MARK: - Reset Methods
    
    func resetAllSettings() {
        guard let preferences = userPreferences else { return }
        
        // Reset to defaults
        preferences.temperatureUnit = Locale.current.usesMetricSystem ? .celsius : .fahrenheit
        preferences.defaultNotificationTiming = .immediate
        preferences.quietHoursEnabled = true
        preferences.quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        preferences.quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        preferences.allowWeekendNotifications = true
        preferences.maximumDailyNotifications = 5
        preferences.selectedActivityInterests = []
        
        // Reset appearance
        selectedAppearance = .system
        UserDefaults.standard.removeObject(forKey: "AppAppearance")
        
        applyPreferences(preferences)
        savePreferences()
        applyAppearance()
        
        logger.info("All settings reset to defaults")
    }
    
    // MARK: - Support Methods
    
    func sendFeedback() {
        let email = "feedback@temptrigger.app"
        let subject = "TempTrigger Feedback"
        let body = """
        
        ---
        App Version: \(appVersion)
        Build: \(buildNumber)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    func contactSupport() {
        let email = "support@temptrigger.app"
        let subject = "TempTrigger Support Request"
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    func rateApp() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func openTermsOfService() {
        if let url = URL(string: "https://temptrigger.app/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Computed Properties
    
    var cloudKitStatusText: String {
        switch cloudKitStatus {
        case .available:
            return "Connected"
        case .noAccount:
            return "Not signed in"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
    
    var cloudKitStatusColor: Color {
        switch cloudKitStatus {
        case .available:
            return .green
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .orange
        case .couldNotDetermine:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    var cloudKitStatusMessage: String {
        switch cloudKitStatus {
        case .available:
            return "Your data is being synced across all your devices using iCloud."
        case .noAccount:
            return "Sign in to iCloud in Settings to sync your reminders across devices."
        case .restricted:
            return "iCloud sync is restricted on this device. Check your device restrictions."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Sync will resume when available."
        default:
            return "Unable to determine iCloud status. Please check your internet connection."
        }
    }
    
    var notificationStatusText: String {
        notificationsEnabled ? "Enabled" : "Disabled"
    }
    
    var locationStatusText: String {
        locationEnabled ? "Enabled" : "Disabled"
    }
    
    var quietHoursDescription: String {
        if quietHoursEnabled {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: quietHoursStart)) - \(formatter.string(from: quietHoursEnd))"
        } else {
            return "Disabled"
        }
    }
    
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}

// MARK: - Location Manager Delegate

extension SettingsViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            updateLocationStatus(status)
            
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                updateCurrentLocation()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates if needed
        Task { @MainActor in
            updateCurrentLocation()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed with error: \(error)")
    }
}

// MARK: - Change Handlers

extension SettingsViewModel {
    func handleTemperatureUnitChange() {
        savePreferences()
    }
    
    func handleNotificationTimingChange() {
        savePreferences()
    }
    
    func handleQuietHoursChange() {
        savePreferences()
    }
    
    func handleWeekendNotificationsChange() {
        savePreferences()
    }
    
    func handleDailyLimitChange() {
        savePreferences()
    }
    
    func handleAppearanceChange() {
        applyAppearance()
    }
}