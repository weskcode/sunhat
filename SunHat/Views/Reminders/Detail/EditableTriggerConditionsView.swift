//
//  EditableTriggerConditionsView.swift
//  SunHat
//

import SwiftUI

struct EditableTriggerConditionsView: View {
    @Binding var condition: EditableTriggerCondition
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Picker("Trigger Type", selection: $condition.triggerType) {
                    ForEach(TriggerType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Temperature")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    HStack {
                        Text("Target Temperature")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(displayTemperature))°\(temperatureUnit.symbol.dropFirst())")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }

                    Slider(
                        value: $condition.targetTemperature,
                        in: 0...110,
                        step: 1
                    )
                    .tint(temperatureColor(for: condition.targetTemperature))
                }

                Picker("Comparison", selection: $condition.comparisonType) {
                    ForEach(ComparisonType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Use 'feels like' temperature", isOn: $condition.useFeelsLike)
                    .font(.caption)
            }
        }
    }

    private var displayTemperature: Double {
        switch temperatureUnit {
        case .fahrenheit:
            return condition.targetTemperature
        case .celsius:
            return (condition.targetTemperature - 32) * 5 / 9
        }
    }

    private func temperatureColor(for temp: Double) -> Color {
        switch temp {
        case ..<40: return .blue
        case 40..<60: return .cyan
        case 60..<75: return .green
        case 75..<85: return .yellow
        case 85..<95: return .orange
        default: return .red
        }
    }
}
