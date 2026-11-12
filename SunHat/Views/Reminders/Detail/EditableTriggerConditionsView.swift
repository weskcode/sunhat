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
                    ForEach(TriggerType.allCases.filter { $0 == .exactTemperature || $0 == .temperatureRange || $0 == condition.triggerType }, id: \.self) { type in
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

                if condition.triggerType == .temperatureRange || condition.comparisonType == .between {
                    TemperatureRangeSlider(minTemp: minimumTemperature, maxTemp: maximumTemperature, temperatureUnit: temperatureUnit)
                } else {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Target Temperature")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(displayTemperature)°\(temperatureUnit.symbol.dropFirst())")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }

                        Slider(
                            value: targetTemperatureInUnit,
                            in: sliderRange,
                            step: 1
                        )
                        .tint(temperatureColor(for: condition.targetTemperature))
                    }

                }

                if condition.triggerType != .temperatureRange {
                    Picker("Comparison", selection: $condition.comparisonType) {
                        ForEach(ComparisonType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }


                Toggle("Use 'feels like' temperature", isOn: $condition.useFeelsLike)
                    .font(.caption)
            }
        }
        .onAppear {
            if condition.triggerType == .temperatureRange || condition.comparisonType == .between { prepareRange() }
        }
        .onChange(of: condition.comparisonType) { _, comparison in
            if comparison == .between { prepareRange() }
        }
        .onChange(of: condition.triggerType) { _, type in
            if type == .temperatureRange {
                prepareRange()
            } else if condition.comparisonType == .between {
                condition.comparisonType = .equals
            }
        }
    }

    private func prepareRange() {
        condition.minTemperature = condition.minTemperature ?? condition.targetTemperature
        condition.maxTemperature = condition.maxTemperature ?? condition.targetTemperature
        condition.comparisonType = .between
    }

    private var minimumTemperature: Binding<Double> {
        Binding(get: { condition.minTemperature ?? condition.targetTemperature }, set: { condition.minTemperature = $0 })
    }

    private var maximumTemperature: Binding<Double> {
        Binding(get: { condition.maxTemperature ?? condition.targetTemperature }, set: { condition.maxTemperature = $0 })
    }

    private var displayTemperature: Int {
        temperatureUnit.roundedFromFahrenheit(condition.targetTemperature)
    }

    private var sliderRange: ClosedRange<Double> {
        TemperatureSliderBounds.range(for: temperatureUnit)
    }

    private var targetTemperatureInUnit: Binding<Double> {
        Binding(
            get: { temperatureUnit.fromFahrenheit(condition.targetTemperature) },
            set: { condition.targetTemperature = temperatureUnit.toFahrenheit($0) }
        )
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
