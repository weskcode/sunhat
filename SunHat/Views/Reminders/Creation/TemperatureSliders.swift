//
//  TemperatureSliders.swift
//  SunHat
//

import SwiftUI

/// The slider bounds below are the same physical range (freezing to 100°F)
/// expressed in each unit, so switching units never changes what's reachable.
private let fahrenheitBounds: ClosedRange<Double> = 32...100
private let celsiusBounds: ClosedRange<Double> = 0...38

struct TemperatureRangeSlider: View {
    /// Canonical Fahrenheit, matching `TriggerCondition`'s storage unit.
    @Binding var minTemp: Double
    @Binding var maxTemp: Double
    let temperatureUnit: TemperatureUnit

    private var range: ClosedRange<Double> {
        temperatureUnit == .fahrenheit ? fahrenheitBounds : celsiusBounds
    }

    private var minTempInUnit: Binding<Double> {
        Binding(
            get: { temperatureUnit.fromFahrenheit(minTemp) },
            set: { minTemp = temperatureUnit.toFahrenheit($0) }
        )
    }

    private var maxTempInUnit: Binding<Double> {
        Binding(
            get: { temperatureUnit.fromFahrenheit(maxTemp) },
            set: { maxTemp = temperatureUnit.toFahrenheit($0) }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            temperatureControl(
                title: String(localized: "Minimum", comment: "Temperature range slider label"),
                value: minTempInUnit,
                range: range
            )
            .onChange(of: minTemp) { _, newValue in
                if maxTemp < newValue { maxTemp = newValue }
            }

            temperatureControl(
                title: String(localized: "Maximum", comment: "Temperature range slider label"),
                value: maxTempInUnit,
                range: range
            )
            .onChange(of: maxTemp) { _, newValue in
                if minTemp > newValue { minTemp = newValue }
            }
        }
    }

    private func temperatureControl(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 8) {
            LabeledContent(title) {
                Text("\(Int(value.wrappedValue))\(temperatureUnit.symbol)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }

            Slider(value: value, in: range, step: 1)
                .tint(Color.accentColor)
                .accessibilityLabel("\(title) temperature")
                .accessibilityValue("\(Int(value.wrappedValue)) degrees \(temperatureUnit.shortName)")
        }
    }
}

struct SingleTemperatureSlider: View {
    /// Canonical Fahrenheit, matching `TriggerCondition`'s storage unit.
    @Binding var temperature: Double
    let temperatureUnit: TemperatureUnit

    private var range: ClosedRange<Double> {
        temperatureUnit == .fahrenheit ? fahrenheitBounds : celsiusBounds
    }

    private var temperatureInUnit: Binding<Double> {
        Binding(
            get: { temperatureUnit.fromFahrenheit(temperature) },
            set: { temperature = temperatureUnit.toFahrenheit($0) }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(Int(range.lowerBound))\(temperatureUnit.symbol)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(temperatureInUnit.wrappedValue))\(temperatureUnit.symbol)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Spacer()

                Text("\(Int(range.upperBound))\(temperatureUnit.symbol)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Slider(value: temperatureInUnit, in: range, step: 1)
                .tint(Color.accentColor)
        }
    }
}
