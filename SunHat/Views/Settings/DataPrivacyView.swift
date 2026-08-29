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
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DataPrivacyViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case exportOptions
        case contactOptions

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            Form {
                overviewSection
                storedDataSection
                dataActionsSection
                weatherProvidersSection
                privacyRightsSection
                privacySupportSection
                deletionSection
            }
            .navigationTitle("Data & Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                viewModel.configure(modelContext: modelContext)
                await viewModel.loadDataSummary()
            }
            .alert(
                "Couldn't Complete Request",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                TextField("Type DELETE to confirm", text: $viewModel.deleteConfirmationText)
                    .textInputAutocapitalization(.characters)

                Button("Delete Everything", role: .destructive) {
                    Task { await viewModel.deleteAllUserData() }
                }
                .disabled(!viewModel.deleteConfirmationValid || viewModel.isDeleting)

                Button("Cancel", role: .cancel) {
                    viewModel.deleteConfirmationText = ""
                }
            } message: {
                Text("This permanently removes your reminders, preferences, saved locations, and cached weather data from this device.")
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .exportOptions:
                    DataExportOptionsView(viewModel: viewModel)
                case .contactOptions:
                    PrivacyContactView()
                }
            }
        }
    }

    private var overviewSection: some View {
        Section {
            Text("SunHat stores your reminders and preferences on this device. Location coordinates are sent to enabled weather providers only when needed to retrieve weather data.")
                .foregroundStyle(.secondary)
        } header: {
            Text("How SunHat Uses Data")
        }
    }

    private var storedDataSection: some View {
        Section("Stored on This Device") {
            if let summary = viewModel.dataSummary {
                LabeledContent("Reminders", value: summary.reminderCount.formatted())
                LabeledContent("Locations", value: summary.locationCount.formatted())
                LabeledContent("Weather records", value: summary.weatherRecordCount.formatted())
                LabeledContent("Estimated size", value: summary.totalDataSize)
            } else {
                HStack {
                    Text("Loading data summary")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var dataActionsSection: some View {
        Section {
            Button("Export My Data", systemImage: "square.and.arrow.up") {
                activeSheet = .exportOptions
            }
        } header: {
            Text("Your Data")
        } footer: {
            Text("Exports include reminders, preferences, locations, notification settings, and reminder history.")
        }
    }

    private var weatherProvidersSection: some View {
        Section("Weather Providers") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple WeatherKit")
                Text("Forecast provider")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacyRightsSection: some View {
        Section {
            privacyRightRow(
                title: "Right to Access",
                description: "View and export all data we have about you",
                regulation: "GDPR Art. 15, CCPA",
                action: "Export Data"
            ) {
                activeSheet = .exportOptions
            }

            privacyRightRow(
                title: "Right to Portability",
                description: "Receive your data in a machine-readable format",
                regulation: "GDPR Art. 20",
                action: "Export as JSON"
            ) {
                Task { await viewModel.exportDataAsJSON() }
            }

            privacyRightRow(
                title: "Right to Rectification",
                description: "Correct or update your personal information",
                regulation: "GDPR Art. 16",
                action: "Contact Support"
            ) {
                activeSheet = .contactOptions
            }

            privacyRightRow(
                title: "Right to Deletion",
                description: "Request deletion of all your personal data",
                regulation: "GDPR Art. 17, CCPA",
                action: "Delete All Data"
            ) {
                showingDeleteConfirmation = true
            }
        } header: {
            Text("Your Privacy Rights")
        } footer: {
            Text("Under GDPR and CCPA, you have specific rights regarding your personal data. We're committed to honoring these rights.")
        }
    }

    private func privacyRightRow(
        title: String,
        description: String,
        regulation: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontWeight(.medium)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(regulation)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button(action, action: perform)
                .font(.subheadline)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var privacySupportSection: some View {
        Section("Privacy Information") {
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }

            Button("Contact About Privacy") {
                activeSheet = .contactOptions
            }
        }
    }

    private var deletionSection: some View {
        Section {
            Button("Delete All Data", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .disabled(viewModel.isDeleting)
        } footer: {
            Text("Deletion cannot be undone. System permission choices remain managed in the Settings app.")
        }
    }
}

#Preview {
    DataPrivacyView()
        .modelContainer(for: [
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self,
            UserPreferences.self,
            SavedLocation.self,
            LocationHistory.self
        ], inMemory: true)
}
