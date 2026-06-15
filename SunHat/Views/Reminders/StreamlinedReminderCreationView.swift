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

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(AppFontStyle.title2.font)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    VStack(spacing: 24) {
                        iconHeaderView
                            .padding(.top, 12)

                        Text("New Task")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        // Form fields
                        VStack(spacing: 20) {
                            titleField

                            notesField

                            locationSelectorRow

                            StreamlinedCurrentWeatherSection(viewModel: viewModel)

                            StreamlinedWeatherConditionsSection(viewModel: viewModel)

                            StreamlinedTimePreferencesSection(viewModel: viewModel)
                        }
                        .padding(.horizontal, 20)

                        // Create button (no preview step)
                        createButton
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                }
            }
            .scrollIndicators(.hidden)
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

    // MARK: - Icon Header

    private var iconHeaderView: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.customReminder.selectedIcon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(viewModel.customReminder.selectedColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 76, height: 76)
                .glassEffect(.regular.tint(viewModel.customReminder.selectedColor.opacity(0.16)), in: .circle)
                .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
        }
    }

    // MARK: - Form Fields

    private var titleField: some View {
        TextField("Reminder Title", text: $viewModel.customReminder.title)
            .font(.body)
            .padding(16)
            .liquidGlassFieldBackground(tint: viewModel.customReminder.selectedColor)
            .accessibilityLabel("Reminder title")
    }

    private var notesField: some View {
        TextField("Notes (optional)", text: $viewModel.customReminder.notes, axis: .vertical)
            .font(.body)
            .lineLimit(2...4)
            .padding(16)
            .liquidGlassFieldBackground(tint: viewModel.customReminder.selectedColor)
            .accessibilityLabel("Reminder notes")
    }

    // MARK: - Location Selector

    private var locationPermissionGranted: Bool {
        let status = LocationPermissionManager.shared.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private var locationSelectorRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            Button(action: { showLocationPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.customReminder.selectedLocation.isCurrentLocation
                          ? "location.fill" : "mappin.and.ellipse")
                        .font(.body)
                        .foregroundStyle(viewModel.customReminder.selectedColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.customReminder.locationDisplayName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if viewModel.customReminder.selectedLocation.isCurrentLocation {
                            Text("Uses your device location")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .liquidGlassFieldBackground(tint: viewModel.customReminder.selectedColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select location, currently \(viewModel.customReminder.locationDisplayName)")
            .accessibilityHint("Double tap to change location")
        }
    }

    // MARK: - Create Button (no preview step per feedback)

    private var createButton: some View {
        Button("Create", systemImage: "plus.circle.fill", action: createReminder)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(viewModel.customReminder.selectedColor)
        .disabled(!viewModel.isReminderValid)
        .opacity(viewModel.isReminderValid ? 1.0 : 0.5)
    }

    // MARK: - Actions

    private func createReminder() {
        guard viewModel.createReminder() else { return }

        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)

        onReminderCreated?()
        dismiss()
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
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
