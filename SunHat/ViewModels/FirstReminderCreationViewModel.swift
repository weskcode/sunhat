//
//  FirstReminderCreationViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import CoreLocation
import MapKit

@MainActor
final class FirstReminderCreationViewModel: ObservableObject {
    @Published var selectedTemplate: ReminderTemplate?
    @Published var customReminder = CustomReminder()
    @Published var weatherForecast: [WeatherForecastDay] = []
    @Published var triggerLikelihood: TriggerLikelihood?
    @Published var isCreatingReminder = false
    @Published var showLocationPicker = false

    private let weatherService = WeatherService.shared
    private let locationPermissionManager = LocationPermissionManager.shared
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Location Management

    func initializeDefaultLocation() {
        let status = locationPermissionManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            customReminder.selectedLocation = .currentLocation
        }
    }

    func selectManualLocation(_ location: ManualLocationData) {
        customReminder.selectedLocation = .manual(location)
        showLocationPicker = false
    }

    func selectCurrentLocation() {
        customReminder.selectedLocation = .currentLocation
        showLocationPicker = false
    }
    
    var isReminderValid: Bool {
        !customReminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func selectTemplate(_ template: ReminderTemplate) {
        selectedTemplate = template

        // Apply template to custom reminder
        customReminder.title = template.defaultTitle
        customReminder.selectedIcon = template.iconName
        applyActivityDefaults(from: template.defaultTitle)
        customReminder.condition = template.condition
        customReminder.minTemperature = template.minTemperature
        customReminder.maxTemperature = template.maxTemperature

        // Map legacy condition type to new fields
        switch template.condition {
        case .temperatureRange:
            customReminder.temperatureType = .temperatureRange
            customReminder.selectedSkyConditions = [.sunny, .partlyCloudy]
            customReminder.conditionMode = .include
        case .exactTemperature:
            customReminder.temperatureType = .exactTemperature
            customReminder.selectedSkyConditions = [.sunny, .partlyCloudy]
            customReminder.conditionMode = .include
        case .sunny:
            customReminder.temperatureType = .temperatureRange
            customReminder.selectedSkyConditions = [.sunny]
            customReminder.conditionMode = .include
        case .partlyCloudy:
            customReminder.temperatureType = .temperatureRange
            customReminder.selectedSkyConditions = [.sunny, .partlyCloudy]
            customReminder.conditionMode = .include
        case .rainy:
            customReminder.temperatureType = .temperatureRange
            customReminder.selectedSkyConditions = [.rainy]
            customReminder.conditionMode = .exclude
        }

        // Set reasonable defaults for other properties
        customReminder.preferredTimeRange = .allDay
        customReminder.respectQuietHours = true
    }

    func applyActivityDefaults(from title: String) {
        let normalizedTitle = title.lowercased()

        let appearance: (icon: String, color: Color)?
        if normalizedTitle.contains("run") || normalizedTitle.contains("jog") {
            appearance = ("figure.run", .blue)
        } else if normalizedTitle.contains("walk") || normalizedTitle.contains("hike") {
            appearance = ("figure.walk", .green)
        } else if normalizedTitle.contains("garden") || normalizedTitle.contains("plant") || normalizedTitle.contains("yard") {
            appearance = ("leaf.fill", .green)
        } else if normalizedTitle.contains("pool") || normalizedTitle.contains("swim") {
            appearance = ("figure.pool.swim", .cyan)
        } else if normalizedTitle.contains("photo") || normalizedTitle.contains("camera") {
            appearance = ("camera.fill", .purple)
        } else if normalizedTitle.contains("bike") || normalizedTitle.contains("cycle") {
            appearance = ("bicycle", .orange)
        } else if normalizedTitle.contains("dog") || normalizedTitle.contains("pet") {
            appearance = ("dog.fill", .orange)
        } else {
            appearance = nil
        }

        guard let appearance else { return }
        customReminder.selectedIcon = appearance.icon
        customReminder.selectedColor = appearance.color
    }
    
    func loadWeatherForecast() {
        Task {
            do {
                // Try to get real weather data first
                if let realForecast = try await fetchRealWeatherForecast() {
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
    
    private func fetchRealWeatherForecast() async throws -> [WeatherForecastDay]? {
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
            description: likelihoodDescription(for: percentage),
            triggerDays: triggerDays.map { $0.date }
        )
    }
    
    private func matchesConditions(day: WeatherForecastDay) -> Bool {
        // Check temperature condition
        let tempMatch: Bool
        switch customReminder.temperatureType {
        case .temperatureRange:
            tempMatch = day.highTemp >= Int(customReminder.minTemperature) &&
                        day.highTemp <= Int(customReminder.maxTemperature)
        case .exactTemperature:
            tempMatch = abs(Double(day.highTemp) - customReminder.minTemperature) <= 2
        }

        // Check sky condition (multi-select with include/exclude)
        let skyMatch = customReminder.matchesSkyCondition(for: day.weatherCondition)

        return tempMatch && skyMatch
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
        guard isReminderValid, let modelContext else { return }

        isCreatingReminder = true

        let reminder = WeatherReminder(title: customReminder.displayTitle)
        reminder.reminderDescription = customReminder.notes
        reminder.userNotes = customReminder.notes
        reminder.category = .general
        reminder.isActive = true

        // Build trigger condition from the custom reminder settings
        let trigger = TriggerCondition()
        switch customReminder.temperatureType {
        case .temperatureRange:
            trigger.triggerType = .temperatureRange
            trigger.minTemperature = customReminder.minTemperature
            trigger.maxTemperature = customReminder.maxTemperature
            trigger.comparisonType = .between
        case .exactTemperature:
            trigger.triggerType = .exactTemperature
            trigger.targetTemperature = customReminder.minTemperature
            trigger.comparisonType = .equals
        }

        if !customReminder.selectedSkyConditions.isEmpty {
            trigger.selectedSkyConditions = customReminder.selectedSkyConditions
            trigger.conditionMode = customReminder.conditionMode
        }

        reminder.triggerCondition = trigger

        // Set location on the reminder
        switch customReminder.selectedLocation {
        case .currentLocation:
            if let clLocation = locationPermissionManager.currentLocation {
                let locationData = LocationData(
                    latitude: clLocation.coordinate.latitude,
                    longitude: clLocation.coordinate.longitude
                )
                locationData.isUserLocation = true
                locationData.displayName = "Current Location"
                reminder.location = locationData
            }
        case .manual(let manualData):
            let locationData = LocationData(
                latitude: manualData.coordinate.latitude,
                longitude: manualData.coordinate.longitude,
                city: manualData.name
            )
            locationData.isManuallyEntered = true
            locationData.state = manualData.administrativeArea ?? ""
            locationData.country = manualData.country ?? ""
            locationData.displayName = manualData.displayName
            reminder.location = locationData
        }

        modelContext.insert(reminder)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save reminder: \(error.localizedDescription)")
        }

        isCreatingReminder = false
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

struct ReminderColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
}

struct CustomReminder {
    var title: String = ""
    var selectedIcon: String = "figure.walk"
    var selectedColor: Color = .blue
    var condition: WeatherConditionType = .temperatureRange
    var temperatureType: TemperatureConditionType = .temperatureRange
    var minTemperature: Double = 65
    var maxTemperature: Double = 75
    var preferredTimeRange: TimeRange = .allDay
    var respectQuietHours: Bool = true

    // Multi-select sky conditions
    var selectedSkyConditions: Set<SkyCondition> = [.sunny, .partlyCloudy]
    var conditionMode: ConditionSelectionMode = .include

    // User notes
    var notes: String = ""

    // Location selection
    var selectedLocation: ReminderLocationSelection = .currentLocation

    var locationDisplayName: String {
        selectedLocation.displayName
    }

    // MARK: - Icon Catalog (Expanded)

    static let availableIcons: [String] = [
        // Outdoor Activities
        "figure.walk",
        "figure.run",
        "figure.hiking",
        "bicycle",
        "figure.outdoor.cycle",

        // Nature & Garden
        "leaf.fill",
        "tree.fill",
        "drop.fill",
        "flame.fill",
        "snowflake",

        // Sports & Fitness
        "tennis.racket",
        "figure.tennis",
        "figure.golf",
        "figure.yoga",
        "dumbbell.fill",

        // Creative & Hobbies
        "camera.fill",
        "paintbrush.fill",
        "pencil.and.outline",
        "music.note",
        "book.fill",

        // Food & Shopping
        "basket.fill",
        "cart.fill",
        "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw.fill",

        // Work & Productivity
        "briefcase.fill",
        "laptopcomputer",
        "desktopcomputer",
        "note.text",

        // Pets & Animals
        "dog.fill",
        "cat.fill",
        "bird.fill",
        "fish.fill",

        // Travel & Transport
        "car.fill",
        "bus.fill",
        "airplane",
        "sailboat.fill",

        // Home & Maintenance
        "house.fill",
        "lightbulb.fill",
        "wrench.and.screwdriver.fill",
        "hammer.fill",

        // General
        "star.fill",
        "heart.fill",
        "flag.fill",
        "bell.fill"
    ]

    // MARK: - Color Palette

    static let availableColors: [ReminderColor] = [
        ReminderColor(name: "Blue", color: .blue),
        ReminderColor(name: "Purple", color: .purple),
        ReminderColor(name: "Pink", color: .pink),
        ReminderColor(name: "Red", color: .red),
        ReminderColor(name: "Orange", color: .orange),
        ReminderColor(name: "Yellow", color: .yellow),
        ReminderColor(name: "Green", color: .green),
        ReminderColor(name: "Teal", color: .teal),
        ReminderColor(name: "Cyan", color: .cyan),
        ReminderColor(name: "Indigo", color: .indigo),
        ReminderColor(name: "Mint", color: .mint),
        ReminderColor(name: "Brown", color: .brown)
    ]

    var iconColor: Color {
        selectedColor
    }

    var displayTitle: String {
        title.isEmpty ? "New Reminder" : title
    }

    var temperatureDescription: String {
        switch temperatureType {
        case .temperatureRange:
            return "\(Int(minTemperature))° - \(Int(maxTemperature))°F"
        case .exactTemperature:
            return "\(Int(minTemperature))°F"
        }
    }

    var skyConditionDescription: String {
        guard !selectedSkyConditions.isEmpty else {
            return "Any weather"
        }
        let names = selectedSkyConditions
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.displayName }
        let joined = names.joined(separator: ", ")
        switch conditionMode {
        case .include:
            return joined
        case .exclude:
            return "Not \(joined.lowercased())"
        }
    }

    var previewTitle: String {
        "Perfect weather for \(displayTitle)! ✨"
    }

    var previewBody: String {
        let tempDesc = temperatureType == .temperatureRange ?
            "It's \(Int(minTemperature + (maxTemperature - minTemperature) / 2))°F" :
            "It's \(Int(minTemperature))°F"

        return "\(tempDesc) and \(skyConditionDescription.lowercased()) — ideal for your \(displayTitle.lowercased()) reminder."
    }

    /// Evaluate if a forecast day matches the sky conditions
    func matchesSkyCondition(for mockCondition: MockWeatherCondition) -> Bool {
        let sky = SkyCondition.from(mockCondition)
        switch conditionMode {
        case .include:
            return selectedSkyConditions.isEmpty || selectedSkyConditions.contains(sky)
        case .exclude:
            return !selectedSkyConditions.contains(sky)
        }
    }
}

// MARK: - Location Selection

enum ReminderLocationSelection: Equatable {
    case currentLocation
    case manual(ManualLocationData)

    var displayName: String {
        switch self {
        case .currentLocation:
            return "Current Location"
        case .manual(let data):
            return data.displayName
        }
    }

    var isCurrentLocation: Bool {
        if case .currentLocation = self { return true }
        return false
    }

    static func == (lhs: ReminderLocationSelection, rhs: ReminderLocationSelection) -> Bool {
        switch (lhs, rhs) {
        case (.currentLocation, .currentLocation):
            return true
        case (.manual(let a), .manual(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

struct ReminderTemplate: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let color: Color
    let defaultTitle: String
    let iconName: String
    let condition: WeatherConditionType
    let minTemperature: Double
    let maxTemperature: Double
    let exampleTrigger: String
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

// MARK: - Sky Condition (multi-select include/exclude)

enum SkyCondition: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case sunny
    case partlyCloudy
    case cloudy
    case rainy
    case snowy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunny: return "Sunny"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .rainy: return "Rainy"
        case .snowy: return "Snowy"
        }
    }

    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .snowy: return "cloud.snow.fill"
        }
    }

    var color: Color {
        switch self {
        case .sunny: return .yellow
        case .partlyCloudy: return .orange
        case .cloudy: return .gray
        case .rainy: return .blue
        case .snowy: return .cyan
        }
    }

    /// Map from MockWeatherCondition
    static func from(_ mock: MockWeatherCondition) -> SkyCondition {
        switch mock {
        case .clear: return .sunny
        case .partlyCloudy: return .partlyCloudy
        case .cloudy: return .cloudy
        case .rain: return .rainy
        case .snow: return .snowy
        }
    }

    /// Map from WeatherCondition (real weather data)
    static func from(_ condition: WeatherCondition) -> SkyCondition {
        switch condition {
        case .clear: return .sunny
        case .partlyCloudy: return .partlyCloudy
        case .cloudy, .overcast, .fog: return .cloudy
        case .rain, .drizzle, .thunderstorm: return .rainy
        case .snow, .sleet, .hail: return .snowy
        case .windy, .unknown: return .sunny
        }
    }
}

enum ConditionSelectionMode: String, Codable, Hashable, Sendable {
    case include  // Remind me when ANY of these conditions
    case exclude  // Remind me UNLESS any of these conditions
}

// MARK: - Temperature Condition Type

enum TemperatureConditionType: String, CaseIterable, Hashable {
    case temperatureRange
    case exactTemperature

    var displayName: String {
        switch self {
        case .temperatureRange: return "Temperature Range"
        case .exactTemperature: return "Exact Temperature"
        }
    }

    var icon: String {
        switch self {
        case .temperatureRange: return "thermometer.medium"
        case .exactTemperature: return "thermometer"
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
