//
//  DashboardComponents.swift
//  SunHat
//
//  Created by Codex on 6/2/26.
//

import SwiftUI

// MARK: - Weather Alert Card

struct WeatherAlertCard: View {
    let alert: WeatherAlertDisplay

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.iconName)
                .font(AppFontStyle.title3.font)
                .foregroundStyle(alert.severityColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(AppFontStyle.subheadline.font)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(alert.description)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .glassEffect(.regular.tint(alert.severityColor.opacity(0.12)), in: .rect(cornerRadius: 10))
    }
}

// MARK: - Active Reminder Card

struct ActiveReminderCard: View {
    let reminder: WeatherReminderDisplay
    let weatherData: WeatherDataTransfer?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.category.iconName)
                .font(AppFontStyle.title3.font)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(AppFontStyle.subheadline.font)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let condition = reminder.triggerCondition {
                    Text("Trigger: When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature, specifier: "%.1f")°")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Trigger: No condition set")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(AppFontStyle.caption2.font)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let weatherData {
                Text("\(weatherData.temperature, specifier: "%.0f")°")
                    .font(AppFontStyle.caption.font)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 10))
    }

    private var statusColor: Color {
        guard weatherData != nil else {
            return .gray
        }

        return .orange
    }

    private var statusText: String {
        guard weatherData != nil else {
            return "Waiting for weather data"
        }

        return "Monitoring"
    }
}

// MARK: - Empty Active Reminders View

struct EmptyActiveRemindersView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Tasks Yet", systemImage: "bell.slash")
        } description: {
            Text("Create a weather task and SunHat will watch for matching conditions.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Refreshable Scroll View

struct RefreshableScrollView<Content: View>: View {
    let onRefresh: () async -> Void
    let content: Content

    @State private var isRefreshing = false

    init(onRefresh: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            isRefreshing = true
            await onRefresh()
            isRefreshing = false
        }
    }
}
