//
//  StreamlinedCurrentWeatherSection.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// Live current-conditions row for the selected location, nested inside the
/// "Location" card in the streamlined reminder creator. Shows loading and
/// unavailable states, never fabricated values.
struct StreamlinedCurrentWeatherSection: View {
    @ObservedObject var viewModel: FirstReminderCreationViewModel

    var body: some View {
        Group {
            if viewModel.hasCurrentWeather {
                currentWeatherRow
            } else if viewModel.isLoadingCurrentWeather {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Updating weather…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minHeight: 44)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "cloud.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Weather unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") { viewModel.loadWeather() }
                        .font(.subheadline)
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.customReminder.selectedColor)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private var currentWeatherRow: some View {
        HStack(spacing: 16) {
            Image(systemName: viewModel.currentConditionIcon)
                .font(.title2)
                .foregroundStyle(viewModel.currentConditionColor)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.currentTemperatureText)°")
                    .font(.title3)
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
