//
//  ReadOnlyTriggerConditionsView.swift
//  SunHat
//

import SwiftUI

struct ReadOnlyTriggerConditionsView: View {
    let condition: TriggerCondition?
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let condition = condition {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .font(.title3)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temperature \(condition.comparisonType.displayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(Int(displayTemperature(condition.targetTemperature)))°\(temperatureUnit.symbol.dropFirst())")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    if condition.useFeelsLike {
                        VStack {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.blue)

                            Text("Feels Like")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }

                if condition.triggerType == .temperatureRange,
                   let min = condition.minTemperature,
                   let max = condition.maxTemperature {

                    HStack {
                        Text("Range:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(Int(displayTemperature(min)))° - \(Int(displayTemperature(max)))°")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                if condition.temperatureTolerance > 0 {
                    HStack {
                        Text("Tolerance:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("±\(Int(condition.temperatureTolerance))°")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            } else {
                Text("No trigger condition set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(.orange.opacity(0.05)), in: .rect(cornerRadius: 10))
    }

    private func displayTemperature(_ fahrenheit: Double) -> Double {
        switch temperatureUnit {
        case .fahrenheit:
            return fahrenheit
        case .celsius:
            return (fahrenheit - 32) * 5 / 9
        }
    }
}
