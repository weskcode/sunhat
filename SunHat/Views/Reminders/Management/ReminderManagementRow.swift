//
//  ReminderManagementRow.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct ReminderManagementRow: View {
    let reminder: WeatherReminder
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: () -> Void
    let onToggleActive: (Bool) -> Void

    @State private var showingDetails = false

    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(.plain)
            }

            Button {
                if isSelectionMode {
                    onToggleSelection()
                } else {
                    showingDetails = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: reminder.category.iconName)
                        .font(.title3)
                        .foregroundColor(reminder.category == .general ? .blue : reminderStatusColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(reminder.displayTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(reminderStatusColor)
                                    .frame(width: 8, height: 8)

                                Text(reminder.statusText)
                                    .font(.caption2)
                                    .foregroundColor(reminderStatusColor)
                            }
                        }

                        Text(reminderDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        HStack {
                            if let condition = reminder.triggerCondition {
                                HStack(spacing: 4) {
                                    Image(systemName: "thermometer")
                                        .font(.caption2)
                                        .foregroundColor(.orange)

                                    Text("\(Int(condition.targetTemperature))° \(condition.comparisonType.rawValue)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }

                            Spacer()

                            Text(dateDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if !isSelectionMode && reminder.canTrigger {
                Toggle("", isOn: .init(
                    get: { reminder.isActive },
                    set: { @Sendable newValue in onToggleActive(newValue) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetails) {
            ReminderDetailView(reminder: reminder)
        }
    }

    private var reminderStatusColor: Color {
        if reminder.isCompleted {
            return .green
        } else if !reminder.isActive {
            return .gray
        } else if reminder.isPaused {
            return .orange
        } else if let snoozedUntil = reminder.snoozedUntil, snoozedUntil > Date() {
            return .blue
        } else {
            return .green
        }
    }

    private var reminderDescription: String {
        if !reminder.reminderDescription.isEmpty {
            return reminder.reminderDescription
        } else if let condition = reminder.triggerCondition {
            return "When temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°"
        } else {
            return "Weather reminder"
        }
    }

    private var dateDescription: String {
        if let lastTriggered = reminder.lastTriggered {
            return "Triggered \(relativeDateFormatter.localizedString(for: lastTriggered, relativeTo: Date()))"
        } else {
            return "Created \(relativeDateFormatter.localizedString(for: reminder.createdDate, relativeTo: Date()))"
        }
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}
