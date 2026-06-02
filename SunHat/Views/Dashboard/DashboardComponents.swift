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
                .foregroundColor(alert.severityColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(AppFontStyle.subheadline.font)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(alert.description)
                    .font(AppFontStyle.caption.font)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(alert.severityColor.opacity(0.1))
        )
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
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(AppFontStyle.subheadline.font)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let condition = reminder.triggerCondition {
                    Text("Trigger: When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature, specifier: "%.1f")°")
                        .font(AppFontStyle.caption.font)
                        .foregroundColor(.secondary)
                } else {
                    Text("Trigger: No condition set")
                        .font(AppFontStyle.caption.font)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(AppFontStyle.caption2.font)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let weatherData {
                Text("\(weatherData.temperature, specifier: "%.0f")°")
                    .font(AppFontStyle.caption.font)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
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

// MARK: - Detailed Weather Card

struct DetailedWeatherCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppFontStyle.title3.font)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(AppFontStyle.caption.font)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(AppFontStyle.headline.font)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Empty Active Reminders View

struct EmptyActiveRemindersView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(AppFontStyle.title.font)
                .foregroundColor(.secondary)

            Text("No active reminders")
                .font(AppFontStyle.subheadline.font)
                .foregroundColor(.secondary)

            Text("Create your first weather reminder to get started")
                .font(AppFontStyle.caption.font)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(AppFontStyle.title3.font)
                    .foregroundColor(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppFontStyle.title3.font)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(title)
                    .font(AppFontStyle.caption.font)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Forecast Range Enum

enum ForecastRange: Int {
    case fiveDay = 5
    case sevenDay = 7
    case tenDay = 10
}

// MARK: - Hourly Weather Card

struct HourlyWeatherCard: View {
    let hour: Int
    let temperature: Double
    let condition: String
    let precipChance: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(hourText)
                .font(AppFontStyle.caption.font)
                .foregroundColor(.secondary)

            Image(systemName: condition)
                .font(AppFontStyle.title3.font)
                .foregroundColor(conditionColor)
                .frame(height: 24)

            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(AppFontStyle.caption2.font)
                    .foregroundColor(.cyan)
                Text("\(precipChance)%")
                    .font(AppFontStyle.caption2.font)
                    .foregroundColor(.cyan)
            }
            .opacity(precipChance > 0 ? 1 : 0)

            Text("\(String(format: "%.0f", temperature))°")
                .font(AppFontStyle.callout.font)
                .fontWeight(.semibold)
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var conditionColor: Color {
        if condition.contains("sun") || condition.contains("clear") {
            return .orange
        } else if condition.contains("cloud.bolt") {
            return .purple
        } else if condition.contains("cloud.rain") || condition.contains("cloud.heavyrain") {
            return .blue
        } else if condition.contains("cloud.snow") || condition.contains("snowflake") {
            return .cyan
        } else if condition.contains("cloud.fog") || condition.contains("cloud.haze") {
            return .gray
        } else if condition.contains("cloud") {
            return .gray
        } else if condition.contains("wind") {
            return .teal
        } else if condition.contains("moon") {
            return .indigo
        } else {
            return .orange
        }
    }

    private var hourText: String {
        if hour == 0 {
            return "Now"
        }
        let futureHour = (Calendar.current.component(.hour, from: Date()) + hour) % 24
        let period = futureHour < 12 ? "AM" : "PM"
        let displayHour = futureHour == 0 ? 12 : (futureHour > 12 ? futureHour - 12 : futureHour)
        return "\(displayHour)\(period)"
    }
}

// MARK: - Enhanced Day Forecast Row

struct EnhancedDayForecastRow: View {
    let forecast: ForecastDay
    let minTemp: Double
    let maxTemp: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(dayText)
                .font(AppFontStyle.subheadline.font)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 52, alignment: .leading)

            Image(systemName: forecast.weatherCondition.icon)
                .font(AppFontStyle.body.font)
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 26)

            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(AppFontStyle.caption2.font)
                    .foregroundColor(.blue)
                Text("\(forecast.precipitationProbability)%")
                    .font(AppFontStyle.caption.font)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, alignment: .leading)
            .opacity(forecast.precipitationProbability > 0 ? 1 : 0)

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                Text("\(String(format: "%.0f", forecast.lowTemperature))°")
                    .font(AppFontStyle.subheadline.font)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)

                TemperatureBar(
                    low: forecast.lowTemperature,
                    high: forecast.highTemperature,
                    minTemp: minTemp,
                    maxTemp: maxTemp
                )
                .frame(width: 75, height: 6)

                Text("\(String(format: "%.0f", forecast.highTemperature))°")
                    .font(AppFontStyle.subheadline.font)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: 30, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
    }

    private var dayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(forecast.date) {
            return "Today"
        } else if calendar.isDateInTomorrow(forecast.date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: forecast.date)
        }
    }
}

// MARK: - Temperature Bar

struct TemperatureBar: View {
    let low: Double
    let high: Double
    let minTemp: Double
    let maxTemp: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: rangeWidth(in: geometry.size.width), height: 6)
                    .offset(x: startOffset(in: geometry.size.width))
            }
        }
        .frame(height: 6)
    }

    private func startOffset(in width: CGFloat) -> CGFloat {
        let normalized = max(0, min(1, (low - minTemp) / (maxTemp - minTemp)))
        return width * normalized
    }

    private func rangeWidth(in width: CGFloat) -> CGFloat {
        let normalizedLow = max(0, min(1, (low - minTemp) / (maxTemp - minTemp)))
        let normalizedHigh = max(0, min(1, (high - minTemp) / (maxTemp - minTemp)))
        return max(width * 0.15, width * (normalizedHigh - normalizedLow))
    }
}

// MARK: - Weather Metric Card

struct WeatherMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppFontStyle.title3.font)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(AppFontStyle.caption.font)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(AppFontStyle.title3.font)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(AppFontStyle.caption2.font)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Empty Forecast View

struct EmptyForecastView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.slash")
                .font(AppFontStyle.title.font)
                .foregroundColor(.secondary)

            Text("Forecast unavailable")
                .font(AppFontStyle.subheadline.font)
                .foregroundColor(.secondary)

            Text("Pull to refresh weather data")
                .font(AppFontStyle.caption.font)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
