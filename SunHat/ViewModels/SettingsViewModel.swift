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
import os

enum SettingsAlert: Identifiable, Equatable {
    case permissionDenied
    case actionFailed(String)
    case confirmReset

    var id: String {
        switch self {
        case .permissionDenied: return "permissionDenied"
        case .actionFailed: return "actionFailed"
        case .confirmReset: return "confirmReset"
        }
    }

    var title: String {
        switch self {
        case .permissionDenied:
            return String(localized: "Notifications Are Off", comment: "Settings alert title")
        case .actionFailed:
            return String(localized: "Couldn't Open", comment: "Settings alert title")
        case .confirmReset:
            return String(localized: "Reset Settings", comment: "Settings alert title")
        }
    }
}

@MainActor @Observable
final class SettingsViewModel {
    // Sync status (CloudKit disabled - prepared for future use)
    var lastSyncTime: Date?

    // Notifications
    /// Whether the in-app master switch is on AND the system permission is
    /// granted, the single source of truth the toggle displays.
    var notificationsEnabled = false
    var defaultNotificationTiming: NotificationTiming = .immediate
    var quietHoursEnabled = true
    var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var allowWeekendNotifications = true
    var maximumDailyNotifications = 5

    // Location
    var locationEnabled = false
    var currentLocationName = "Unknown"

    // Preferences
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var selectedAppearance: AppearanceMode = .system

    // UI State
    /// The at-most-one currently visible alert on this screen. A single
    /// optional instead of separate booleans makes "only one alert at a
    /// time" structural: the permission-denied alert's "Open Settings"
    /// action can itself fail and want to show the action-error alert, and
    /// without a shared source of truth that's a real collision risk.
    var activeAlert: SettingsAlert?

    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private var userPreferences: UserPreferences?
    private let locationDelegate: SettingsLocationDelegate
    let settingsOpener: SettingsOpening
    private let notificationPermissions: NotificationPermissionProviding
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "SettingsViewModel")

    // MARK: - Initialization

    init(
        settingsOpener: SettingsOpening = ApplicationSettingsOpener(),
        notificationPermissions: NotificationPermissionProviding = UserNotificationPermissionProvider()
    ) {
        self.settingsOpener = settingsOpener
        self.notificationPermissions = notificationPermissions
        let delegate = SettingsLocationDelegate()
        self.locationDelegate = delegate

        delegate.onAuthorizationChange = { [weak self] status in
            self?.updateLocationStatus(status)
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self?.updateCurrentLocation()
            }
        }

        setupInitialValues()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadUserPreferences()
        checkNotificationStatus()
        checkLocationStatus()
    }

    // MARK: - Setup Methods

    private func setupInitialValues() {
        temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit

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

    // MARK: - Notification Methods

    /// Binding target for the "Allow Notifications" toggle. Setting it runs
    /// the permission flow asynchronously; the stored property only flips
    /// once the outcome is known, so a denied request visibly snaps the
    /// toggle back off.
    var notificationsToggleIsOn: Bool {
        get { notificationsEnabled }
        set { setNotificationsEnabled(newValue) }
    }

    private func checkNotificationStatus() {
        Task {
            let status = await notificationPermissions.authorizationStatus()
            let masterSwitchOn = userPreferences?.notificationsEnabled ?? true
            self.notificationsEnabled = masterSwitchOn && status == .authorized
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        guard enabled else {
            notificationsEnabled = false
            userPreferences?.notificationsEnabled = false
            savePreferences()
            return
        }

        Task {
            let status = await notificationPermissions.authorizationStatus()
            switch status {
            case .notDetermined:
                do {
                    let granted = try await notificationPermissions.requestAuthorization(options: [.alert, .badge, .sound])
                    notificationsEnabled = granted
                    userPreferences?.notificationsEnabled = granted
                } catch {
                    logger.error("Failed to request notification permission: \(error)")
                    notificationsEnabled = false
                    activeAlert = .actionFailed("Couldn't request notification permission. Enable notifications for SunHat in the Settings app.")
                }
            case .denied:
                notificationsEnabled = false
                activeAlert = .permissionDenied
            default: // .authorized, .provisional, .ephemeral
                notificationsEnabled = true
                userPreferences?.notificationsEnabled = true
            }
            savePreferences()
        }
    }

    // MARK: - Location Methods

    private func checkLocationStatus() {
        let status = locationDelegate.authorizationStatus
        updateLocationStatus(status)

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            updateCurrentLocation()
        }
    }

    func requestLocationPermission() {
        locationDelegate.requestWhenInUseAuthorization()
    }

    private func updateLocationStatus(_ status: CLAuthorizationStatus) {
        locationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private func updateCurrentLocation() {
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

        preferences.temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        preferences.defaultNotificationTiming = .immediate
        preferences.notificationsEnabled = true
        preferences.quietHoursEnabled = true
        preferences.quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        preferences.quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        preferences.allowWeekendNotifications = true
        preferences.maximumDailyNotifications = 5
        preferences.selectedActivityInterests = []

        selectedAppearance = .system
        UserDefaults.standard.removeObject(forKey: "AppAppearance")

        applyPreferences(preferences)
        savePreferences()
        applyAppearance()
        checkNotificationStatus()

        logger.info("All settings reset to defaults")
    }

    // MARK: - Support Methods

    func sendFeedback() {
        let email = AppSupportLinks.feedbackEmail
        let subject = String(localized: "SunHat Feedback", comment: "Pre-filled subject line of the feedback email the app composes; 'SunHat' is the app name")
        let body = String(localized: """

        ---
        App Version: \(appVersion)
        Build: \(buildNumber)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """, comment: "Pre-filled body of the feedback email the app composes, listing diagnostic info after the user's own message")

        if let url = AppSupportLinks.mailURL(to: email, subject: subject, body: body) {
            open(url, failureMessage: String(localized: "Couldn't open Mail. Set up a mail account, or email \(email) directly.", comment: "Error shown when deep-linking to the Mail app fails"))
        }
    }

    func contactSupport() {
        let email = AppSupportLinks.supportEmail
        let subject = String(localized: "SunHat Support Request", comment: "Pre-filled subject line of the support email the app composes; 'SunHat' is the app name")

        if let url = AppSupportLinks.mailURL(to: email, subject: subject) {
            open(url, failureMessage: String(localized: "Couldn't open Mail. Set up a mail account, or email \(email) directly.", comment: "Error shown when deep-linking to the Mail app fails"))
        }
    }

    /// Opens a URL through the injected opener and surfaces a user-visible alert if the
    /// system can't handle it (e.g. a mailto link with no configured mail account).
    private func open(_ url: URL, failureMessage: String) {
        Task {
            let opened = await settingsOpener.open(url)
            if opened == false {
                activeAlert = .actionFailed(failureMessage)
            }
        }
    }

    func rateApp() {
        Task { @MainActor in
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                if #available(iOS 18.0, *) {
                    AppStore.requestReview(in: scene)
                } else {
                    SKStoreReviewController.requestReview()
                }
            }
        }
    }

    func openTermsOfService() {
        open(
            AppSupportLinks.termsOfServiceURL,
            failureMessage: String(localized: "Couldn't open the Terms of Service. Visit \(AppSupportLinks.termsOfServiceURL.absoluteString) in a browser.", comment: "Error shown when opening the Terms of Service link fails")
        )
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            open(url, failureMessage: String(localized: "Couldn't open Settings. Open the Settings app manually to change SunHat's permissions.", comment: "Error shown when deep-linking to the iOS Settings app fails"))
        }
    }

    // MARK: - Computed Properties

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

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "Unknown", comment: "Fallback app version when it cannot be read from the bundle")
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}

// MARK: - Change Handlers

extension SettingsViewModel {
    func handleTemperatureUnitChange() {
        savePreferences()
    }

    func handleQuietHoursChange() {
        savePreferences()
    }

    func handleDailyLimitChange() {
        savePreferences()
    }

    func handleAppearanceChange() {
        applyAppearance()
    }
}

// MARK: - Location Delegate Helper

private final class SettingsLocationDelegate: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor [weak self] in
            self?.onAuthorizationChange?(status)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
