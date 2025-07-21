//
//  DetailedReminderComponents.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import MapKit

// MARK: - Live Prediction Card

struct LivePredictionCard: View {
    let prediction: LivePrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Trigger")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(prediction.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(prediction.confidenceText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(prediction.confidenceColor)
                    
                    Text("confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar for confidence
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(prediction.confidenceColor)
                        .frame(width: geometry.size.width * prediction.confidence, height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.5), value: prediction.confidence)
                }
            }
            .frame(height: 4)
            
            // Matching days indicator
            HStack {
                ForEach(0..<prediction.totalDays, id: \.self) { index in
                    Circle()
                        .fill(index < prediction.matchingDays ? prediction.confidenceColor : Color(.systemGray5))
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                Text("\(prediction.matchingDays) of \(prediction.totalDays) days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Editable Trigger Conditions View

struct EditableTriggerConditionsView: View {
    @Binding var condition: EditableTriggerCondition
    let temperatureUnit: TemperatureUnit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trigger type selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Picker("Trigger Type", selection: $condition.triggerType) {
                    ForEach(TriggerType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Temperature settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Temperature")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Temperature slider
                VStack(spacing: 8) {
                    HStack {
                        Text("Target Temperature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(displayTemperature))°\(temperatureUnit.symbol.dropFirst())")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Slider(
                        value: $condition.targetTemperature,
                        in: 0...110,
                        step: 1
                    )
                    .accentColor(temperatureColor(for: condition.targetTemperature))
                }
                
                // Comparison type
                Picker("Comparison", selection: $condition.comparisonType) {
                    ForEach(ComparisonType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                // Feels like toggle
                Toggle("Use 'feels like' temperature", isOn: $condition.useFeelsLike)
                    .font(.caption)
            }
        }
    }
    
    private var displayTemperature: Double {
        switch temperatureUnit {
        case .fahrenheit:
            return condition.targetTemperature
        case .celsius:
            return (condition.targetTemperature - 32) * 5 / 9
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

// MARK: - Read-Only Trigger Conditions View

struct ReadOnlyTriggerConditionsView: View {
    let condition: TriggerCondition?
    let temperatureUnit: TemperatureUnit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let condition = condition {
                // Temperature display
                HStack {
                    Image(systemName: "thermometer.medium")
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temperature \(condition.comparisonType.displayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("\(Int(displayTemperature(condition.targetTemperature)))°\(temperatureUnit.symbol.dropFirst())")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    if condition.useFeelsLike {
                        VStack {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("Feels Like")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Additional condition details
                if condition.triggerType == .temperatureRange,
                   let min = condition.minTemperature,
                   let max = condition.maxTemperature {
                    
                    HStack {
                        Text("Range:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(displayTemperature(min)))° - \(Int(displayTemperature(max)))°")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
                // Tolerance display
                if condition.temperatureTolerance > 0 {
                    HStack {
                        Text("Tolerance:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("±\(Int(condition.temperatureTolerance))°")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
            } else {
                Text("No trigger condition set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private func displayTemperature(_ fahrenheit: Double) -> Double {
        switch temperatureUnit {
        case .fahrenheit:
            return fahrenheit
        case .celsius:
            return (fahrenheit - 32) * 5 / 9
        }
    }
}

// MARK: - Editable Notification Settings View

struct EditableNotificationSettingsView: View {
    @Binding var config: EditableNotificationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Notification title
            VStack(alignment: .leading, spacing: 8) {
                Text("Notification Title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                TextField("Enter notification title", text: $config.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Notification message
            VStack(alignment: .leading, spacing: 8) {
                Text("Message")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                TextField("Enter notification message", text: $config.message, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3)
            }
            
            // Cooldown period
            VStack(alignment: .leading, spacing: 8) {
                Text("Cooldown Period")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Stepper("\(config.cooldownPeriodHours) hours", value: $config.cooldownPeriodHours, in: 0...24)
                    .font(.subheadline)
            }
            
            // Notification options
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show badge", isOn: $config.enableBadge)
                Toggle("Play sound", isOn: $config.enableSound)
            }
        }
    }
}

// MARK: - Read-Only Notification Settings View

struct ReadOnlyNotificationSettingsView: View {
    let config: NotificationConfig?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let config = config {
                // Title and message
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        Text(config.title.isEmpty ? "Default Title" : config.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    if !config.message.isEmpty {
                        Text(config.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cooldown:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(config.cooldownPeriodHours) hours")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        if config.enableBadge {
                            Label("Badge", systemImage: "app.badge")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if config.enableSound {
                            Label("Sound", systemImage: "speaker.wave.2")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
            } else {
                Text("Default notification settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Editable Location View

struct EditableLocationView: View {
    @Binding var location: EditableLocation
    @Binding var showingLocationPicker: Bool
    
    var body: some View {
        Button(action: {
            showingLocationPicker = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: location.isCurrentLocation ? "location.fill" : "mappin.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let address = location.fullAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Read-Only Location View

struct ReadOnlyLocationView: View {
    let location: LocationData?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: location != nil ? "mappin.circle.fill" : "location.fill")
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location?.name ?? "Current Location")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let address = location?.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Using device location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Trigger History Timeline

struct TriggerHistoryTimeline: View {
    let history: [ReminderHistory]
    let isCompact: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if history.isEmpty {
                emptyHistoryView
            } else {
                ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                    TriggerHistoryRow(
                        entry: entry,
                        isLast: index == history.count - 1,
                        isCompact: isCompact
                    )
                }
            }
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No recent activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("History will appear here when the reminder triggers")
                .font(.caption)
                .foregroundColor(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct TriggerHistoryRow: View {
    let entry: ReminderHistory
    let isLast: Bool
    let isCompact: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(actionColor)
                    .frame(width: 12, height: 12)
                
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: isCompact ? 20 : 30)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.action.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isCompact ? 1 : 2)
                }
                
                if let temperature = entry.temperatureAtTime {
                    Text("Temperature: \(Int(temperature))°F")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Text(entry.timestamp, format: .dateTime.weekday().month().day())
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private var actionColor: Color {
        switch entry.action {
        case .triggered:
            return .green
        case .completed:
            return .blue
        case .snoozed, .paused:
            return .orange
        case .skipped:
            return .red
        case .created, .modified:
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Share Reminder View

struct ShareReminderView: View {
    let reminder: WeatherReminder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview of what will be shared
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share Reminder")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reminder.displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        if let condition = reminder.triggerCondition {
                            Text("Triggers when temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°F")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                
                // Share options
                VStack(spacing: 12) {
                    Button("Share as Text") {
                        shareAsText()
                    }
                    .buttonStyle(ShareButtonStyle())
                    
                    Button("Export Settings") {
                        exportSettings()
                    }
                    .buttonStyle(ShareButtonStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareAsText() {
        // Implement text sharing
    }
    
    private func exportSettings() {
        // Implement settings export
    }
}

struct ShareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.blue)
            .foregroundColor(.white)
            .font(.headline)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Duplicate Reminder View

struct DuplicateReminderView: View {
    let reminder: WeatherReminder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create a copy of this reminder with modifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Duplicate options
                VStack(spacing: 12) {
                    Button("Exact Copy") {
                        duplicateExact()
                    }
                    .buttonStyle(ShareButtonStyle())
                    
                    Button("Copy with New Location") {
                        duplicateWithNewLocation()
                    }
                    .buttonStyle(ShareButtonStyle())
                    
                    Button("Copy with Different Temperature") {
                        duplicateWithDifferentTemperature()
                    }
                    .buttonStyle(ShareButtonStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Duplicate Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func duplicateExact() {
        // Implement exact duplication
        dismiss()
    }
    
    private func duplicateWithNewLocation() {
        // Implement duplication with location picker
        dismiss()
    }
    
    private func duplicateWithDifferentTemperature() {
        // Implement duplication with temperature adjustment
        dismiss()
    }
}

// MARK: - Extensions

extension ComparisonType {
    var displayName: String {
        switch self {
        case .above: return "above"
        case .below: return "below"
        case .equals: return "exactly"
        case .between: return "between"
        }
    }
}

extension TriggerType {
    var displayName: String {
        switch self {
        case .exactTemperature: return "Exact"
        case .temperatureRange: return "Range"
        case .consecutiveDays: return "Trend"
        case .averageTemperature: return "Average"
        case .seasonalMarker: return "Seasonal"
        case .composite: return "Complex"
        case .historicalComparison: return "Historical"
        }
    }
}

// MARK: - Preview

#Preview {
    let reminder = WeatherReminder(
        title: "Morning Walk",
        reminderDescription: "Perfect weather for a refreshing morning walk",
        category: .exercise
    )
    
    return DetailedReminderView(reminder: reminder)
        .modelContainer(for: [
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ReminderHistory.self,
            NotificationConfig.self
        ], inMemory: true)
}