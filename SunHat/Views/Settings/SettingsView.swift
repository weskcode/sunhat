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

    @State private var activeSheet: ActiveSheet?
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
                SettingsIconLabel(title: "Allow Notifications", systemImage: "bell.badge.fill", color: .red)
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
                SettingsIconLabel(title: "Location Access", systemImage: "location.fill", color: .blue)
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
                SettingsIconLabel(title: "Temperature", systemImage: "thermometer.medium", color: .orange)
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
                SettingsIconLabel(title: "Appearance", systemImage: "circle.lefthalf.filled", color: .indigo)
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
                SettingsIconLabel(title: "Help & FAQ", systemImage: "questionmark", color: .teal)
            }

            Button {
                viewModel.contactSupport()
            } label: {
                SettingsIconLabel(title: "Contact Support", systemImage: "envelope.fill", color: .blue)
            }

            Button {
                viewModel.sendFeedback()
            } label: {
                SettingsIconLabel(title: "Send Feedback", systemImage: "bubble.left.fill", color: .green)
            }

            Button {
                viewModel.rateApp()
            } label: {
                SettingsIconLabel(title: "Rate SunHat", systemImage: "star.fill", color: .yellow)
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
                SettingsIconLabel(title: "Data & Privacy", systemImage: "hand.raised.fill", color: .blue)
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
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [
            UserPreferences.self,
            WeatherReminder.self,
            WeatherData.self,
            LocationData.self
        ], inMemory: true)
}
