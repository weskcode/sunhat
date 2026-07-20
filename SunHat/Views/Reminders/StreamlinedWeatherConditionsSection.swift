//
//  StreamlinedWeatherConditionsSection.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// The "Weather Conditions" card in the streamlined reminder creator —
/// temperature condition type, range/exact sliders, and multi-select sky
/// conditions with include/exclude mode.
struct StreamlinedWeatherConditionsSection: View {
    @ObservedObject var viewModel: FirstReminderCreationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(icon: "thermometer.medium", title: "Weather Conditions")

            // Temperature section
            VStack(alignment: .leading, spacing: 12) {
                Picker("Condition Type", selection: $viewModel.customReminder.temperatureType) {
                    ForEach(TemperatureConditionType.allCases, id: \.self) { type in
                        Text(type == .temperatureRange ? "Range" : "Exact").tag(type)
                    }
                }
                .pickerStyle(.segmented)

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
        .cardStyle()
    }

    // MARK: - Sky Conditions

    private var skyConditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sky Conditions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Picker("Condition Mode", selection: $viewModel.customReminder.conditionMode) {
                Text("Include").tag(ConditionSelectionMode.include)
                Text("Exclude").tag(ConditionSelectionMode.exclude)
            }
            .pickerStyle(.segmented)

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
            let isExcluded = isSelected && viewModel.customReminder.conditionMode == .exclude

            HStack(spacing: 6) {
                Image(systemName: sky.icon)
                    .font(.caption)
                    .foregroundStyle(isSelected && !isExcluded ? .white : sky.color)

                Text(sky.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected && !isExcluded ? .white : .primary)
                    .strikethrough(isExcluded, pattern: .solid, color: .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isExcluded
                            ? Color(.tertiarySystemBackground)
                            : (isSelected ? sky.color.opacity(0.85) : Color(.tertiarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isExcluded ? Color.secondary.opacity(0.4) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sky.displayName), \(viewModel.customReminder.selectedSkyConditions.contains(sky) ? "selected" : "not selected")")
    }

    // MARK: - Temperature Controls

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
