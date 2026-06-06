//
//  ReminderCreationComponents.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation

// MARK: - Data Models

// Models have been moved to the Models folder to avoid duplication:
// ParsedLanguageInfo -> Models/ParsedLanguageInfo.swift
// SmartSuggestion     -> Models/SmartSuggestion.swift
// ReminderLocation    -> Models/ReminderLocation.swift
// TriggerLikelihood   -> Models/TriggerLikelihood.swift

// MARK: - Enums
// Note: ConditionType moved to TriggerCondition.swift as TriggerType to avoid redeclaration

enum TrendType: String, CaseIterable {
    case rising = "rising"
    case falling = "falling"
    
    var displayName: String {
        switch self {
        case .rising: return "Rising"
        case .falling: return "Falling"
        }
    }
    
    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        }
    }
}

enum SeasonalTriggerType: String, CaseIterable {
    case springTransition = "spring_transition"
    case summerTransition = "summer_transition"
    case fallTransition = "fall_transition"
    case winterTransition = "winter_transition"
    case firstFrost = "first_frost"
    case lastFrost = "last_frost"
    
    var displayName: String {
        switch self {
        case .springTransition: return "Spring Transition"
        case .summerTransition: return "Summer Transition"
        case .fallTransition: return "Fall Transition"
        case .winterTransition: return "Winter Transition"
        case .firstFrost: return "First Frost"
        case .lastFrost: return "Last Frost"
        }
    }
    
    var description: String {
        switch self {
        case .springTransition: return "When spring weather begins"
        case .summerTransition: return "When summer heat arrives"
        case .fallTransition: return "When autumn weather starts"
        case .winterTransition: return "When winter cold begins"
        case .firstFrost: return "First frost of the season"
        case .lastFrost: return "Last frost before spring"
        }
    }
}

// Note: ActivityCategory moved to UserPreferences.swift as ActivityInterest to avoid redeclaration

// MARK: - Supporting Views

struct ParsedInfoView: View {
    let info: ParsedLanguageInfo
    let onApply: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    
                    Text("Smart Analysis")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.purple)
                    
                    Spacer()
                    
                    Text("\(Int(info.confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(info.suggestedTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            
            Button("Apply") {
                onApply()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple)
            .clipShape(.rect(cornerRadius: 6))
        }
        .padding(12)
        .background(Color.purple.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }
}

struct SmartSuggestionCard: View {
    let suggestion: SmartSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: suggestion.icon)
                        .font(.title3)
                        .foregroundStyle(suggestion.color)
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct VisualTemperatureSlider: View {
    @Binding var value: Double
    @Binding var range: ClosedRange<Double>
    let conditionType: TriggerType
    let temperatureUnit: TemperatureUnit
    
    var body: some View {
        VStack(spacing: 16) {
            // Temperature scale visualization
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        .blue,    // Cold
                        .cyan,    // Cool
                        .green,   // Mild
                        .yellow,  // Warm
                        .orange,  // Hot
                        .red      // Very hot
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 20)
                .clipShape(.rect(cornerRadius: 10))
                
                // Temperature markers
                HStack {
                    ForEach([32, 50, 70, 85, 100], id: \.self) { temp in
                        VStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 1, height: 8)
                            
                            Text("\(temp)°")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        if temp != 100 {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Slider based on condition type
            if conditionType == .temperatureRange {
                RangeSlider(
                    range: $range,
                    bounds: 0...110,
                    step: 1
                )
            } else {
                Slider(
                    value: $value,
                    in: 0...110,
                    step: 1
                )
                .accentColor(temperatureColor(for: value))
            }
        }
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

// Note: RangeSlider moved to FirstReminderCreationComponents.swift to avoid duplication

// MARK: - Additional Supporting Views

struct ConditionTypeCard: View {
    let type: TriggerType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : type.iconColor)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text(type.descriptionText)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActivityCategoryCard: View {
    let category: ActivityInterest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : category.color)
                
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? category.color : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

struct NotificationTimingRow: View {
    let timing: NotificationTiming
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(timing.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(timing.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: timing.icon)
                    .font(.callout)
                    .foregroundStyle(isSelected ? .blue : .gray)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Additional Parameter Views

struct TrendConditionParameters: View {
    @Binding var trendType: TrendType
    @Binding var trendDuration: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Trend Type:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Trend Type", selection: $trendType) {
                    ForEach(TrendType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Text("Duration:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Stepper("\(trendDuration) days", value: $trendDuration, in: 1...7)
                    .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }
}

struct SeasonalConditionParameters: View {
    @Binding var seasonalType: SeasonalTriggerType
    @Binding var historicalComparison: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Seasonal Type", selection: $seasonalType) {
                ForEach(SeasonalTriggerType.allCases, id: \.self) { type in
                    VStack(alignment: .leading) {
                        Text(type.displayName)
                        Text(type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            
            Toggle("Compare to historical data", isOn: $historicalComparison)
                .font(.subheadline)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview Views

struct TriggerLikelihoodView: View {
    let likelihood: TriggerLikelihood?
    let nextTriggerDate: Date?
    
    var body: some View {
        VStack(spacing: 12) {
            if let likelihood = likelihood {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trigger Likelihood")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text(likelihood.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(likelihood.percentage))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(likelihood.color)
                        
                        Text("\(likelihood.triggerDays.count) trigger days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let nextDate = nextTriggerDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Text("Next possible trigger: \(nextDate, format: .dateTime.weekday().month().day())")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Spacer()
                    }
                }
            } else {
                Text("Calculating likelihood...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}

struct ForecastPreviewView: View {
    let forecast: [ForecastDay]
    let triggerCondition: TriggerCondition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Forecast")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(forecast.prefix(7)), id: \.id) { day in
                        ForecastDayView(day: day, willTrigger: evaluateDay(day))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func evaluateDay(_ day: ForecastDay) -> Bool {
        // Simplified evaluation
        switch triggerCondition.triggerType {
        case .exactTemperature:
            return abs(day.highTemperature - triggerCondition.targetTemperature) <= 3.0
        case .temperatureRange:
            if let min = triggerCondition.minTemperature, let max = triggerCondition.maxTemperature {
                return day.highTemperature >= min && day.highTemperature <= max
            }
        default:
            break
        }
        return false
    }
}

struct ForecastDayView: View {
    let day: ForecastDay
    let willTrigger: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            
            Text("\(Int(day.highTemperature))°")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(willTrigger ? .green : .primary)
            
            if willTrigger {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 50)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(willTrigger ? Color.green.opacity(0.1) : Color(.tertiarySystemBackground))
        )
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: day.date)
    }
}

struct ExampleNotificationView: View {
    let title: String
    let message: String
    let timing: NotificationTiming
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example Notification")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            VStack(spacing: 0) {
                // Mock notification header
                HStack {
                    Image(systemName: "app.badge")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Text("SunHat")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // Mock notification content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            )
            
            Text("Timing: \(timing.displayName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Extension for NotificationTiming

extension NotificationTiming {
    var cooldownHours: Int {
        switch self {
        case .immediate: return 1
        case .fifteenMinutes: return 2
        case .thirtyMinutes: return 2
        case .oneHour: return 3
        case .twoHours: return 4
        case .fourHours: return 5
        case .sixHours: return 6
        case .twelveHours: return 8
        case .oneDayBefore: return 24
        }
    }
}
