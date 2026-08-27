//
//  ReminderGlassCard.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct ReminderGlassCard: View {
    let reminder: WeatherReminder

    var body: some View {
        NavigationLink {
            DetailedReminderView(reminder: reminder)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: reminder.category.iconName)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
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
                        Text("When temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°")
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

    private var accessibilityLabel: String {
        var parts = [reminder.displayTitle, reminder.isCurrentlyActive ? "Active" : "Paused"]

        if !reminder.reminderDescription.isEmpty {
            parts.append(reminder.reminderDescription)
        }

        if let condition = reminder.triggerCondition {
            parts.append("When temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature)) degrees")
        }

        return parts.joined(separator: ", ")
    }
}
