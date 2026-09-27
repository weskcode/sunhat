//
//  ReminderGlassCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import SwiftUI

struct ReminderGlassCard: View {
    let reminder: WeatherReminder
    let temperatureUnit: TemperatureUnit

    var body: some View {
        NavigationLink {
            DetailedReminderView(reminder: reminder)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: reminder.displayIconName)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(reminder.displayTint ?? Color.accentColor)
                        .frame(width: 24)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(reminder.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(reminder.isCurrentlyActive ? "Active" : "Paused")
                        .font(.subheadline)
                        .foregroundStyle(reminder.isCurrentlyActive ? .green : .secondary)
                }

                if let condition = reminder.triggerCondition {
                    HStack(spacing: 8) {
                        temperatureConditionText(condition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Text(reminder.createdDate, format: .dateTime.month().day())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens task details.")
    }

    @ViewBuilder
    private func temperatureConditionText(_ condition: TriggerCondition) -> some View {
        if condition.comparisonType == .between,
           let minTemperature = condition.minTemperature,
           let maxTemperature = condition.maxTemperature {
            Text("When temperature is between \(temperatureUnit.roundedFromFahrenheit(minTemperature))° and \(temperatureUnit.roundedFromFahrenheit(maxTemperature))°", comment: "Reminder card temperature trigger description for a between-range condition, e.g. 'When temperature is between 65° and 97°'")
        } else {
            Text("When temperature is \(condition.comparisonType.displayName) \(temperatureUnit.roundedFromFahrenheit(condition.targetTemperature))°")
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            reminder.displayTitle,
            reminder.isCurrentlyActive
                ? String(localized: "Active", comment: "Accessibility label clause: the reminder is active")
                : String(localized: "Paused", comment: "Accessibility label clause: the reminder is paused")
        ]

        if !reminder.reminderDescription.isEmpty {
            parts.append(reminder.reminderDescription)
        }

        if let condition = reminder.triggerCondition {
            if condition.comparisonType == .between,
               let minTemperature = condition.minTemperature,
               let maxTemperature = condition.maxTemperature {
                parts.append(String(localized: "When temperature is between \(temperatureUnit.roundedFromFahrenheit(minTemperature)) and \(temperatureUnit.roundedFromFahrenheit(maxTemperature)) degrees", comment: "Accessibility label clause describing a reminder's between-range temperature trigger condition"))
            } else {
                parts.append(String(localized: "When temperature is \(condition.comparisonType.displayName) \(temperatureUnit.roundedFromFahrenheit(condition.targetTemperature)) degrees", comment: "Accessibility label clause describing a reminder's temperature trigger condition"))
            }
        }

        return parts.joined(separator: ", ")
    }
}
