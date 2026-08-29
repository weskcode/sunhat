//
//  StreamlinedReminderCreationView.swift
//  SunHat
//
//  Created by Wesley Keetch on 2/12/26.
//  Enhanced with mockup feedback: multi-select sky conditions, time preferences, current weather
//

import SwiftUI
import SwiftData
import CoreLocation

struct StreamlinedReminderCreationView: View {
    @StateObject private var viewModel = FirstReminderCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onReminderCreated: (() -> Void)?

    @State private var showLocationPicker = false
    @State private var didCreateReminder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ReminderIconColorPicker(
                        selectedIcon: $viewModel.customReminder.selectedIcon,
                        selectedColor: $viewModel.customReminder.selectedColor
                    )
                    .padding(.top, 12)

                    detailsCard
                    locationCard
                    StreamlinedWeatherConditionsSection(viewModel: viewModel)
                    StreamlinedTimePreferencesSection(viewModel: viewModel)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .scrollIndicators(.hidden)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createReminder)
                        .fontWeight(.semibold)
                        .disabled(!viewModel.isReminderValid)
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            ManualLocationEntryView(
                isPresented: $showLocationPicker,
                onLocationSelected: { location in
                    viewModel.selectManualLocation(location)
                },
                onUseCurrentLocation: locationPermissionGranted ? {
                    viewModel.selectCurrentLocation()
                    showLocationPicker = false
                } : nil
            )
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.initializeDefaultLocation()
            viewModel.loadWeather()
        }
        .onChange(of: viewModel.customReminder.title) { _, newTitle in
            viewModel.applyActivityDefaults(from: newTitle)
        }
        .sensoryFeedback(.success, trigger: didCreateReminder) { _, newValue in
            newValue
        }
        .alert(
            "Couldn't Save",
            isPresented: Binding(
                get: { viewModel.creationErrorMessage != nil },
                set: { if !$0 { viewModel.creationErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.creationErrorMessage ?? "")
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeaderView(icon: "square.and.pencil", title: "Details")
                .padding(.bottom, 8)

            TextField("Title", text: $viewModel.customReminder.title)
                .font(.body)
                .padding(.vertical, 10)
                .accessibilityLabel("Reminder title")

            Divider()

            TextField("Notes (optional)", text: $viewModel.customReminder.notes, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .padding(.vertical, 10)
                .accessibilityLabel("Reminder notes")
        }
        .cardStyle()
    }

    // MARK: - Location Card

    private var locationPermissionGranted: Bool {
        let status = LocationPermissionManager.shared.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeaderView(icon: "location.fill", title: "Location")
                .padding(.bottom, 8)

            Button(action: { showLocationPicker = true }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.customReminder.locationDisplayName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if viewModel.customReminder.selectedLocation.isCurrentLocation {
                            Text("Uses your device location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select location, currently \(viewModel.customReminder.locationDisplayName)")
            .accessibilityHint("Double tap to change location")

            Divider()

            StreamlinedCurrentWeatherSection(viewModel: viewModel)
                .padding(.vertical, 10)
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func createReminder() {
        guard viewModel.createReminder() else { return }

        didCreateReminder = true
        onReminderCreated?()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    StreamlinedReminderCreationView()
}

#Preview("Dark Mode") {
    StreamlinedReminderCreationView()
        .preferredColorScheme(.dark)
}
