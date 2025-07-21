//
//  FirstReminderCreationViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class FirstReminderCreationViewModel: ObservableObject {
    @Published var selectedTemplate: ReminderTemplate?
    @Published var customReminder = CustomReminder()
    @Published var weatherForecast: [WeatherForecastDay] = []
    @Published var triggerLikelihood: TriggerLikelihood?
    @Published var isCreatingReminder = false
    
    private let weatherService = WeatherService.shared
    
    var isReminderValid: Bool {
        if customReminder.activity == .custom {
            return !customReminder.customActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return customReminder.activity != .custom
    }
    
    func selectTemplate(_ template: ReminderTemplate) {
        selectedTemplate = template
        
        // Apply template to custom reminder
        customReminder.activity = template.activity
        customReminder.condition = template.condition
        customReminder.minTemperature = template.minTemperature
        customReminder.maxTemperature = template.maxTemperature
        
        // Set reasonable defaults for other properties
        customReminder.preferredTimeRange = .allDay
        customReminder.respectQuietHours = true
        
        if template.activity == .custom {
            customReminder.customActivityName = ""
        }
    }
    
    func loadWeatherForecast() {
        Task {
            do {
                // Try to get real weather data first
                if let realForecast = await fetchRealWeatherForecast() {
                    weatherForecast = realForecast
                } else {
                    // Fall back to enhanced mock data
                    weatherForecast = generateEnhancedMockForecast()
                }
            } catch {
                print("Failed to load weather forecast: \(error)")
                weatherForecast = generateEnhancedMockForecast()
            }
        }
    }
    
    private func fetchRealWeatherForecast() async -> [WeatherForecastDay]? {
        // In a real implementation, this would use WeatherService
        // For now, return nil to use mock data
        return nil
    }
    
    func calculateLikelihood() {
        guard !weatherForecast.isEmpty else { return }
        
        let triggerDays = weatherForecast.filter { day in
            matchesConditions(day: day)
        }
        
        let percentage = Double(triggerDays.count) / Double(weatherForecast.count) * 100
        
        triggerLikelihood = TriggerLikelihood(
            percentage: percentage,
            triggerDays: triggerDays.map { $0.date },
            description: likelihoodDescription(for: percentage)
        )
    }
    
    private func matchesConditions(day: WeatherForecastDay) -> Bool {
        switch customReminder.condition {
        case .temperatureRange:
            return day.highTemp >= Int(customReminder.minTemperature) && 
                   day.highTemp <= Int(customReminder.maxTemperature)
        case .exactTemperature:
            return abs(Double(day.highTemp) - customReminder.minTemperature) <= 2
        case .sunny:
            return day.weatherCondition == .clear
        case .partlyCloudy:
            return day.weatherCondition == .partlyCloudy
        case .rainy:
            return day.weatherCondition == .rain
        }
    }
    
    private func likelihoodDescription(for percentage: Double) -> String {
        switch percentage {
        case 0:
            return "Unlikely"
        case 1...25:
            return "Low chance"
        case 26...50:
            return "Moderate chance"
        case 51...75:
            return "Good chance"
        case 76...100:
            return "Very likely"
        default:
            return "Unknown"
        }
    }
    
    func createReminder() {
        guard isReminderValid else { return }
        
        isCreatingReminder = true
        
        // In a real app, this would save to SwiftData
        // For now, we'll simulate the creation process
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                isCreatingReminder = false
                print("Reminder created: \(customReminder.displayTitle)")
            }
        }
    }
    
    private func generateEnhancedMockForecast() -> [WeatherForecastDay] {
        let today = Date()
        var forecast: [WeatherForecastDay] = []
        
        // Create more realistic weather patterns
        let baseTemperature = getCurrentSeasonalBaseTemp()
        var previousTemp = baseTemperature
        
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: today) ?? today
            
            // Create gradual temperature changes (more realistic)
            let tempChange = Int.random(in: -8...8)
            let newTemp = max(30, min(90, previousTemp + tempChange))
            previousTemp = newTemp
            
            // Weather conditions based on temperature and season
            let condition = getRealisticWeatherCondition(for: newTemp, date: date)
            
            forecast.append(WeatherForecastDay(
                date: date,
                highTemp: newTemp,
                lowTemp: newTemp - Int.random(in: 8...15),
                weatherCondition: condition
            ))
        }
        
        return forecast
    }
    
    private func getCurrentSeasonalBaseTemp() -> Int {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return 45 // Winter
        case 3, 4, 5: return 65 // Spring
        case 6, 7, 8: return 80 // Summer
        case 9, 10, 11: return 60 // Fall
        default: return 65
        }
    }
    
    private func getRealisticWeatherCondition(for temp: Int, date: Date) -> MockWeatherCondition {
        let month = Calendar.current.component(.month, from: date)
        
        // Winter conditions
        if month == 12 || month == 1 || month == 2 {
            if temp < 35 {
                return Bool.random() ? .snow : .cloudy
            } else if temp < 50 {
                return [.cloudy, .partlyCloudy].randomElement() ?? .cloudy
            }
        }
        
        // Summer conditions
        if month == 6 || month == 7 || month == 8 {
            if temp > 85 {
                return [.clear, .partlyCloudy].randomElement() ?? .clear
            } else if temp > 75 {
                return Bool.random() ? .clear : .partlyCloudy
            }
        }
        
        // General conditions based on temperature
        if temp < 40 {
            return [.cloudy, .snow].randomElement() ?? .cloudy
        } else if temp > 80 {
            return [.clear, .partlyCloudy].randomElement() ?? .clear
        } else {
            return [.clear, .partlyCloudy, .cloudy, .rain].randomElement() ?? .partlyCloudy
        }
    }
}

// MARK: - Data Structures

struct CustomReminder {
    var activity: ReminderActivity = .walking
    var customActivityName: String = ""
    var condition: WeatherConditionType = .temperatureRange
    var minTemperature: Double = 65
    var maxTemperature: Double = 75
    var preferredTimeRange: TimeRange = .allDay
    var respectQuietHours: Bool = true
    
    var displayTitle: String {
        switch activity {
        case .custom:
            return customActivityName.isEmpty ? "Custom Activity" : customActivityName
        default:
            return "Time to \(activity.actionVerb)"
        }
    }
    
    var activityDisplayName: String {
        switch activity {
        case .custom:
            return customActivityName.isEmpty ? "Custom Activity" : customActivityName
        default:
            return activity.displayName
        }
    }
    
    var temperatureDescription: String {
        switch condition {
        case .temperatureRange:
            return "\(Int(minTemperature))° - \(Int(maxTemperature))°F"
        case .exactTemperature:
            return "\(Int(minTemperature))°F"
        case .sunny:
            return "Sunny conditions"
        case .partlyCloudy:
            return "Partly cloudy"
        case .rainy:
            return "No rain"
        }
    }
    
    var previewTitle: String {
        switch activity {
        case .walking:
            return "Perfect walking weather! 🚶‍♀️"
        case .exercise:
            return "Great workout conditions! 💪"
        case .gardening:
            return "Ideal gardening weather! 🌱"
        case .photography:
            return "Beautiful lighting for photos! 📸"
        case .picnic:
            return "Perfect picnic weather! 🧺"
        case .custom:
            return "Perfect conditions for \(customActivityName)! ✨"
        }
    }
    
    var previewBody: String {
        let tempDesc = condition == .temperatureRange ? 
            "It's \(Int(minTemperature + (maxTemperature - minTemperature) / 2))°F" :
            "It's \(Int(minTemperature))°F"
        
        return "\(tempDesc) - ideal conditions for your \(activityDisplayName.lowercased()) reminder."
    }
}

struct ReminderTemplate: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let color: Color
    let activity: ReminderActivity
    let condition: WeatherConditionType
    let minTemperature: Double
    let maxTemperature: Double
    let exampleTrigger: String
}

enum ReminderActivity: String, CaseIterable, Hashable {
    case walking
    case exercise
    case gardening
    case photography
    case picnic
    case custom
    
    var displayName: String {
        switch self {
        case .walking:
            return "Walking"
        case .exercise:
            return "Exercise"
        case .gardening:
            return "Gardening"
        case .photography:
            return "Photography"
        case .picnic:
            return "Picnic"
        case .custom:
            return "Custom"
        }
    }
    
    var actionVerb: String {
        switch self {
        case .walking:
            return "go for a walk"
        case .exercise:
            return "exercise"
        case .gardening:
            return "tend your garden"
        case .photography:
            return "take photos"
        case .picnic:
            return "have a picnic"
        case .custom:
            return "start your activity"
        }
    }
    
    var icon: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .exercise:
            return "figure.run"
        case .gardening:
            return "leaf.fill"
        case .photography:
            return "camera.fill"
        case .picnic:
            return "basket.fill"
        case .custom:
            return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .walking:
            return .green
        case .exercise:
            return .blue
        case .gardening:
            return .green
        case .photography:
            return .purple
        case .picnic:
            return .orange
        case .custom:
            return .gray
        }
    }
}

enum WeatherConditionType: String, CaseIterable, Hashable {
    case temperatureRange
    case exactTemperature
    case sunny
    case partlyCloudy
    case rainy
    
    var displayName: String {
        switch self {
        case .temperatureRange:
            return "Temperature Range"
        case .exactTemperature:
            return "Exact Temperature"
        case .sunny:
            return "Sunny"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .rainy:
            return "No Rain"
        }
    }
    
    var icon: String {
        switch self {
        case .temperatureRange:
            return "thermometer.medium"
        case .exactTemperature:
            return "thermometer"
        case .sunny:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .rainy:
            return "cloud.rain.fill"
        }
    }
}

enum TimeRange: String, CaseIterable, Hashable {
    case morning
    case afternoon
    case evening
    case allDay
    
    var displayName: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .allDay:
            return "All Day"
        }
    }
    
    var icon: String {
        switch self {
        case .morning:
            return "sunrise.fill"
        case .afternoon:
            return "sun.max.fill"
        case .evening:
            return "sunset.fill"
        case .allDay:
            return "clock.fill"
        }
    }
    
    var hours: ClosedRange<Int> {
        switch self {
        case .morning:
            return 6...11
        case .afternoon:
            return 12...17
        case .evening:
            return 18...21
        case .allDay:
            return 6...21
        }
    }
}

struct TriggerLikelihood {
    let percentage: Double
    let triggerDays: [Date]
    let description: String
    
    var color: Color {
        switch percentage {
        case 0:
            return .gray
        case 1...25:
            return .red
        case 26...50:
            return .orange
        case 51...75:
            return .yellow
        case 76...100:
            return .green
        default:
            return .gray
        }
    }
}

struct WeatherForecastDay: Identifiable {
    let id = UUID()
    let date: Date
    let highTemp: Int
    let lowTemp: Int
    let weatherCondition: MockWeatherCondition
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    var weatherIcon: String {
        weatherCondition.icon
    }
    
    var weatherColor: Color {
        weatherCondition.color
    }
}

enum MockWeatherCondition: String, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case snow
    
    var icon: String {
        switch self {
        case .clear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .clear:
            return .yellow
        case .partlyCloudy:
            return .orange
        case .cloudy:
            return .gray
        case .rain:
            return .blue
        case .snow:
            return .white
        }
    }
}