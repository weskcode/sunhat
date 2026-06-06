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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingNotificationInfo = false
    @State private var activeSheet: ActiveSheet?
    @StateObject private var locationViewModel = LocationManagementViewModel()

    private enum ActiveSheet: Identifiable {
        case manualLocationEntry
        case about

        var id: Self { self }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                locationSection
                temperatureSection
                appearanceSection
                privacySection
                aboutSection
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                locationViewModel.configure(modelContext: modelContext)
            }
            .alert("Notification Settings", isPresented: $showingNotificationInfo) {
                Button("Settings") {
                    viewModel.openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To receive weather-based reminders, please enable notifications in Settings.")
            }
            .alert(
                "Couldn't Open",
                isPresented: $viewModel.isShowingActionError,
                presenting: viewModel.actionError
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .manualLocationEntry:
                    ManualLocationEntrySheet(viewModel: locationViewModel)
                case .about:
                    AboutView()
                }
            }
        }
    }
    
    // MARK: - Notification Section
    
    private var notificationSection: some View {
        Section {
            // Notification status
            HStack {
                Label("Notifications", systemImage: "bell.fill")
                    .foregroundStyle(.red)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.notificationStatusText)
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(viewModel.notificationsEnabled ? .primary : .secondary)
                    
                    if !viewModel.notificationsEnabled {
                        Button("Enable") {
                            showingNotificationInfo = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
            
            if viewModel.notificationsEnabled {
                // Quiet hours
                Toggle("Quiet Hours", isOn: $viewModel.quietHoursEnabled)
                    .onChange(of: viewModel.quietHoursEnabled) {
                        viewModel.handleQuietHoursChange()
                    }
                
                if viewModel.quietHoursEnabled {
                    HStack {
                        Text("From")
                        Spacer()
                        DatePicker("", selection: $viewModel.quietHoursStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("To")
                        Spacer()
                        DatePicker("", selection: $viewModel.quietHoursEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                
                // Maximum daily notifications
                Stepper("Daily Limit: \(viewModel.maximumDailyNotifications)", 
                       value: $viewModel.maximumDailyNotifications, 
                       in: 1...10)
                    .onChange(of: viewModel.maximumDailyNotifications) {
                        viewModel.handleDailyLimitChange()
                    }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if viewModel.quietHoursEnabled && viewModel.notificationsEnabled {
                Text("Notifications will be silenced during quiet hours: \(viewModel.quietHoursDescription)")
            }
        }
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        Section {
            // Location permission status
            HStack {
                Label("Location Access", systemImage: "location.fill")
                    .foregroundStyle(.blue)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.locationStatusText)
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(viewModel.locationEnabled ? .primary : .secondary)
                    
                    if !viewModel.locationEnabled {
                        Button("Enable") {
                            viewModel.requestLocationPermission()
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
            
            if viewModel.locationEnabled {
                // Current location
                HStack {
                    Text("Current Location")
                    Spacer()
                    Text(viewModel.currentLocationName)
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Button {
                    activeSheet = .manualLocationEntry
                } label: {
                    HStack {
                        Label("Choose City Manually", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Location access is required for weather-based reminders. We only access your location to provide relevant weather data.")
        }
    }
    
    // MARK: - Temperature Section
    
    private var temperatureSection: some View {
        Section {
            Picker("Temperature Unit", selection: $viewModel.temperatureUnit) {
                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                    HStack {
                        Text(unit.symbol)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                        Text(unit.shortName)
                    }
                    .tag(unit)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.temperatureUnit) {
                viewModel.handleTemperatureUnitChange()
            }
        } header: {
            Text("Temperature")
        } footer: {
            Text("Choose your preferred temperature unit for all weather displays and reminders.")
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $viewModel.selectedAppearance) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    HStack {
                        Image(systemName: mode.iconName)
                            .foregroundStyle(mode.color)
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedAppearance) {
                viewModel.handleAppearanceChange()
            }
            
            if viewModel.selectedAppearance == .system {
                HStack {
                    Text("Current Mode")
                    Spacer()
                    Text(colorScheme == .dark ? "Dark" : "Light")
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose how the app appears. System matches your device settings.")
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
            
            Button("Reset All Settings") {
                viewModel.showResetConfirmation = true
            }
            .foregroundStyle(.red)
            .alert("Reset Settings", isPresented: $viewModel.showResetConfirmation) {
                Button("Reset", role: .destructive) {
                    viewModel.resetAllSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all app settings to their defaults. Your reminders will not be affected.")
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(viewModel.buildNumber)
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
            }
            
            Button("Acknowledgments") {
                activeSheet = .about
            }
            
            Button("Terms of Service") {
                viewModel.openTermsOfService()
            }
        } header: {
            Text("About")
        } footer: {
            VStack(spacing: 8) {
                Text("Made with ❤️ for weather enthusiasts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("© 2026 SunHat. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
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
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    var iconName: String {
        switch self {
        case .system:
            return "gear"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .system:
            return .blue
        case .light:
            return .orange
        case .dark:
            return .purple
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
