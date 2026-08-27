//
//  TemperatureSliders.swift
//  SunHat
//

import SwiftUI

struct TemperatureRangeSlider: View {
    @Binding var minTemp: Double
    @Binding var maxTemp: Double

    var body: some View {
        VStack(spacing: 16) {
            temperatureControl(
                title: "Minimum",
                value: $minTemp,
                range: 32...100
            )
            .onChange(of: minTemp) { _, newValue in
                if maxTemp < newValue { maxTemp = newValue }
            }

            temperatureControl(
                title: "Maximum",
                value: $maxTemp,
                range: 32...100
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
                Text("\(Int(value.wrappedValue))°F")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }

            Slider(value: value, in: range, step: 1)
                .tint(Color.accentColor)
                .accessibilityLabel("\(title) temperature")
                .accessibilityValue("\(Int(value.wrappedValue)) degrees Fahrenheit")
        }
    }
}

struct SingleTemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("32°F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(temperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Spacer()

                Text("100°F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $temperature, in: 32...100, step: 1)
                .tint(Color.accentColor)
        }
    }
}
