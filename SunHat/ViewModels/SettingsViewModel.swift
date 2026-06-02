//
//  SettingsViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
@preconcurrency import UserNotifications
import CoreLocation
import StoreKit
import Combine
import os

@MainActor
final class SettingsViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties

    // Sync status (CloudKit disabled - prepared for future use)
    @Published var syncEnabled: Bool = false
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    @Published var userAccountInfo = "Local storage only"
    
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
    @Published var backgroundLocationEnabled = true
    
    // Preferences
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    @Published var selectedAppearance: AppearanceMode = .system
    
    // UI State
    @Published var showResetConfirmation = false
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var userPreferences: UserPreferences?
    private let locationManager = CLLocationManager()
    private let settingsOpener: SettingsOpening
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "SettingsViewModel")
    
    // MARK: - Initialization
    
    init(settingsOpener: SettingsOpening = ApplicationSettingsOpener()) {
        self.settingsOpener = settingsOpener
        super.init()
        setupLocationManager()
        setupInitialValues()
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadUserPreferences()
        checkNotificationStatus()
        checkLocationStatus()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    private func setupInitialValues() {
        // Set default values based on system locale
        temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        
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
    
    // MARK: - Sync Methods (CloudKit disabled - prepared for future use)

    func forceSyncNow() async {
        // CloudKit sync is currently disabled
        // This method is preserved for future CloudKit integration
        logger.info("Sync is currently disabled - data is stored locally only")
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
    }
    
    private func updateCurrentLocation() {
        // In a real app, this would get the actual location name
        // For now, use a placeholder
        currentLocationName = "Current Location"
    }
    
    // MARK: - Appearance Methods
    
    func applyAppearance() {
        UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "AppAppearance")
        
        Task { @MainActor in
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
    }
    
    // MARK: - Reset Methods
    
    func resetAllSettings() {
        guard let preferences = userPreferences else { return }
        
        // Reset to defaults
        preferences.temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
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
        let email = AppSupportLinks.feedbackEmail
        let subject = "SunHat Feedback"
        let body = """
        
        ---
        App Version: \(appVersion)
        Build: \(buildNumber)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            settingsOpener.open(url)
        }
    }
    
    func contactSupport() {
        let email = AppSupportLinks.supportEmail
        let subject = "SunHat Support Request"
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            settingsOpener.open(url)
        }
    }
    
    func rateApp() {
        Task { @MainActor in
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                if #available(iOS 18.0, *) {
                    AppStore.requestReview(in: scene)
                } else {
                    // For iOS versions below 18.0, use the older API
                    SKStoreReviewController.requestReview()
                }
            }
        }
    }
    
    func openTermsOfService() {
        settingsOpener.open(AppSupportLinks.termsOfServiceURL)
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            settingsOpener.open(url)
        }
    }
    
    // MARK: - Computed Properties
    
    var syncStatusText: String {
        syncEnabled ? "Enabled" : "Disabled"
    }

    var syncStatusColor: Color {
        syncEnabled ? .green : .gray
    }

    var syncStatusMessage: String {
        "Your data is stored locally on this device. iCloud sync will be available in a future update."
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
