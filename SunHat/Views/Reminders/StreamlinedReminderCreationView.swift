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
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Main content
                    VStack(spacing: 24) {
                        // Animated icon header
                        iconHeaderView
                            .padding(.top, 20)

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
            viewModel.loadWeatherForecast()
        }
        .onChange(of: viewModel.customReminder.title) { _, newTitle in
            viewModel.applyActivityDefaults(from: newTitle)
        }
    }

    // MARK: - Icon Header

    private var iconHeaderView: some View {
        VStack(spacing: 12) {
            // Large circular icon with liquid glass effect
            ZStack {
                // Liquid glass circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                viewModel.customReminder.selectedColor.opacity(0.8),
                                viewModel.customReminder.selectedColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                // Selected icon
                Image(systemName: viewModel.customReminder.selectedIcon)
                    .font(.system(size: 45, weight: .medium))
                    .foregroundColor(.white)
            }
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
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            Button(action: { showLocationPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.customReminder.selectedLocation.isCurrentLocation
                          ? "location.fill" : "mappin.and.ellipse")
                        .font(.body)
                        .foregroundColor(viewModel.customReminder.selectedColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.customReminder.locationDisplayName)
                            .font(.body)
                            .foregroundColor(.primary)

                        if viewModel.customReminder.selectedLocation.isCurrentLocation {
                            Text("Uses your device location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(liquidGlassBackground)
            }
            .buttonStyle(PlainButtonStyle())
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
                    .foregroundColor(viewModel.customReminder.selectedColor)

                Text(viewModel.customReminder.locationDisplayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)

            // Mock current weather display
            HStack(spacing: 16) {
                Image(systemName: "cloud.sun.fill")
                    .font(.title)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("74°")
                        .font(AppFontStyle.title2.font)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Light Rain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Feels like 71°")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Removed "waiting for conditions" - no more "LIVE" spam
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.customReminder.selectedColor)
                            .frame(width: 6, height: 6)

                        Text("Monitoring")
                            .font(.caption2)
                            .foregroundColor(viewModel.customReminder.selectedColor)
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
                    .foregroundColor(viewModel.customReminder.selectedColor)

                Text("Weather")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 20) {
                // Temperature section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Condition Type")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

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
                .foregroundColor(.secondary)

            // Include/Exclude toggle
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
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
                    .foregroundColor(viewModel.customReminder.conditionMode == .include ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        viewModel.customReminder.conditionMode == .include
                            ? viewModel.customReminder.selectedColor
                            : Color(.tertiarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
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
                    .foregroundColor(viewModel.customReminder.conditionMode == .exclude ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        viewModel.customReminder.conditionMode == .exclude
                            ? Color.gray  // Changed from red to grey per feedback
                            : Color(.tertiarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text(viewModel.customReminder.conditionMode == .include
                 ? "Remind me when it's any of these:"
                 : "Remind me unless it's any of these:")
                .font(.caption2)
                .foregroundColor(.secondary)

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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                    .foregroundColor(
                        isSelected && viewModel.customReminder.conditionMode == .include
                            ? .white
                            : sky.color
                    )

                Text(sky.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(
                        isSelected
                            ? (viewModel.customReminder.conditionMode == .include ? .white : .primary)
                            : .primary
                    )

                if isSelected && viewModel.customReminder.conditionMode == .exclude {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)  // Changed from red to grey
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(sky.displayName), \(viewModel.customReminder.selectedSkyConditions.contains(sky) ? "selected" : "not selected")")
    }

    private var conditionTypeSelector: some View {
        HStack(spacing: 10) {
            ForEach(TemperatureConditionType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
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
                    .foregroundColor(
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
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var temperatureRangeControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Range")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(viewModel.customReminder.minTemperature))° - \(Int(viewModel.customReminder.maxTemperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.customReminder.selectedColor)
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
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(viewModel.customReminder.minTemperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.customReminder.selectedColor)
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
                    .foregroundColor(viewModel.customReminder.selectedColor)

                Text("Time")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
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
                            .foregroundColor(.primary)

                        Text("Avoid notifications during sleep")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.customReminder.preferredTimeRange = timeRange
            }

            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: timeRange.icon)
                    .font(.body)
                    .foregroundColor(
                        viewModel.customReminder.preferredTimeRange == timeRange
                            ? .white
                            : viewModel.customReminder.selectedColor
                    )

                Text(timeRange.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(timeRange.displayName)
        .accessibilityAddTraits(viewModel.customReminder.preferredTimeRange == timeRange ? .isSelected : [])
    }

    // MARK: - Create Button (no preview step per feedback)

    private var createButton: some View {
        Button(action: createReminder) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)

                Text("Create")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        viewModel.customReminder.selectedColor.opacity(0.9),
                        viewModel.customReminder.selectedColor
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: viewModel.customReminder.selectedColor.opacity(0.4), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
            .fill(
                colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.white.opacity(0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Computed Properties

    private var backgroundGradient: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(red: 0.97, green: 0.98, blue: 1.0))
                .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    viewModel.customReminder.selectedColor.opacity(colorScheme == .dark ? 0.15 : 0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.1)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(colorScheme == .dark ? 0.1 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.5)
                }
            }
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
