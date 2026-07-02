//
//  StreamlinedWeatherConditionsSection.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// The "Weather" card in the streamlined reminder creator — temperature
/// condition type, range/exact sliders, and multi-select sky conditions
/// with include/exclude mode.
struct StreamlinedWeatherConditionsSection: View {
    @ObservedObject var viewModel: FirstReminderCreationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
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
            .liquidGlassFieldBackground(tint: viewModel.customReminder.selectedColor)
        }
    }

    // MARK: - Sky Conditions

    private var skyConditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sky Conditions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Include/Exclude toggle
            HStack(spacing: 8) {
                conditionModeButton(
                    mode: .include,
                    title: "Include",
                    icon: "checkmark.circle.fill",
                    selectedFill: viewModel.customReminder.selectedColor
                )

                conditionModeButton(
                    mode: .exclude,
                    title: "Exclude",
                    icon: "xmark.circle.fill",
                    selectedFill: .gray // softer than red for negative states
                )
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

    private func conditionModeButton(
        mode: ConditionSelectionMode,
        title: String,
        icon: String,
        selectedFill: Color
    ) -> some View {
        Button {
            withAnimation(selectionAnimation) {
                viewModel.customReminder.conditionMode = mode
            }
        } label: {
            let isSelected = viewModel.customReminder.conditionMode == mode

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(isSelected ? selectedFill : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.customReminder.conditionMode == mode ? .isSelected : [])
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
                        .foregroundStyle(.gray)
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
                               : Color.gray.opacity(0.15))
                            : Color(.tertiarySystemBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected
                                    ? (viewModel.customReminder.conditionMode == .include
                                       ? Color.clear
                                       : Color.gray.opacity(0.4))
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sky.displayName), \(viewModel.customReminder.selectedSkyConditions.contains(sky) ? "selected" : "not selected")")
    }

    // MARK: - Temperature Controls

    private var conditionTypeSelector: some View {
        HStack(spacing: 10) {
            ForEach(TemperatureConditionType.allCases, id: \.self) { type in
                Button {
                    withAnimation(selectionAnimation) {
                        viewModel.customReminder.temperatureType = type
                    }
                } label: {
                    SelectableTileLabel(
                        icon: type.icon,
                        title: type == .temperatureRange ? "Range" : "Exact",
                        isSelected: viewModel.customReminder.temperatureType == type,
                        tint: viewModel.customReminder.selectedColor
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.customReminder.temperatureType == type ? .isSelected : [])
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

    private var selectionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : .smooth(duration: 0.2)
    }
}
