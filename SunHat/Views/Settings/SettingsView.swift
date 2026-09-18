//
//  SettingsView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeSheet: ActiveSheet?
    @State private var adManager = AdManager.shared
    @StateObject private var locationViewModel = LocationManagementViewModel()

    private enum ActiveSheet: Identifiable {
        case manualLocationEntry
        case helpFAQ
        case dataPrivacy
        case about

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                locationSection
                generalSection
                AdFreeSettingsSection()
                supportSection
                privacySection
                aboutSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                locationViewModel.configure(modelContext: modelContext)
                // UMP state isn't observable, so re-read it when Settings
                // appears; Google requires the privacy-options entry point to
                // be reachable whenever the framework says it's required.
                adManager.refreshConsentState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // The system notification permission has no delegate callback,
                // unlike location, so a user who flips it in the iOS Settings
                // app and returns here would otherwise see a stale toggle.
                if newPhase == .active {
                    viewModel.checkNotificationStatus()
                }
            }
            .alert(
                viewModel.activeAlert?.title ?? "",
                isPresented: Binding(
                    get: { viewModel.activeAlert != nil },
                    set: { if !$0 { viewModel.activeAlert = nil } }
                ),
                presenting: viewModel.activeAlert
            ) { alert in
                switch alert {
                case .permissionDenied:
                    Button("Open Settings") {
                        viewModel.openAppSettings()
                    }
                    Button("Cancel", role: .cancel) { }
                case .actionFailed:
                    Button("OK", role: .cancel) { }
                case .confirmReset:
                    Button("Reset", role: .destructive) {
                        viewModel.resetAllSettings()
                    }
                    Button("Cancel", role: .cancel) { }
                }
            } message: { alert in
                switch alert {
                case .permissionDenied:
                    Text("To get weather reminders, allow notifications for SunHat in Settings.")
                case .actionFailed(let message):
                    Text(message)
                case .confirmReset:
                    Text("This will reset all app settings to their defaults. Your reminders will not be affected.")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .manualLocationEntry:
                    ManualLocationEntrySheet(viewModel: locationViewModel)
                case .helpFAQ:
                    HelpFAQView()
                case .dataPrivacy:
                    DataPrivacyView()
                case .about:
                    AboutView()
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $viewModel.notificationsToggleIsOn) {
                SettingsIconLabel(title: String(localized: "Allow Notifications", comment: "Settings row toggling the notification master switch"), systemImage: "bell.badge.fill", color: .red)
            }

            if viewModel.notificationsEnabled {
                Toggle("Quiet Hours", isOn: $viewModel.quietHoursEnabled)
                    .onChange(of: viewModel.quietHoursEnabled) {
                        viewModel.handleQuietHoursChange()
                    }

                if viewModel.quietHoursEnabled {
                    QuietHoursWindowPicker(
                        start: $viewModel.quietHoursStart,
                        end: $viewModel.quietHoursEnd
                    )
                    .onChange(of: viewModel.quietHoursStart) {
                        viewModel.handleQuietHoursChange()
                    }
                    .onChange(of: viewModel.quietHoursEnd) {
                        viewModel.handleQuietHoursChange()
                    }
                }

                Stepper(value: $viewModel.maximumDailyNotifications, in: 1...10) {
                    HStack {
                        Text("Daily Limit")
                        Spacer()
                        Text("\(viewModel.maximumDailyNotifications)")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: viewModel.maximumDailyNotifications) {
                    viewModel.handleDailyLimitChange()
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if !viewModel.notificationsEnabled {
                Text("SunHat won't send weather reminders while notifications are off.")
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        Section {
            HStack {
                SettingsIconLabel(title: String(localized: "Location Access", comment: "Settings row showing location permission status"), systemImage: "location.fill", color: .blue)
                Spacer()
                Text(viewModel.locationEnabled ? String(localized: "While Using", comment: "Location access status") : String(localized: "Off", comment: "Location access status"))
                    .foregroundStyle(.secondary)
            }

            if viewModel.locationEnabled {
                LabeledContent("Current Location", value: viewModel.currentLocationName)

                Button("Choose City Manually…") {
                    activeSheet = .manualLocationEntry
                }
            } else {
                Button("Allow Location Access") {
                    viewModel.requestLocationPermission()
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Your location is used only to fetch forecasts from enabled weather providers for your reminders.")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Picker(selection: $viewModel.temperatureUnit) {
                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                    Text("\(unit.shortName) (\(unit.symbol))")
                        .tag(unit)
                }
            } label: {
                SettingsIconLabel(title: String(localized: "Temperature", comment: "Settings row for the temperature unit picker"), systemImage: "thermometer.medium", color: .orange)
            }
            .onChange(of: viewModel.temperatureUnit) {
                viewModel.handleTemperatureUnitChange()
            }

            Picker(selection: $viewModel.selectedAppearance) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            } label: {
                SettingsIconLabel(title: String(localized: "Appearance", comment: "Settings row for the light/dark/system appearance picker"), systemImage: "circle.lefthalf.filled", color: .indigo)
            }
            .onChange(of: viewModel.selectedAppearance) {
                viewModel.handleAppearanceChange()
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section("Support") {
            Button {
                activeSheet = .helpFAQ
            } label: {
                SettingsIconLabel(title: String(localized: "Help & FAQ", comment: "Settings row opening the Help & FAQ sheet"), systemImage: "questionmark", color: .teal)
            }

            Button {
                viewModel.contactSupport()
            } label: {
                SettingsIconLabel(title: String(localized: "Contact Support", comment: "Settings row composing a support email"), systemImage: "envelope.fill", color: .blue)
            }

            Button {
                viewModel.sendFeedback()
            } label: {
                SettingsIconLabel(title: String(localized: "Send Feedback", comment: "Settings row composing a feedback email"), systemImage: "bubble.left.fill", color: .green)
            }

            Button {
                viewModel.rateApp()
            } label: {
                SettingsIconLabel(title: String(localized: "Rate SunHat", comment: "Settings row requesting an App Store rating; 'SunHat' is the app name"), systemImage: "star.fill", color: .yellow)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            Button {
                activeSheet = .dataPrivacy
            } label: {
                SettingsIconLabel(title: String(localized: "Data & Privacy", comment: "Settings row opening the Data & Privacy sheet"), systemImage: "hand.raised.fill", color: .blue)
            }
            .foregroundStyle(.primary)

            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
            .foregroundStyle(.primary)

            Button("Terms of Service") {
                viewModel.openTermsOfService()
            }
            .foregroundStyle(.primary)

            // Google-required consent revocation entry point; only appears
            // for users in regions where the consent framework mandates it.
            if adManager.privacyOptionsRequired {
                Button("Ad Privacy Options") {
                    adManager.presentPrivacyOptions()
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "\(viewModel.appVersion) (\(viewModel.buildNumber))")

            Button("Acknowledgments") {
                activeSheet = .about
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button("Reset All Settings", role: .destructive) {
                viewModel.activeAlert = .confirmReset
            }
        } footer: {
            Text("© 2026 SunHat")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
    }
}

// MARK: - Appearance Mode Enum

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    static let defaultsKey = "AppAppearance"

    /// The last-saved appearance choice, or `.system` if none was ever saved.
    static var stored: AppearanceMode {
        guard let saved = UserDefaults.standard.object(forKey: defaultsKey) as? String,
              let appearance = AppearanceMode(rawValue: saved) else {
            return .system
        }
        return appearance
    }

    var displayName: String {
        switch self {
        case .system:
            return String(localized: "System", comment: "Appearance mode option: follow the system light/dark setting")
        case .light:
            return String(localized: "Light", comment: "Appearance mode option: always light")
        case .dark:
            return String(localized: "Dark", comment: "Appearance mode option: always dark")
        }
    }

    /// Applies this appearance to the app's window. Called both when the
    /// user changes the setting and once at launch, since setting the
    /// UserDefaults value alone (what the app previously did) never
    /// re-applied it to a freshly created window.
    @MainActor
    func apply() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        switch self {
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(StoreManager.shared)
        .modelContainer(for: [
            UserPreferences.self,
            WeatherReminder.self,
            WeatherData.self,
            LocationData.self
        ], inMemory: true)
}
