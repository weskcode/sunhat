//
//  StreamlinedCurrentWeatherSection.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// The "Current Conditions" card in the streamlined reminder creator —
/// live weather for the selected location with loading and unavailable states.
struct StreamlinedCurrentWeatherSection: View {
    @ObservedObject var viewModel: FirstReminderCreationViewModel

    var body: some View {
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
                    currentWeatherRow
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
            .liquidGlassFieldBackground(tint: viewModel.customReminder.selectedColor)
        }
    }

    private var currentWeatherRow: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current conditions: \(viewModel.currentTemperatureText) degrees, \(viewModel.currentConditionText), feels like \(viewModel.feelsLikeText) degrees"
        )
    }
}
