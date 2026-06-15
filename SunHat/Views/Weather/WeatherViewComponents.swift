//
//  WeatherViewComponents.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import Foundation

// MARK: - Detailed Metric Card

struct DetailedMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(AppFontStyle.title3.font)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppFontStyle.title3.font)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)

                Text(description)
                    .font(AppFontStyle.caption2.font)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thickMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(description)")
    }
}

// MARK: - Hourly Forecast Card

struct HourlyForecastCard: View {
    let hourData: HourlyWeatherData
    
    var body: some View {
        VStack(spacing: 8) {
            // Time
            Text(hourData.timeLabel)
                .font(AppFontStyle.caption.font)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            // Weather icon
            Image(systemName: hourData.iconName)
                .font(AppFontStyle.title3.font)
                .foregroundStyle(hourData.iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(height: 24)
            
            // Temperature
            Text("\(hourData.temperature, specifier: "%.0f")°")
                .font(AppFontStyle.subheadline.font)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            // Precipitation probability (always reserve space)
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)

                Text("\(hourData.precipitationProbability)%")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            .opacity(hourData.precipitationProbability > 0 ? 1 : 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("At \(hourData.timeLabel): \(hourData.temperature, specifier: "%.0f") degrees, \(hourData.condition)")
    }
}

// MARK: - Weekly Forecast Row

struct WeeklyForecastRow: View {
    let dayData: DailyWeatherData
    
    var body: some View {
        HStack(spacing: 16) {
            // Day of week
            Text(dayData.dayOfWeek)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: 50, alignment: .leading)
            
            // Weather icon
            Image(systemName: dayData.iconName)
                .font(AppFontStyle.title3.font)
                .foregroundStyle(dayData.iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)
            
            // Condition
            Text(dayData.condition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Precipitation probability
            if dayData.precipitationProbability > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.blue)
                    
                    Text("\(dayData.precipitationProbability)%")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.blue)
                }
                .frame(width: 40)
            } else {
                Spacer()
                    .frame(width: 40)
            }
            
            // Temperature range
            HStack(spacing: 8) {
                Text("\(dayData.lowTemp, specifier: "%.0f")°")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Temperature range bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 4)
                    
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.blue, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: temperatureBarWidth(for: dayData), height: 4)
                }
                
                Text("\(dayData.highTemp, specifier: "%.0f")°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayData.dayOfWeek): \(dayData.condition), high \(dayData.highTemp, specifier: "%.0f"), low \(dayData.lowTemp, specifier: "%.0f") degrees")
    }
    
    private func temperatureBarWidth(for dayData: DailyWeatherData) -> CGFloat {
        // Simple calculation - in a real app, you'd want to normalize across all days
        let range = dayData.highTemp - dayData.lowTemp
        return max(20, min(60, CGFloat(range) * 2))
    }
}

// Note: WeatherAlertDetailCard is defined in WeatherAlertsView.swift to avoid duplication

// MARK: - Air Quality Card

struct AirQualityCard: View {
    let aqi: Int
    let pm25: Double?
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(AppFontStyle.title3.font)
                    .foregroundStyle(aqiColor)
                
                Spacer()
                
                Text("AQI")
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(aqi)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(AppFontStyle.caption.font)
                    .fontWeight(.medium)
                    .foregroundStyle(aqiColor)
                
                if let pm25 = pm25 {
                    Text("PM2.5: \(pm25, specifier: "%.1f") μg/m³")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thickMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Air quality index: \(aqi), \(description)")
    }
    
    private var aqiColor: Color {
        switch aqi {
        case 0...50: return .green
        case 51...100: return .yellow
        case 101...150: return .orange
        case 151...200: return .red
        case 201...300: return .purple
        default: return .brown
        }
    }
}

// MARK: - Sun Times Card

struct SunTimesCard: View {
    let sunrise: Date?
    let sunset: Date?
    let dayLength: TimeInterval?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.and.horizon.fill")
                    .font(AppFontStyle.title3.font)
                    .foregroundStyle(.orange)
                
                Spacer()
                
                Text("Sun")
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let sunrise = sunrise {
                    HStack(spacing: 6) {
                        Image(systemName: "sunrise.fill")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.orange)
                        
                        Text(sunrise, style: .time)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
                
                if let sunset = sunset {
                    HStack(spacing: 6) {
                        Image(systemName: "sunset.fill")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.orange)
                        
                        Text(sunset, style: .time)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
                
                if let dayLength = dayLength {
                    let hours = Int(dayLength / 3600)
                    let minutes = Int((dayLength.truncatingRemainder(dividingBy: 3600)) / 60)
                    
                    Text("\(hours)h \(minutes)m daylight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thickMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sunrise and sunset times")
    }
}

// MARK: - Historical Comparison Row

struct HistoricalComparisonRow: View {
    let title: String
    let currentTemp: Double
    let historicalTemp: Double
    let timeframe: String
    
    private var difference: Double {
        currentTemp - historicalTemp
    }
    
    private var differenceText: String {
        let absValue = abs(difference)
        let direction = difference > 0 ? "warmer" : "cooler"
        return "\(String(format: "%.1f", absValue))° \(direction)"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(timeframe)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: difference > 0 ? "arrow.up" : difference < 0 ? "arrow.down" : "minus")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(difference > 0 ? .red : difference < 0 ? .blue : .secondary)
                    
                    Text(differenceText)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(difference > 0 ? .red : difference < 0 ? .blue : .secondary)
                }
                
                Text("\(historicalTemp, specifier: "%.1f")° then")
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): current temperature is \(differenceText) than \(timeframe)")
    }
}

// MARK: - Trigger Prediction Card

struct TriggerPredictionCard: View {
    let prediction: TriggerPrediction
    
    var body: some View {
        HStack(spacing: 12) {
            // Reminder category icon
            Image(systemName: prediction.reminderIcon)
                .font(AppFontStyle.title3.font)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.reminderTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(prediction.conditionDescription)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let triggerTime = prediction.estimatedTriggerTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        
                        Text("Expected \(triggerTime, style: .relative)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Likelihood indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(likelihoodColor)
                        .frame(width: 8, height: 8)
                    
                    Text(likelihoodText)
                        .font(AppFontStyle.caption.font)
                        .fontWeight(.medium)
                        .foregroundStyle(likelihoodColor)
                }
                
                // Current vs target temperature difference
                if let targetTemp = prediction.targetTemperature {
                    let difference = prediction.currentTemperature - targetTemp
                    Text("\(difference > 0 ? "+" : "")\(difference, specifier: "%.0f")°")
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(difference > 0 ? .red : .blue)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reminder \(prediction.reminderTitle): \(likelihoodText) likelihood to trigger")
    }
    
    private var likelihoodColor: Color {
        switch prediction.likelihood {
        case 0..<0.3: return .gray
        case 0.3..<0.6: return .yellow
        case 0.6..<0.8: return .orange
        default: return .green
        }
    }
    
    private var likelihoodText: String {
        switch prediction.likelihood {
        case 0..<0.3: return "Low"
        case 0.3..<0.6: return "Medium"
        case 0.6..<0.8: return "High"
        default: return "Very High"
        }
    }
}

// MARK: - Empty Trigger Predictions View

struct EmptyTriggerPredictionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No active reminders")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text("Create weather-triggered reminders to see predictions here")
                .font(AppFontStyle.caption.font)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }
}

// MARK: - Data Models for Components

struct HourlyWeatherData {
    let hour: Date
    let temperature: Double
    let condition: String
    let iconName: String
    let iconColor: Color
    let precipitationProbability: Int
    
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: hour).lowercased()
    }
}

struct DailyWeatherData {
    let date: Date
    let dayOfWeek: String
    let condition: String
    let iconName: String
    let iconColor: Color
    let highTemp: Double
    let lowTemp: Double
    let precipitationProbability: Int
}

struct TriggerPrediction {
    let reminderId: UUID
    let reminderTitle: String
    let reminderIcon: String
    let conditionDescription: String
    let currentTemperature: Double
    let targetTemperature: Double?
    let likelihood: Double
    let estimatedTriggerTime: Date?
}
