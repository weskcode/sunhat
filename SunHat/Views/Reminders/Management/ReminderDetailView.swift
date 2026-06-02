//
//  ReminderDetailView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct ReminderDetailView: View {
    let reminder: WeatherReminder

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    statusSection
                    triggerConditionSection
                    statisticsSection
                    timelineSection
                }
                .padding()
            }
            .navigationTitle("Reminder Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: reminder.category.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(reminder.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            Text(reminder.displayTitle)
                .font(.title)
                .fontWeight(.bold)

            if !reminder.reminderDescription.isEmpty {
                Text(reminder.reminderDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)

            HStack {
                Circle()
                    .fill(reminder.isCurrentlyActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(reminder.statusText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }

    @ViewBuilder
    private var triggerConditionSection: some View {
        if let condition = reminder.triggerCondition {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger Condition")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("Temperature: \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°F")
                            .font(.subheadline)
                    }

                    if condition.useFeelsLike {
                        Text("Uses 'feels like' temperature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Times Triggered", value: "\(reminder.triggerCount)")
                StatCard(title: "Completed", value: "\(reminder.successfulCompletions)")
                StatCard(title: "Skipped", value: "\(reminder.skippedCount)")
                StatCard(title: "Notifications", value: "\(reminder.totalNotificationsSent)")
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                DateRow(label: "Created", date: reminder.createdDate)
                DateRow(label: "Last Modified", date: reminder.lastModified)

                if let lastTriggered = reminder.lastTriggered {
                    DateRow(label: "Last Triggered", date: lastTriggered)
                }

                if let completedDate = reminder.completedDate {
                    DateRow(label: "Completed", date: completedDate)
                }
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}

private struct DateRow: View {
    let label: String
    let date: Date

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(date, format: .dateTime.weekday().month().day().hour().minute())
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
