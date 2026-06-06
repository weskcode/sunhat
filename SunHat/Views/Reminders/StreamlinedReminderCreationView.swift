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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onReminderCreated: (() -> Void)?

    @State private var showLocationPicker = false

    var body: some View {
        ZStack {
            // Background with subtle gradient
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
                            // Title field
                            titleField

                            // Notes field
                            notesField

                            // Location selector
                            locationSelectorRow

                            // Current weather conditions (moved to top per feedback)
                            currentWeatherSection

                            // Weather conditions section (with multi-select sky conditions)
                            weatherConditionsSection

                            // Time preferences section
                            timePreferencesSection
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
        VStack(alignment: .leading, spacing: 0) {
            TextField("Reminder Title", text: $viewModel.customReminder.title)
                .font(.body)
                .padding(16)
                .background(liquidGlassBackground)
                .accessibilityLabel("Reminder title")
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Notes (optional)", text: $viewModel.customReminder.notes, axis: .vertical)
                .font(.body)
                .lineLimit(2...4)
                .padding(16)
                .background(liquidGlassBackground)
                .accessibilityLabel("Reminder notes")
        }
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
                .background(liquidGlassBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select location, currently \(viewModel.customReminder.locationDisplayName)")
            .accessibilityHint("Double tap to change location")
        }
    }

    // MARK: - Current Weather Section (moved to top per feedback)

    private var currentWeatherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(viewModel.customReminder.selectedColor)

                Text(viewModel.customReminder.locationDisplayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)

            // Real current weather for the selected location.
            Group {
                if viewModel.hasCurrentWeather {
                    HStack(spacing: 16) {
                        Image(systemName: viewModel.currentConditionIcon)
                            .font(.title)
                            .foregroundStyle(viewModel.currentConditionColor)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.currentTemperatureText)°")
                                .font(AppFontStyle.title2.font)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())

                            Text(viewModel.currentConditionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Feels like \(viewModel.feelsLikeText)°")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.customReminder.selectedColor)
                                    .frame(width: 6, height: 6)

                                Text("Monitoring")
                                    .font(.caption2)
                                    .foregroundStyle(viewModel.customReminder.selectedColor)
                            }
                        }
                    }
                } else if viewModel.isLoadingCurrentWeather {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Updating weather…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.slash")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Weather unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(liquidGlassBackground)
        }
    }

    // MARK: - Weather Conditions Section (with multi-select sky conditions)

    private var weatherConditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "thermometer.medium")
                    .font(.body)
                    .foregroundStyle(viewModel.customReminder.selectedColor)

                Text("Weather")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 20) {
                // Temperature section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Condition Type")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    conditionTypeSelector

                    if viewModel.customReminder.temperatureType == .temperatureRange {
                        temperatureRangeControl
                    } else {
                        exactTemperatureControl
                    }
                }

                Divider()

                // Sky conditions (multi-select with include/exclude)
                skyConditionsSection
            }
            .padding(16)
            .background(liquidGlassBackground)
        }
    }

    private var skyConditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sky Conditions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Include/Exclude toggle
            HStack(spacing: 8) {
                Button {
                    withAnimation(selectionAnimation) {
                        viewModel.customReminder.conditionMode = .include
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Include")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(viewModel.customReminder.conditionMode == .include ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        viewModel.customReminder.conditionMode == .include
                            ? viewModel.customReminder.selectedColor
                            : Color(.tertiarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(selectionAnimation) {
                        viewModel.customReminder.conditionMode = .exclude
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Exclude")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(viewModel.customReminder.conditionMode == .exclude ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        viewModel.customReminder.conditionMode == .exclude
                            ? Color.gray  // Changed from red to grey per feedback
                            : Color(.tertiarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.customReminder.conditionMode == .include
                 ? "Remind me when it's any of these:"
                 : "Remind me unless it's any of these:")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Sky condition chips
            FlowLayoutConditions(spacing: 8) {
                ForEach(SkyCondition.allCases) { sky in
                    skyConditionChip(for: sky)
                }
            }
        }
    }

    private func skyConditionChip(for sky: SkyCondition) -> some View {
        Button {
            withAnimation(selectionAnimation) {
                if viewModel.customReminder.selectedSkyConditions.contains(sky) {
                    viewModel.customReminder.selectedSkyConditions.remove(sky)
                } else {
                    viewModel.customReminder.selectedSkyConditions.insert(sky)
                }
            }

            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            let isSelected = viewModel.customReminder.selectedSkyConditions.contains(sky)

            HStack(spacing: 6) {
                Image(systemName: sky.icon)
                    .font(.caption)
                    .foregroundStyle(
                        isSelected && viewModel.customReminder.conditionMode == .include
                            ? .white
                            : sky.color
                    )

                Text(sky.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        isSelected
                            ? (viewModel.customReminder.conditionMode == .include ? .white : .primary)
                            : .primary
                    )

                if isSelected && viewModel.customReminder.conditionMode == .exclude {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.gray)  // Changed from red to grey
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? (viewModel.customReminder.conditionMode == .include
                               ? sky.color.opacity(0.85)
                               : Color.gray.opacity(0.15))  // Changed from red to grey
                            : Color(.tertiarySystemBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected
                                    ? (viewModel.customReminder.conditionMode == .include
                                       ? Color.clear
                                       : Color.gray.opacity(0.4))  // Changed from red to grey
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sky.displayName), \(viewModel.customReminder.selectedSkyConditions.contains(sky) ? "selected" : "not selected")")
    }

    private var conditionTypeSelector: some View {
        HStack(spacing: 10) {
            ForEach(TemperatureConditionType.allCases, id: \.self) { type in
                Button {
                    withAnimation(selectionAnimation) {
                        viewModel.customReminder.temperatureType = type
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.body)

                        Text(type == .temperatureRange ? "Range" : "Exact")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(
                        viewModel.customReminder.temperatureType == type
                            ? .white
                            : .primary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                viewModel.customReminder.temperatureType == type
                                    ? LinearGradient(
                                        colors: [
                                            viewModel.customReminder.selectedColor.opacity(0.9),
                                            viewModel.customReminder.selectedColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color(.tertiarySystemBackground),
                                            Color(.tertiarySystemBackground)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.customReminder.temperatureType == type
                                            ? Color.white.opacity(0.3)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var temperatureRangeControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Range")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(viewModel.customReminder.minTemperature))° - \(Int(viewModel.customReminder.maxTemperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.customReminder.selectedColor)
            }

            TemperatureRangeSlider(
                minTemp: $viewModel.customReminder.minTemperature,
                maxTemp: $viewModel.customReminder.maxTemperature
            )
        }
    }

    private var exactTemperatureControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(viewModel.customReminder.minTemperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.customReminder.selectedColor)
            }

            SingleTemperatureSlider(temperature: $viewModel.customReminder.minTemperature)
        }
    }

    // MARK: - Time Preferences Section

    private var timePreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.body)
                    .foregroundStyle(viewModel.customReminder.selectedColor)

                Text("Time")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 16) {
                // Time range selector
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(TimeRange.allCases, id: \.self) { timeRange in
                        timeRangeButton(for: timeRange)
                    }
                }

                // Quiet hours toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Respect Quiet Hours")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Avoid notifications during sleep")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.customReminder.respectQuietHours)
                        .labelsHidden()
                }
            }
            .padding(16)
            .background(liquidGlassBackground)
        }
    }

    private func timeRangeButton(for timeRange: TimeRange) -> some View {
        Button {
            withAnimation(selectionAnimation) {
                viewModel.customReminder.preferredTimeRange = timeRange
            }

            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: timeRange.icon)
                    .font(.body)
                    .foregroundStyle(
                        viewModel.customReminder.preferredTimeRange == timeRange
                            ? .white
                            : viewModel.customReminder.selectedColor
                    )

                Text(timeRange.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        viewModel.customReminder.preferredTimeRange == timeRange
                            ? .white
                            : .primary
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        viewModel.customReminder.preferredTimeRange == timeRange
                            ? LinearGradient(
                                colors: [
                                    viewModel.customReminder.selectedColor.opacity(0.9),
                                    viewModel.customReminder.selectedColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color(.tertiarySystemBackground),
                                    Color(.tertiarySystemBackground)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                viewModel.customReminder.preferredTimeRange == timeRange
                                    ? Color.white.opacity(0.3)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timeRange.displayName)
        .accessibilityAddTraits(viewModel.customReminder.preferredTimeRange == timeRange ? .isSelected : [])
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
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)

        viewModel.createReminder()

        onReminderCreated?()
        dismiss()
    }

    // MARK: - Liquid Glass Background

    private var liquidGlassBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.clear)
            .glassEffect(.regular.tint(viewModel.customReminder.selectedColor.opacity(0.05)), in: .rect(cornerRadius: 16))
    }

    private var selectionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : .smooth(duration: 0.2)
    }

    // MARK: - Computed Properties

    private var backgroundGradient: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(red: 0.97, green: 0.98, blue: 1.0))
                .ignoresSafeArea()

        }
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
