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
    @Published var creationErrorMessage: String?
    @Published var showLocationPicker = false

    // Real current-weather display for the selected location (no hardcoded values).
    @Published var isLoadingCurrentWeather = false
    @Published var hasCurrentWeather = false
    @Published var currentTemperatureText = "--"
    @Published var feelsLikeText = "--"
    @Published var currentConditionText = ""
    @Published var currentConditionIcon = "cloud.fill"
    @Published var currentConditionColor: Color = .secondary

    private let weatherService = WeatherService.shared
    private let locationPermissionManager = LocationPermissionManager.shared
    private var modelContext: ModelContext?
    private var temperatureUnit: TemperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
    private var weatherTask: Task<Void, Never>?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadTemperatureUnit()
    }

    private func loadTemperatureUnit() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<UserPreferences>()
        if let preferences = try? modelContext.fetch(descriptor).first {
            temperatureUnit = preferences.temperatureUnit
        }
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
        loadWeather()
    }

    func selectCurrentLocation() {
        customReminder.selectedLocation = .currentLocation
        showLocationPicker = false
        loadWeather()
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
        } else if normalizedTitle.contains("dog") || normalizedTitle.contains("pet") {
            appearance = ("dog.fill", .orange)
        } else if normalizedTitle.contains("photo") || normalizedTitle.contains("camera") {
            appearance = ("camera.fill", .purple)
        } else if normalizedTitle.contains("bike") || normalizedTitle.contains("cycle") {
            appearance = ("bicycle", .orange)
        } else if normalizedTitle.contains("pool") || normalizedTitle.contains("swim") {
            appearance = ("figure.pool.swim", .cyan)
        } else if normalizedTitle.contains("garden") || normalizedTitle.contains("plant") || normalizedTitle.contains("yard") {
            appearance = ("leaf.fill", .green)
        } else if normalizedTitle.contains("walk") || normalizedTitle.contains("hike") {
            appearance = ("figure.walk", .green)
        } else {
            appearance = nil
        }

        guard let appearance else { return }
        customReminder.selectedIcon = appearance.icon
        customReminder.selectedColor = appearance.color
    }
    
    /// Loads live weather for the selected location via WeatherKit and publishes both
    /// the current-conditions card and the forecast (used for trigger likelihood) from a
    /// single API call. Degrades to an unavailable/empty state when there's no location
    /// or the fetch fails, never shows fabricated values.
    func loadWeather() {
        weatherTask?.cancel()
        weatherTask = Task { [weak self] in
            guard let self else { return }

            guard let location = self.resolveSelectedLocation() else {
                self.clearWeather()
                return
            }

            self.isLoadingCurrentWeather = true
            defer { self.isLoadingCurrentWeather = false }

            do {
                let data = try await self.weatherService.fetchWeatherData(for: location)
                guard !Task.isCancelled else { return }
                self.applyCurrentWeather(data)
                self.weatherForecast = Self.mapForecast(data.forecastDays)
                self.calculateLikelihood()
            } catch {
                guard !Task.isCancelled else { return }
                self.clearWeather()
            }
        }
    }

    private func clearWeather() {
        isLoadingCurrentWeather = false
        hasCurrentWeather = false
        weatherForecast = []
        triggerLikelihood = nil
    }

    /// Maps the live forecast (full `WeatherCondition` set, Fahrenheit) into the compact
    /// `WeatherForecastDay` used by the likelihood calculation. Temps stay in Fahrenheit
    /// to match the trigger comparison against the user's configured temperature range.
    // Internal (not private) so the mapping is unit-testable via `@testable import`.
    static func mapForecast(_ days: [ForecastDay]) -> [WeatherForecastDay] {
        days.prefix(7).map { day in
            WeatherForecastDay(
                date: day.date,
                highTemp: Int(day.highTemperature.rounded()),
                lowTemp: Int(day.lowTemperature.rounded()),
                weatherCondition: mapToMockCondition(day.weatherCondition)
            )
        }
    }

    static func mapToMockCondition(_ condition: WeatherCondition) -> MockWeatherCondition {
        switch condition {
        case .clear: return .clear
        case .partlyCloudy: return .partlyCloudy
        case .cloudy, .overcast, .fog, .windy, .unknown: return .cloudy
        case .rain, .drizzle, .thunderstorm: return .rain
        case .snow, .sleet, .hail: return .snow
        }
    }

    private func applyCurrentWeather(_ data: WeatherData) {
        currentTemperatureText = formattedTemperature(data.temperature)
        feelsLikeText = formattedTemperature(data.feelsLike)
        currentConditionText = data.weatherDescription.isEmpty
            ? data.weatherCondition.rawValue.capitalized
            : data.weatherDescription
        currentConditionIcon = data.weatherCondition.iconName
        currentConditionColor = data.weatherCondition.iconColor
        hasCurrentWeather = true
    }

    private func resolveSelectedLocation() -> CLLocation? {
        switch customReminder.selectedLocation {
        case .currentLocation:
            return locationPermissionManager.currentLocation
        case .manual(let data):
            return CLLocation(latitude: data.coordinate.latitude, longitude: data.coordinate.longitude)
        }
    }

    private func convertTemperature(_ fahrenheit: Double) -> Double {
        switch temperatureUnit {
        case .fahrenheit: return fahrenheit
        case .celsius: return (fahrenheit - 32) * 5 / 9
        }
    }

    private func formattedTemperature(_ fahrenheit: Double) -> String {
        convertTemperature(fahrenheit).formatted(.number.precision(.fractionLength(0)))
    }
    
    func calculateLikelihood() {
        guard !weatherForecast.isEmpty else {
            triggerLikelihood = nil
            return
        }

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
            return String(localized: "Unlikely", comment: "Trigger likelihood: 0% chance the reminder's conditions will occur")
        case 1...25:
            return String(localized: "Low chance", comment: "Trigger likelihood: 1-25% chance the reminder's conditions will occur")
        case 26...50:
            return String(localized: "Moderate chance", comment: "Trigger likelihood: 26-50% chance the reminder's conditions will occur")
        case 51...75:
            return String(localized: "Good chance", comment: "Trigger likelihood: 51-75% chance the reminder's conditions will occur")
        case 76...100:
            return String(localized: "Very likely", comment: "Trigger likelihood: 76-100% chance the reminder's conditions will occur")
        default:
            return String(localized: "Unknown", comment: "Trigger likelihood: percentage outside the expected 0-100 range")
        }
    }
    
    /// Saves the reminder. Returns whether the save succeeded; on failure
    /// `creationErrorMessage` is set for the view to surface.
    @discardableResult
    func createReminder() -> Bool {
        guard isReminderValid, let modelContext else { return false }

        // Resolve the location before creating anything. A reminder without a
        // usable location can never be evaluated, so saving one would silently
        // do nothing; fail with a clear message instead.
        let locationData: LocationData
        switch customReminder.selectedLocation {
        case .currentLocation:
            guard let clLocation = locationPermissionManager.currentLocation else {
                creationErrorMessage = String(localized: "SunHat couldn't determine your current location. Pick a location for this reminder, or try again once location is available.", comment: "Error shown when saving a reminder set to current location while no location fix is available")
                return false
            }
            locationData = LocationData(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude
            )
            locationData.isUserLocation = true
            locationData.displayName = String(localized: "Current Location", comment: "Location label shown when using the device's current location")
        case .manual(let manualData):
            locationData = LocationData(
                latitude: manualData.coordinate.latitude,
                longitude: manualData.coordinate.longitude,
                city: manualData.name
            )
            locationData.isManuallyEntered = true
            locationData.state = manualData.administrativeArea ?? ""
            locationData.country = manualData.country ?? ""
            locationData.displayName = manualData.displayName
        }

        isCreatingReminder = true

        let reminder = WeatherReminder(title: customReminder.displayTitle)
        reminder.reminderDescription = customReminder.notes
        reminder.userNotes = customReminder.notes
        reminder.category = .general
        reminder.isActive = true
        reminder.customIconName = customReminder.selectedIcon
        reminder.customTintName = ReminderTint.name(for: customReminder.selectedColor)

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
        reminder.location = locationData

        // Persist the delivery preferences the creation screen collects. The
        // title/message stay empty so notifications keep the specific trigger
        // reason until the user customizes them in the reminder's settings.
        let notificationConfig = NotificationConfig(title: "", message: "")
        notificationConfig.respectsQuietHours = customReminder.respectQuietHours
        let timeRange = customReminder.preferredTimeRange
        notificationConfig.avoidNighttime = timeRange != .allDay
        notificationConfig.preferredStartHour = timeRange.hours.lowerBound
        notificationConfig.preferredEndHour = timeRange.hours.upperBound
        notificationConfig.avoidEarlyMorning = false
        reminder.notificationConfig = notificationConfig

        modelContext.insert(reminder)
        do {
            try modelContext.save()
            SunHatSearchIndexer.index(reminder: reminder)
        } catch {
            modelContext.delete(reminder)
            creationErrorMessage = String(localized: "Couldn't save your reminder. Please try again.", comment: "Error shown when creating a reminder fails to persist")
            isCreatingReminder = false
            return false
        }

        isCreatingReminder = false
        return true
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
        ReminderColor(name: String(localized: "Blue", comment: "Reminder color swatch name"), color: .blue),
        ReminderColor(name: String(localized: "Purple", comment: "Reminder color swatch name"), color: .purple),
        ReminderColor(name: String(localized: "Pink", comment: "Reminder color swatch name"), color: .pink),
        ReminderColor(name: String(localized: "Red", comment: "Reminder color swatch name"), color: .red),
        ReminderColor(name: String(localized: "Orange", comment: "Reminder color swatch name"), color: .orange),
        ReminderColor(name: String(localized: "Yellow", comment: "Reminder color swatch name"), color: .yellow),
        ReminderColor(name: String(localized: "Green", comment: "Reminder color swatch name"), color: .green),
        ReminderColor(name: String(localized: "Teal", comment: "Reminder color swatch name"), color: .teal),
        ReminderColor(name: String(localized: "Cyan", comment: "Reminder color swatch name"), color: .cyan),
        ReminderColor(name: String(localized: "Indigo", comment: "Reminder color swatch name"), color: .indigo),
        ReminderColor(name: String(localized: "Mint", comment: "Reminder color swatch name"), color: .mint),
        ReminderColor(name: String(localized: "Brown", comment: "Reminder color swatch name"), color: .brown)
    ]

    var iconColor: Color {
        selectedColor
    }

    var displayTitle: String {
        title.isEmpty ? String(localized: "New Reminder", comment: "Fallback reminder title shown when the user hasn't entered one") : title
    }

    var temperatureDescription: String {
        switch temperatureType {
        case .temperatureRange:
            return String(localized: "\(Int(minTemperature))° - \(Int(maxTemperature))°F", comment: "Temperature range shown for a reminder, e.g. '65° - 75°F'")
        case .exactTemperature:
            return String(localized: "\(Int(minTemperature))°F", comment: "Exact target temperature shown for a reminder, e.g. '70°F'")
        }
    }

    var skyConditionDescription: String {
        guard !selectedSkyConditions.isEmpty else {
            return String(localized: "Any weather", comment: "Sky condition summary when no specific sky conditions are selected")
        }
        let names = selectedSkyConditions
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.displayName }
        let joined = names.joined(separator: ", ")
        switch conditionMode {
        case .include:
            return joined
        case .exclude:
            return String(localized: "Not \(joined.lowercased())", comment: "Sky condition summary when excluding the listed conditions, e.g. 'Not rainy'")
        }
    }

    var previewTitle: String {
        String(localized: "Perfect weather for \(displayTitle)! ✨", comment: "Preview notification title shown while creating a reminder")
    }

    var previewBody: String {
        let tempDesc = temperatureType == .temperatureRange ?
            String(localized: "It's \(Int(minTemperature + (maxTemperature - minTemperature) / 2))°F", comment: "Preview notification body temperature clause for a temperature range reminder") :
            String(localized: "It's \(Int(minTemperature))°F", comment: "Preview notification body temperature clause for an exact temperature reminder")

        return String(localized: "\(tempDesc) and \(skyConditionDescription.lowercased()), ideal for your \(displayTitle.lowercased()) reminder.", comment: "Full preview notification body combining temperature and sky condition")
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
            return String(localized: "Current Location", comment: "Location label shown when using the device's current location")
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
            return String(localized: "Temperature Range", comment: "Weather condition type option label")
        case .exactTemperature:
            return String(localized: "Exact Temperature", comment: "Weather condition type option label")
        case .sunny:
            return String(localized: "Sunny", comment: "Weather condition type option label")
        case .partlyCloudy:
            return String(localized: "Partly Cloudy", comment: "Weather condition type option label")
        case .rainy:
            return String(localized: "No Rain", comment: "Weather condition type option label")
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
        case .sunny: return String(localized: "Sunny", comment: "Sky condition option label")
        case .partlyCloudy: return String(localized: "Partly Cloudy", comment: "Sky condition option label")
        case .cloudy: return String(localized: "Cloudy", comment: "Sky condition option label")
        case .rainy: return String(localized: "Rainy", comment: "Sky condition option label")
        case .snowy: return String(localized: "Snowy", comment: "Sky condition option label")
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
        case .temperatureRange: return String(localized: "Temperature Range", comment: "Temperature condition type option label")
        case .exactTemperature: return String(localized: "Exact Temperature", comment: "Temperature condition type option label")
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
    
    nonisolated var displayName: String {
        switch self {
        case .morning:
            return String(localized: "Morning", comment: "Time-of-day preference option label")
        case .afternoon:
            return String(localized: "Afternoon", comment: "Time-of-day preference option label")
        case .evening:
            return String(localized: "Evening", comment: "Time-of-day preference option label")
        case .allDay:
            return String(localized: "All Day", comment: "Time-of-day preference option label")
        }
    }

    nonisolated var icon: String {
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

    nonisolated var hours: ClosedRange<Int> {
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
        date.formatted(.dateTime.month(.defaultDigits).day())
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
