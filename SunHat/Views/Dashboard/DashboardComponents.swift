//
//  DashboardComponents.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/2/26.
//

import SwiftUI

// MARK: - Weather Alert Card

struct WeatherAlertCard: View {
    let alert: WeatherAlertDisplay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shouldReduceMotion = reduceMotion

        HStack(spacing: 12) {
            Image(systemName: alert.iconName)
                .font(AppFontStyle.title3.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(alert.severityColor)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(alert.severityColor.opacity(0.12))
                }
                .accessibilityHidden(true)

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
        .padding(14)
        .sunHatSurface(tint: alert.severityColor, cornerRadius: 16, prominence: 0.55)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.82)
                .scaleEffect(shouldReduceMotion || phase.isIdentity ? 1 : 0.98)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(alert.title), \(alert.description)")
    }
}

// MARK: - Active Reminder Card

struct ActiveReminderCard: View {
    let reminder: WeatherReminderDisplay
    let weatherData: WeatherDataTransfer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shouldReduceMotion = reduceMotion

        HStack(spacing: 14) {
            Image(systemName: reminder.displayIconName)
                .font(AppFontStyle.title3.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(reminder.displayTint ?? Color.accentColor)
                .frame(width: 42, height: 42)
                .background {
                    Circle()
                        .fill((reminder.displayTint ?? Color.accentColor).opacity(0.12))
                        .overlay {
                            Circle()
                                .stroke((reminder.displayTint ?? Color.accentColor).opacity(0.22), lineWidth: 0.8)
                        }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(AppFontStyle.subheadline.font)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let condition = reminder.triggerCondition {
                    Text("Trigger: When temperature is \(condition.comparisonType.displayName) \(condition.targetTemperature, specifier: "%.1f")°")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Trigger: No condition set")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.secondary)
                }

                SunHatStatusPill(
                    text: statusText,
                    systemImage: weatherData == nil ? "clock" : "dot.radiowaves.left.and.right",
                    tint: statusColor
                )
            }

            Spacer()

            if let weatherData {
                Text("\(weatherData.temperature, specifier: "%.0f")°")
                    .font(AppFontStyle.title3.font)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(weatherData.temperature, specifier: "%.0f") degrees")
            }
        }
        .padding(14)
        .sunHatSurface(tint: statusColor, cornerRadius: 16, prominence: 0.56)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.82)
                .scaleEffect(shouldReduceMotion || phase.isIdentity ? 1 : 0.98)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reminderAccessibilityLabel)
    }

    private var statusColor: Color {
        guard weatherData != nil else {
            return .gray
        }

        return .orange
    }

    private var statusText: String {
        guard weatherData != nil else {
            return String(localized: "Waiting for weather data", comment: "Status text shown on a reminder card while weather data hasn't loaded yet")
        }

        return String(localized: "Monitoring", comment: "Status text shown on a reminder card while actively watching the weather")
    }

    private var reminderAccessibilityLabel: String {
        var parts = [reminder.title, statusText]

        if let condition = reminder.triggerCondition {
            let temperature = String(format: "%.1f", condition.targetTemperature)
            parts.append(String(localized: "Trigger when temperature is \(condition.comparisonType.displayName) \(temperature) degrees", comment: "Accessibility label clause describing a reminder's temperature trigger condition"))
        } else {
            parts.append(String(localized: "No trigger condition set", comment: "Accessibility label clause when a reminder has no trigger condition configured"))
        }

        if let weatherData {
            let temperature = String(format: "%.0f", weatherData.temperature)
            parts.append(String(localized: "Current temperature \(temperature) degrees", comment: "Accessibility label clause stating the current temperature"))
        }

        return parts.joined(separator: ", ")
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
