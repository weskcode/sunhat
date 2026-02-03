//
//  DataPrivacyView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct DataPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = DataPrivacyViewModel()
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportOptions = false
    @State private var showingPrivacyPolicy = false
    @State private var showingContactOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                // Data Collection Overview
                dataCollectionSection

                // Data Storage Info (CloudKit disabled)
                storageSection

                // Data Export
                dataExportSection

                // Data Deletion
                dataDeletionSection

                // Weather Data Sources
                weatherDataSourcesSection

                // Third-Party Services
                thirdPartyServicesSection

                // Privacy Rights (GDPR/CCPA)
                privacyRightsSection

                // Contact & Support
                contactSection
            }
            .navigationTitle("Data & Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadDataSummary()
                }
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                TextField("Type DELETE to confirm", text: $viewModel.deleteConfirmationText)
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await viewModel.deleteAllUserData()
                    }
                }
                .disabled(!viewModel.deleteConfirmationValid)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your reminders, preferences, and weather data will be permanently deleted from this device.")
            }
            .sheet(isPresented: $showingExportOptions) {
                DataExportOptionsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingContactOptions) {
                PrivacyContactView()
            }
        }
    }
    
    // MARK: - Data Collection Section
    
    private var dataCollectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("Privacy First")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("SunHat is designed with your privacy in mind. We collect minimal data necessary to provide weather-based reminders.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            // Data Collection Details
            DisclosureGroup("What Data We Collect") {
                VStack(alignment: .leading, spacing: 8) {
                    DataCollectionRow(
                        icon: "thermometer",
                        title: "Weather Preferences",
                        description: "Temperature units, reminder settings, and trigger conditions you configure",
                        dataType: .essential
                    )
                    
                    DataCollectionRow(
                        icon: "location",
                        title: "Location Data",
                        description: "City-level location for weather data (precise location never stored)",
                        dataType: .essential
                    )
                    
                    DataCollectionRow(
                        icon: "bell",
                        title: "Notification Settings",
                        description: "Your notification preferences and quiet hours",
                        dataType: .functional
                    )
                    
                    DataCollectionRow(
                        icon: "icloud",
                        title: "Sync Data",
                        description: "Reminder data synced across your devices via iCloud (when enabled)",
                        dataType: .optional
                    )
                    
                    DataCollectionRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Usage Analytics",
                        description: "Anonymous app usage patterns to improve the experience",
                        dataType: .optional
                    )
                }
                .padding(.vertical, 8)
            }
            
            // Data Storage Summary
            if let summary = viewModel.dataSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Data Summary")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Reminders:")
                        Spacer()
                        Text("\(summary.reminderCount)")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Locations:")
                        Spacer()
                        Text("\(summary.locationCount)")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Weather Records:")
                        Spacer()
                        Text("\(summary.weatherRecordCount)")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Data Size:")
                        Spacer()
                        Text(summary.totalDataSize)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
        } header: {
            Label("Data Collection", systemImage: "doc.text.magnifyingglass")
        } footer: {
            Text("We only collect data necessary to provide weather reminders. You have full control over your data.")
        }
    }
    
    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            // Storage Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Storage")
                        .font(.body)
                        .fontWeight(.medium)

                    Text(viewModel.syncStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "internaldrive.fill")
                    .foregroundColor(.blue)
            }

            // Storage Information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Local Storage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Data is stored securely on this device")
                    Text("• No data is shared with external servers")
                    Text("• Full control over your information")
                    Text("• iCloud sync coming in a future update")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)

        } header: {
            Label("Data Storage", systemImage: "internaldrive")
        } footer: {
            Text("Your data is currently stored locally on this device. iCloud sync will be available in a future update.")
        }
    }
    
    // MARK: - Data Export Section
    
    private var dataExportSection: some View {
        Section {
            Button("Export My Data") {
                showingExportOptions = true
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Export Includes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• All your weather reminders and settings")
                    Text("• Location data and preferences")
                    Text("• Notification settings and history")
                    Text("• App preferences and customizations")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
            
        } header: {
            Label("Data Export", systemImage: "square.and.arrow.up")
        } footer: {
            Text("Export your data in a machine-readable format (JSON). This includes all personal data we store about you.")
        }
    }
    
    // MARK: - Data Deletion Section
    
    private var dataDeletionSection: some View {
        Section {
            Button("Delete All My Data", role: .destructive) {
                showingDeleteConfirmation = true
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("This Will Delete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• All weather reminders and triggers")
                    Text("• Location data and preferences")
                    Text("• Notification settings and history")
                    Text("• Weather data cache")
                    Text("• iCloud synced data (if enabled)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
            
        } header: {
            Label("Data Deletion", systemImage: "trash")
        } footer: {
            Text("Permanently delete all your data from this device and iCloud. This action cannot be undone.")
        }
    }
    
    // MARK: - Weather Data Sources Section
    
    private var weatherDataSourcesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                WeatherSourceCard(
                    name: "Apple WeatherKit",
                    description: "Primary weather data source",
                    privacyPolicy: "https://developer.apple.com/weatherkit/",
                    dataShared: "Location (city-level only)",
                    isPrimary: true
                )
                
                WeatherSourceCard(
                    name: "OpenWeatherMap",
                    description: "Backup weather data source",
                    privacyPolicy: "https://openweathermap.org/privacy-policy",
                    dataShared: "Location (coordinates)",
                    isPrimary: false
                )
            }
            
        } header: {
            Label("Weather Data Sources", systemImage: "cloud.sun")
        } footer: {
            Text("We use these third-party services to provide accurate weather data. Only necessary location information is shared.")
        }
    }
    
    // MARK: - Third-Party Services Section
    
    private var thirdPartyServicesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ThirdPartyServiceCard(
                    name: "Apple CloudKit",
                    purpose: "Data synchronization across devices",
                    dataShared: "Reminder data, preferences (encrypted)",
                    privacyPolicy: "https://www.apple.com/legal/privacy/"
                )
                
                ThirdPartyServiceCard(
                    name: "Apple Core Location",
                    purpose: "Location services for weather data",
                    dataShared: "City-level location only",
                    privacyPolicy: "https://www.apple.com/legal/privacy/"
                )
                
                ThirdPartyServiceCard(
                    name: "Apple UserNotifications",
                    purpose: "Weather reminder notifications",
                    dataShared: "Notification content (local only)",
                    privacyPolicy: "https://www.apple.com/legal/privacy/"
                )
            }
            
        } header: {
            Label("Third-Party Services", systemImage: "building.2")
        } footer: {
            Text("These Apple services are integrated into iOS and follow Apple's privacy policies.")
        }
    }
    
    // MARK: - Privacy Rights Section
    
    private var privacyRightsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                PrivacyRightCard(
                    title: "Right to Access",
                    description: "View and export all data we have about you",
                    regulation: "GDPR Art. 15, CCPA",
                    action: "Export Data"
                ) {
                    showingExportOptions = true
                }
                
                PrivacyRightCard(
                    title: "Right to Deletion",
                    description: "Request deletion of all your personal data",
                    regulation: "GDPR Art. 17, CCPA",
                    action: "Delete All Data"
                ) {
                    showingDeleteConfirmation = true
                }
                
                PrivacyRightCard(
                    title: "Right to Portability",
                    description: "Receive your data in a machine-readable format",
                    regulation: "GDPR Art. 20",
                    action: "Export as JSON"
                ) {
                    Task {
                        await viewModel.exportDataAsJSON()
                    }
                }
                
                PrivacyRightCard(
                    title: "Right to Rectification",
                    description: "Correct or update your personal information",
                    regulation: "GDPR Art. 16",
                    action: "Contact Support"
                ) {
                    showingContactOptions = true
                }
            }
            
        } header: {
            Label("Your Privacy Rights", systemImage: "hand.raised")
        } footer: {
            Text("Under GDPR and CCPA, you have specific rights regarding your personal data. We're committed to honoring these rights.")
        }
    }
    
    // MARK: - Contact Section
    
    private var contactSection: some View {
        Section {
            Button("Privacy Policy") {
                showingPrivacyPolicy = true
            }
            
            Button("Contact Privacy Officer") {
                showingContactOptions = true
            }
            
            HStack {
                Text("Data Protection Officer")
                Spacer()
                Text("placeholder@example.com") // TODO: Replace with actual privacy email
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .onTapGesture {
                viewModel.contactPrivacyOfficer()
            }
            
            HStack {
                Text("Response Time")
                Spacer()
                Text("Within 30 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        } header: {
            Label("Privacy Support", systemImage: "questionmark.circle")
        } footer: {
            Text("For privacy-related questions or to exercise your rights, contact our Data Protection Officer. We respond to all requests within 30 days as required by law.")
        }
    }
}

// MARK: - Supporting Views

struct DataCollectionRow: View {
    let icon: String
    let title: String
    let description: String
    let dataType: DataCollectionType
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(dataType.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(dataType.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(dataType.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(dataType.color.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WeatherSourceCard: View {
    let name: String
    let description: String
    let privacyPolicy: String
    let dataShared: String
    let isPrimary: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isPrimary {
                    Text("Primary")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Data Shared:")
                Text(dataShared)
                    .fontWeight(.medium)
            }
            .font(.caption)
            
            Button("View Privacy Policy") {
                if let url = URL(string: privacyPolicy) {
                    Task { @MainActor in
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct ThirdPartyServiceCard: View {
    let name: String
    let purpose: String
    let dataShared: String
    let privacyPolicy: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Purpose: \(purpose)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Data Shared: \(dataShared)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Privacy Policy") {
                if let url = URL(string: privacyPolicy) {
                    Task { @MainActor in
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct PrivacyRightCard: View {
    let title: String
    let description: String
    let regulation: String
    let action: String
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(regulation)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action) {
                onAction()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Types

enum DataCollectionType {
    case essential
    case functional
    case optional
    
    var displayName: String {
        switch self {
        case .essential:
            return "Essential"
        case .functional:
            return "Functional"
        case .optional:
            return "Optional"
        }
    }
    
    var color: Color {
        switch self {
        case .essential:
            return .red
        case .functional:
            return .orange
        case .optional:
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    DataPrivacyView()
        .modelContainer(for: [
            UserPreferences.self,
            WeatherReminder.self,
            WeatherData.self,
            LocationData.self
        ], inMemory: true)
}
