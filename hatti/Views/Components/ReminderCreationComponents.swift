//
//  ReminderCreationComponents.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation

// MARK: - Data Models

struct ParsedLanguageInfo {
    let originalInput: String
    let extractedTemperature: Double?
    let extractedTemperatureRange: ClosedRange<Double>?
    let suggestedCategory: ActivityInterest
    let suggestedTiming: NotificationTiming
    let suggestedTitle: String
    let suggestedMessage: String
    let confidence: Double
}

struct SmartSuggestion: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let naturalLanguageText: String
    let category: ActivityInterest
    let temperature: Double
    let temperatureRange: ClosedRange<Double>?
    let conditionType: TriggerType
    let timing: NotificationTiming
    let icon: String
    let color: Color
    
    init(id: UUID, title: String, description: String, naturalLanguageText: String, category: ActivityInterest, temperature: Double, temperatureRange: ClosedRange<Double>? = nil, conditionType: TriggerType, timing: NotificationTiming, icon: String, color: Color) {
        self.id = id
        self.title = title
        self.description = description
        self.naturalLanguageText = naturalLanguageText
        self.category = category
        self.temperature = temperature
        self.temperatureRange = temperatureRange
        self.conditionType = conditionType
        self.timing = timing
        self.icon = icon
        self.color = color
    }
}

// Note: ReminderLocation struct moved to Models/ReminderLocation.swift to avoid duplication
// Note: TriggerLikelihood moved to FirstReminderCreationViewModel.swift

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
                        .foregroundColor(.purple)
                    
                    Text("Smart Analysis")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text("\(Int(info.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(info.suggestedTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Button("Apply") {
                onApply()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple)
            .cornerRadius(6)
        }
        .padding(12)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
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
                        .foregroundColor(suggestion.color)
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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
                .cornerRadius(10)
                
                // Temperature markers
                HStack {
                    ForEach([32, 50, 70, 85, 100], id: \.self) { temp in
                        VStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 1, height: 8)
                            
                            Text("\(temp)°")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : type == .exact ? .blue : type == .range ? .green : type == .trend ? .orange : .purple)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
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
        .buttonStyle(PlainButtonStyle())
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
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
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
        .buttonStyle(PlainButtonStyle())
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
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(timing.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(timing.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: timing.icon)
                    .font(.callout)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
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
                    .foregroundColor(.secondary)
                
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
                    .foregroundColor(.secondary)
                
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
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.primary)
                        
                        Text(likelihood.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(likelihood.percentage))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(likelihood.color)
                        
                        Text("\(likelihood.triggerDays)/\(likelihood.totalDays) days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let nextDate = nextTriggerDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Next possible trigger: \(nextDate, format: .dateTime.weekday().month().day())")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
            } else {
                Text("Calculating likelihood...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
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
                .foregroundColor(.primary)
            
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
                .foregroundColor(.primary)
            
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            Text("\(Int(day.highTemperature))°")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(willTrigger ? .green : .primary)
            
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
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Mock notification header
                HStack {
                    Image(systemName: "app.badge")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("TempTrigger")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("now")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // Mock notification content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                .foregroundColor(.secondary)
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
        }
    }
}