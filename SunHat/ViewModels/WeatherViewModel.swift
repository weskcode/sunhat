//
//  WeatherViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

//
//  WeatherViewModel.swift
//  SunHat
//
//  Refactored by ChatGPT
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import Combine
import os

// MARK: - WeatherCondition Icon & Color Extension
extension WeatherCondition {
    var iconName: String {
        switch self {
        case .clear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy, .overcast:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .fog:
            return "cloud.fog.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .clear:
            return .orange
        case .partlyCloudy:
            return .yellow
        case .cloudy, .overcast:
            return .gray
        case .rain, .thunderstorm:
            return .blue
        case .snow:
            return .cyan
        case .fog:
            return .gray
        default:
            return .gray
        }
    }
}

// MARK: - LocationManaging Protocol
protocol LocationManaging {
    func currentLocation() async -> (location: CLLocation, name: String)?
}

// MARK: - LocationPermissionManager Integration
final class LocationPermissionManagerAdapter: LocationManaging {
    private let locationPermissionManager: LocationPermissionManager

    init(locationPermissionManager: LocationPermissionManager) {
        self.locationPermissionManager = locationPermissionManager
    }

    func currentLocation() async -> (location: CLLocation, name: String)? {
        // Request location permission if not already granted
        if locationPermissionManager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                locationPermissionManager.requestLocationPermission { success in
                    continuation.resume()
                }
            }
        }

        // Check if we already have a manual location set
        if let manualLocation = locationPermissionManager.manualLocation {
            let location = CLLocation(
                latitude: manualLocation.coordinate.latitude,
                longitude: manualLocation.coordinate.longitude
            )
            return (location, manualLocation.displayName)
        }

        // Check if we already have a current GPS location
        if let currentLocation = locationPermissionManager.currentLocation {
            let locationName = locationPermissionManager.getDisplayLocation()
            return (currentLocation, locationName)
        }

        // If authorized but no location yet, request and wait with timeout
        if locationPermissionManager.authorizationStatus == .authorizedWhenInUse ||
           locationPermissionManager.authorizationStatus == .authorizedAlways {
            locationPermissionManager.getCurrentLocation()

            // Poll for location with timeout (up to 10 seconds)
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(500))
                if let loc = locationPermissionManager.currentLocation {
                    let locationName = locationPermissionManager.getDisplayLocation()
                    return (loc, locationName)
                }
            }
        }

        // Final fallback: log warning and return nil rather than fake data
        let logger = Logger(subsystem: "org.wesley.sunhat", category: "LocationAdapter")
        logger.warning("Could not obtain user location — no fallback used")
        return nil
    }
}

// MARK: - Default Location Manager (Legacy — no longer uses hardcoded fallback)
final class DefaultLocationManager: LocationManaging {
    static let shared = DefaultLocationManager()
    private var cached: (CLLocation, String)?

    func currentLocation() async -> (location: CLLocation, name: String)? {
        if let loc = cached { return loc }
        // Use the shared LocationPermissionManager to get real location
        let mgr = await LocationPermissionManager.shared
        if let loc = mgr.currentLocation {
            let name = mgr.getDisplayLocation()
            cached = (loc, name)
            return cached
        }
        return nil
    }
}

@MainActor
final class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var locationName: String = "Loading location..."

    @Published var currentTemperature: Double = 0
    @Published var feelsLikeTemperature: Double = 0
    @Published var weatherDescription: String = "Clear"
    @Published var weatherIconName: String = "sun.max.fill"
    @Published var weatherIconColor: Color = .orange
    @Published var highTemperature: Double = 0
    @Published var lowTemperature: Double = 0

    @Published var humidity: Int = 0
    @Published var windSpeed: Double = 0
    @Published var windDirection: String = "N"
    @Published var windGust: Double = 0
    @Published var visibility: Double = 0
    @Published var pressure: Double = 0
    @Published var uvIndex: Double = 0
    @Published var dewPoint: Double = 0

    @Published var airQualityIndex: Int = 0
    @Published var pm25: Double = 0
    @Published var sunrise: Date?
    @Published var sunset: Date?
    @Published var dayLength: TimeInterval?

    @Published var yesterdayTemp: Double = 0
    @Published var lastWeekTemp: Double = 0
    @Published var historicalAvgTemp: Double = 0

    @Published var hourlyForecast: [HourlyWeatherData] = []
    @Published var weeklyForecast: [DailyWeatherData] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var triggerPredictions: [TriggerPrediction] = []

    // MARK: - Private Properties
    private var weatherModelActor: WeatherModelActor?
    private var weatherService: WeatherService
    private var locationManager: LocationManaging
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherVM")
    private var cancellables = Set<AnyCancellable>()
    private static let calendar = Calendar.current
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df
    }()

    // MARK: - Initialization
    init(
        modelContainer: ModelContainer,
        weatherService: WeatherService,
        locationManager: LocationManaging
    ) {
        self.weatherModelActor = WeatherModelActor(modelContainer: modelContainer)
        self.weatherService = weatherService
        self.locationManager = locationManager

        Task { @MainActor in
            bindService()
            await loadAllData(forceRefresh: false)
        }
    }

    // Convenience initializer that uses shared instances
    convenience init(modelContainer: ModelContainer) {
        let locationManager = LocationPermissionManagerAdapter(locationPermissionManager: LocationPermissionManager.shared)
        self.init(
            modelContainer: modelContainer,
            weatherService: WeatherService.shared,
            locationManager: locationManager
        )
    }

    // Initializer with LocationPermissionManager for better control
    convenience init(
        modelContainer: ModelContainer,
        locationPermissionManager: LocationPermissionManager
    ) {
        let locationManager = LocationPermissionManagerAdapter(locationPermissionManager: locationPermissionManager)
        self.init(
            modelContainer: modelContainer,
            weatherService: WeatherService.shared,
            locationManager: locationManager
        )
    }

    // MARK: - Service Bindings
    private func bindService() {
        weatherService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        weatherService.$lastUpdateTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateTime)
    }

    // MARK: - Public
    func refresh() async {
        await loadAllData(forceRefresh: true)
    }

    // MARK: - Data Loading
    private func loadAllData(forceRefresh: Bool) async {
        guard let locInfo = await locationManager.currentLocation() else {
            logger.warning("Location unavailable")
            return
        }
        locationName = locInfo.name
        do {
            isLoading = true
            let data = try await weatherService.fetchCurrentWeather(
                for: locInfo.location,
                forceRefresh: forceRefresh
            )
            updateCurrent(from: data)
            computeDayLength()
            // Run these tasks sequentially to avoid Sendable issues with WeatherData
            await loadForecasts()
            await loadHistorical()
            await loadTriggers(with: data)
            logger.info("Weather data loaded for \(locInfo.name)")
        } catch {
            logger.error("Error loading weather: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func updateCurrent(from data: WeatherData) {
        currentTemperature = data.temperature
        feelsLikeTemperature = data.apparentTemperature
        weatherDescription = data.weatherDescription.isEmpty
            ? data.weatherCondition.rawValue.capitalized
            : data.weatherDescription
        weatherIconName = data.weatherCondition.iconName
        weatherIconColor = data.weatherCondition.iconColor
        humidity = data.humidity
        windSpeed = data.windSpeed
        windDirection = data.windDirectionCardinal
        windGust = data.windGust ?? 0
        visibility = data.visibility
        pressure = data.pressure
        uvIndex = data.uvIndex
        dewPoint = data.dewPoint
        airQualityIndex = data.airQualityIndex ?? 0
        pm25 = data.pm25 ?? 0
        sunrise = data.sunrise
        sunset = data.sunset
        if let today = data.forecastDays.first {
            highTemperature = today.highTemperature
            lowTemperature = today.lowTemperature
        }
    }

    private func computeDayLength() {
        if let rise = sunrise, let set = sunset {
            dayLength = set.timeIntervalSince(rise)
        }
    }

    private func loadForecasts() async {
        await loadHourly()
        await loadWeekly()
        await loadAlerts()
    }

    private func loadHourly() async {
        var hours: [HourlyWeatherData] = []
        let now = Self.calendar.dateInterval(of: .hour, for: Date())?.start ?? Date()
        for i in 0..<24 {
            guard let dt = Self.calendar.date(byAdding: .hour, value: i, to: now) else { continue }
            let variation = sin(Double(i) * .pi / 12) * 10
            let temp = currentTemperature + variation
            hours.append(.init(
                hour: dt,
                temperature: temp,
                condition: weatherDescription,
                iconName: weatherIconName,
                iconColor: weatherIconColor,
                precipitationProbability: max(0, humidity - 50)
            ))
        }
        hourlyForecast = hours
    }

    private func loadWeekly() async {
        guard let weatherModelActor = weatherModelActor else {
            logger.error("WeatherModelActor not available")
            return
        }
        
        do {
            // Use fetchForecastData which returns [ForecastDayDisplay]
            guard let locInfo = await locationManager.currentLocation() else {
                logger.warning("No current location for forecast")
                return
            }
            let forecastDays = try await weatherModelActor.fetchForecastData(for: locInfo.location)
            var week: [DailyWeatherData] = []
            let start = Self.calendar.startOfDay(for: Date())
            
            for offset in 0..<7 {
                guard let date = Self.calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                if let ex = forecastDays.first(where: { Self.calendar.isDate($0.date, inSameDayAs: date) }) {
                    week.append(.init(
                        date: date,
                        dayOfWeek: label(for: date),
                        condition: ex.weatherDescription,
                        iconName: ex.weatherCondition.iconName,
                        iconColor: ex.weatherCondition.iconColor,
                        highTemp: ex.highTemperature,
                        lowTemp: ex.lowTemperature,
                        precipitationProbability: ex.precipitationProbability
                    ))
                } else {
                    let varTemp = Double.random(in: -15...15)
                    week.append(.init(
                        date: date,
                        dayOfWeek: label(for: date),
                        condition: weatherDescription,
                        iconName: weatherIconName,
                        iconColor: weatherIconColor,
                        highTemp: currentTemperature + varTemp + 5,
                        lowTemp: currentTemperature + varTemp - 8,
                        precipitationProbability: Int.random(in: 0...40)
                    ))
                }
            }
            weeklyForecast = week
        } catch {
            logger.error("Weekly load error: \(error)")
        }
    }

    private func loadAlerts() async {
        var alerts: [WeatherAlert] = []
        if currentTemperature > 95 {
            alerts.append(.init(
                id: .init(),
                title: "Excessive Heat Warning",
                description: "Temperatures above 95°F",
                severity: .warning,
                area: locationName,
                instructions: "Stay hydrated",
                expiresAt: Date().addingTimeInterval(8 * 3600)
            ))
        }
        if uvIndex > 8 {
            alerts.append(.init(
                id: .init(),
                title: "High UV Index",
                description: "UV > 8",
                severity: .advisory,
                area: locationName,
                instructions: "Use sunscreen",
                expiresAt: Date().addingTimeInterval(6 * 3600)
            ))
        }
        weatherAlerts = alerts
    }

    private func loadHistorical() async {
        func temp(daysAgo: Int) async -> Double {
            let date = Self.calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            return await getHistoricalTemp(for: date) ?? currentTemperature
        }
        yesterdayTemp = await temp(daysAgo: 1)
        lastWeekTemp = await temp(daysAgo: 7)
        historicalAvgTemp = await estimateSeasonalAverage()
    }

    private func loadTriggers(with data: WeatherData) async {
        guard let weatherModelActor = weatherModelActor else {
            logger.error("WeatherModelActor not available")
            return
        }
        
        do {
            let reminderDisplays = try await weatherModelActor.fetchActiveRemindersForDisplay()
            var preds: [TriggerPrediction] = []
            
            // Process reminders sequentially to avoid Sendable issues with WeatherData
            for reminder in reminderDisplays {
                let likelihood = calculateLikelihoodFromDisplay(reminder: reminder, data: data)
                let eta = await estimateTimeFromDisplay(reminder: reminder, current: data)
    
                let prediction = TriggerPrediction(
                    reminderId: reminder.id,
                    reminderTitle: reminder.title,
                    reminderIcon: reminder.category.iconName,
                    conditionDescription: formatConditionDescription(reminder.triggerCondition),
                    currentTemperature: data.temperature,
                    targetTemperature: reminder.triggerCondition?.targetTemperature ?? 70.0,
                    likelihood: likelihood,
                    estimatedTriggerTime: eta
                )
                preds.append(prediction)
            }
            triggerPredictions = preds.sorted { $0.likelihood > $1.likelihood }
        } catch {
            logger.error("Trigger load error: \(error)")
        }
    }

    // MARK: - Helpers
    private func label(for date: Date) -> String {
        if Self.calendar.isDateInToday(date) { return "Today" }
        if Self.calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return Self.dayFormatter.string(from: date)
    }

    private func calculateLikelihood(cond: TriggerCondition, data: WeatherData) -> Double {
        if data.evaluateCondition(cond) { return 1.0 }
        let current = cond.useFeelsLike ? data.apparentTemperature : data.temperature
        let diff = abs(current - cond.targetTemperature)
        switch cond.comparisonType {
        case .above, .below:
            return Swift.max(0, 1 - diff / 20)
        case .equals:
            let tol = cond.temperatureTolerance
            return diff <= tol ? 1 : Swift.max(0, 1 - (diff - tol) / 10)
        case .between:
            guard let min = cond.minTemperature, let max = cond.maxTemperature else { return 0 }
            if current >= min && current <= max { return 1 }
            let dist = Swift.min(abs(current - min), abs(current - max))
            return Swift.max(0, 1 - dist / 15)
        }
    }

    private func estimateTime(cond: TriggerCondition, current: WeatherData) async -> Date? {
        guard !current.evaluateCondition(cond) else { return nil }
        let now = Date()
        switch cond.comparisonType {
        case .above where current.temperature < cond.targetTemperature:
            return Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: now)
        case .below where current.temperature > cond.targetTemperature:
            return Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: now)
        default:
            return nil
        }
    }

    private func getHistoricalTemp(for date: Date) async -> Double? {
        guard let weatherModelActor = weatherModelActor else {
            logger.error("WeatherModelActor not available")
            return nil
        }
        
        do {
            // Fetch historical weather data for the past year to find this date
            guard let locInfo = await locationManager.currentLocation() else { return nil }

            let weatherData = try await weatherModelActor.fetchHistoricalWeatherData(for: locInfo.location, daysBack: 365)

            // Find the weather data closest to the same day/month as the target date
            let calendar = Calendar.current
            let targetDay = calendar.component(.day, from: date)
            let targetMonth = calendar.component(.month, from: date)

            let matching = weatherData.first { data in
                let dataDay = calendar.component(.day, from: data.timestamp)
                let dataMonth = calendar.component(.month, from: data.timestamp)
                return dataDay == targetDay && dataMonth == targetMonth
            }

            return matching?.temperature
        } catch {
            logger.error("Failed to fetch historical temperature: \(error)")
            return nil
        }
    }

    private func estimateSeasonalAverage() async -> Double {
        switch Self.calendar.component(.month, from: Date()) {
        case 12, 1, 2: return 35
        case 3, 4, 5: return 55
        case 6, 7, 8: return 75
        case 9, 10, 11: return 60
        default: return 60
        }
    }
    
    // MARK: - Display Calculation Helpers

    private func formatConditionDescription(_ condition: TriggerConditionData?) -> String {
        guard let condition = condition else { return "No condition set" }

        let tempStr = String(format: "%.1f°", condition.targetTemperature)

        switch condition.comparisonType {
        case .above:
            return "When temp > \(tempStr)"
        case .below:
            return "When temp < \(tempStr)"
        case .equals:
            return "When temp = \(tempStr)"
        case .between:
            if let min = condition.minTemperature, let max = condition.maxTemperature {
                return "When temp between \(String(format: "%.1f°", min)) and \(String(format: "%.1f°", max))"
            }
            return "When temp = \(tempStr)"
        }
    }

    private func calculateLikelihoodFromDisplay(reminder: WeatherReminderDisplay, data: WeatherData) -> Double {
        // Simple heuristic based on trigger condition
        guard let condition = reminder.triggerCondition else { return 0.3 }

        let targetTemp = condition.targetTemperature
        let currentTemp = data.temperature

        switch condition.comparisonType {
        case .above:
            if currentTemp > targetTemp { return 0.8 }
            return max(0.3, 0.8 * (currentTemp / targetTemp))
        case .below:
            if currentTemp < targetTemp { return 0.8 }
            return max(0.3, 0.8 * (targetTemp / currentTemp))
        case .equals:
            let diff = abs(currentTemp - targetTemp)
            return diff < 2.0 ? 0.9 : max(0.2, 0.8 * (1.0 - diff / 10.0))
        case .between:
            if let min = condition.minTemperature, let max = condition.maxTemperature {
                if currentTemp >= min && currentTemp <= max { return 0.9 }
            }
            return 0.3
        }
    }

    private func estimateTimeFromDisplay(reminder: WeatherReminderDisplay, current: WeatherData) async -> Date? {
        // Simple time estimation based on condition type
        let now = Date()
        guard let condition = reminder.triggerCondition else { return nil }

        let targetTemp = condition.targetTemperature

        if condition.comparisonType == .above && current.temperature < targetTemp {
            return Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: now)
        } else if condition.comparisonType == .below && current.temperature > targetTemp {
            return Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: now)
        }
        
        return nil
    }
}

// MARK: - WeatherReminder Description
private extension WeatherReminder {
    func formatDescription() -> String {
        guard let cond = triggerCondition else { return "" }
        switch cond.comparisonType {
        case .above:
            return String(format: "When temp > %.0f°", cond.targetTemperature)
        case .below:
            return String(format: "When temp < %.0f°", cond.targetTemperature)
        case .equals:
            return String(format: "When temp ≈ %.0f°", cond.targetTemperature)
        case .between:
            let minT = cond.minTemperature ?? 0
            let maxT = cond.maxTemperature ?? 0
            return String(format: "When temp %.0f-%.0f°", minT, maxT)
        }
    }
}


//import Foundation
//import SwiftUI
//import SwiftData
//import CoreLocation
//import Combine
//import os.log
//
//@MainActor
//final class WeatherViewModel: ObservableObject {
//    // MARK: - Published Properties
//    
//    @Published var isLoading = false
//    @Published var lastUpdateTime: Date?
//    @Published var currentLocationName = "Loading location..."
//    
//    // Current weather data
//    @Published var currentTemperature: Double = 0
//    @Published var feelsLikeTemperature: Double = 0
//    @Published var weatherDescription = "Clear"
//    @Published var weatherIconName = "sun.max.fill"
//    @Published var weatherIconColor: Color = .orange
//    @Published var highTemperature: Double = 0
//    @Published var lowTemperature: Double = 0
//    
//    // Detailed metrics
//    @Published var humidity: Int = 0
//    @Published var windSpeed: Double = 0
//    @Published var windDirection = "N"
//    @Published var windGust: Double = 0
//    @Published var visibility: Double = 0
//    @Published var pressure: Double = 0
//    @Published var uvIndex: Double = 0
//    @Published var dewPoint: Double = 0
//    
//    // Air quality and sun data
//    @Published var airQualityIndex: Int = 0
//    @Published var pm25: Double = 0
//    @Published var sunrise: Date?
//    @Published var sunset: Date?
//    @Published var dayLength: TimeInterval?
//    
//    // Historical comparison
//    @Published var yesterdayTemperature: Double = 0
//    @Published var lastWeekTemperature: Double = 0
//    @Published var historicalAverageTemperature: Double = 0
//    
//    // Forecast data
//    @Published var hourlyForecast: [HourlyWeatherData] = []
//    @Published var weeklyForecast: [DailyWeatherData] = []
//    @Published var weatherAlerts: [WeatherAlert] = []
//    @Published var triggerPredictions: [TriggerPrediction] = []
//    
//    // MARK: - Private Properties
//    
//    private var modelContext: ModelContext?
//    private let weatherService = WeatherService.shared
//    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherViewModel")
//    private var cancellables = Set<AnyCancellable>()
//    private var currentLocation: CLLocation?
//    
//    // MARK: - Initialization
//    
//    init() {
//        setupBindings()
//    }
//    
//    func configure(modelContext: ModelContext) {
//        self.modelContext = modelContext
//        
//        Task {
//            await weatherService.configure(modelContext: modelContext)
//            await loadInitialData()
//        }
//    }
//    
//    // MARK: - Private Setup
//    
//    private func setupBindings() {
//        // Observe weather service loading state
//        weatherService.$isLoading
//            .receive(on: DispatchQueue.main)
//            .assign(to: \.isLoading, on: self)
//            .store(in: &cancellables)
//        
//        weatherService.$lastUpdateTime
//            .receive(on: DispatchQueue.main)
//            .assign(to: \.lastUpdateTime, on: self)
//            .store(in: &cancellables)
//    }
//    
//    // MARK: - Public Methods
//    
//    func refreshWeatherData() async {
//        logger.debug("Refreshing weather data")
//        
//        guard let location = await getCurrentLocation() else {
//            logger.warning("No location available for weather refresh")
//            return
//        }
//        
//        await loadWeatherData(for: location, forceRefresh: true)
//    }
//    
//    // MARK: - Private Data Loading
//    
//    private func loadInitialData() async {
//        guard let location = await getCurrentLocation() else {
//            logger.warning("No location available for initial data load")
//            return
//        }
//        
//        await loadWeatherData(for: location, forceRefresh: false)
//    }
//    
//    private func getCurrentLocation() async -> CLLocation? {
//        // In a real app, this would integrate with LocationPermissionManager
//        // For now, return a default location (could be user's saved location)
//        if let currentLocation = currentLocation {
//            return currentLocation
//        }
//        
//        // Default to a sample location (could be from user preferences)
//        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
//        currentLocation = defaultLocation
//        currentLocationName = "San Francisco, CA"
//        
//        return defaultLocation
//    }
//    
//    private func loadWeatherData(for location: CLLocation, forceRefresh: Bool) async {
//        do {
//            let weatherData = try await weatherService.fetchCurrentWeather(for: location, forceRefresh: forceRefresh)
//            
//            await updateCurrentWeatherData(weatherData)
//            await loadForecastData(for: location)
//            await loadHistoricalData(for: location)
//            await loadTriggerPredictions(for: location, with: weatherData)
//            
//            logger.info("Successfully loaded weather data for location: \(location.coordinate)")
//            
//        } catch {
//            logger.error("Failed to load weather data: \(error.localizedDescription)")
//            await handleWeatherDataError(error)
//        }
//    }
//    
//    private func updateCurrentWeatherData(_ weatherData: WeatherData) async {
//        currentTemperature = weatherData.temperature
//        feelsLikeTemperature = weatherData.apparentTemperature
//        weatherDescription = weatherData.weatherDescription.isEmpty ? weatherData.weatherCondition.rawValue.capitalized : weatherData.weatherDescription
//        
//        // Set weather icon based on condition
//        (weatherIconName, weatherIconColor) = getWeatherIconAndColor(for: weatherData.weatherCondition)
//        
//        // Update detailed metrics
//        humidity = weatherData.humidity
//        windSpeed = weatherData.windSpeed
//        windDirection = weatherData.windDirectionCardinal
//        windGust = weatherData.windGust ?? 0
//        visibility = weatherData.visibility
//        pressure = weatherData.pressure
//        uvIndex = weatherData.uvIndex
//        dewPoint = weatherData.dewPoint
//        
//        // Air quality data
//        airQualityIndex = weatherData.airQualityIndex ?? 0
//        pm25 = weatherData.pm25 ?? 0
//        
//        // Sun data
//        sunrise = weatherData.sunrise
//        sunset = weatherData.sunset
//        dayLength = weatherData.dayLength
//        
//        // Set high/low from forecast if available
//        if let todayForecast = weatherData.forecastDays.first {
//            highTemperature = todayForecast.highTemperature
//            lowTemperature = todayForecast.lowTemperature
//        } else {
//            // Estimate from current temperature
//            highTemperature = currentTemperature + 5
//            lowTemperature = currentTemperature - 8
//        }
//    }
//    
//    private func loadForecastData(for location: CLLocation) async {
//        // Load hourly forecast for next 24 hours
//        await loadHourlyForecast(for: location)
//        
//        // Load weekly forecast
//        await loadWeeklyForecast(for: location)
//        
//        // Load weather alerts
//        await loadWeatherAlerts(for: location)
//    }
//    
//    private func loadHourlyForecast(for location: CLLocation) async {
//        // In a real implementation, this would fetch hourly forecast data
//        // For now, generate sample data based on current conditions
//        
//        var forecast: [HourlyWeatherData] = []
//        let currentHour = Calendar.current.dateInterval(of: .hour, for: Date())?.start ?? Date()
//        
//        for i in 0..<24 {
//            guard let hour = Calendar.current.date(byAdding: .hour, value: i, to: currentHour) else { continue }
//            
//            // Simulate temperature variation throughout the day
//            let tempVariation = sin(Double(i) * .pi / 12) * 10 // ±10 degree variation
//            let hourlyTemp = currentTemperature + tempVariation
//            
//            let hourData = HourlyWeatherData(
//                hour: hour,
//                temperature: hourlyTemp,
//                condition: weatherDescription,
//                iconName: weatherIconName,
//                iconColor: weatherIconColor,
//                precipitationProbability: max(0, humidity - 50) // Simple precipitation estimate
//            )
//            
//            forecast.append(hourData)
//        }
//        
//        hourlyForecast = forecast
//    }
//    
//    private func loadWeeklyForecast(for location: CLLocation) async {
//        guard let modelContext = modelContext else { return }
//        
//        // Try to load existing forecast data from SwiftData
//        let descriptor = FetchDescriptor<ForecastDay>(
//            sortBy: [SortDescriptor(\ForecastDay.date)]
//        )
//        
//        do {
//            let forecastDays = try modelContext.fetch(descriptor)
//            
//            var weeklyData: [DailyWeatherData] = []
//            let calendar = Calendar.current
//            let today = calendar.startOfDay(for: Date())
//            
//            for i in 0..<7 {
//                guard let date = calendar.date(byAdding: .day, value: i, to: today) else { continue }
//                
//                // Find existing forecast for this date or create sample data
//                if let existingForecast = forecastDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
//                    let dayData = DailyWeatherData(
//                        date: date,
//                        dayOfWeek: getDayOfWeekLabel(for: date),
//                        condition: existingForecast.weatherDescription,
//                        iconName: getWeatherIconName(for: existingForecast.weatherCondition),
//                        iconColor: getWeatherIconColor(for: existingForecast.weatherCondition),
//                        highTemp: existingForecast.highTemperature,
//                        lowTemp: existingForecast.lowTemperature,
//                        precipitationProbability: existingForecast.precipitationProbability
//                    )
//                    weeklyData.append(dayData)
//                } else {
//                    // Generate sample forecast data
//                    let tempVariation = Double.random(in: -15...15)
//                    let dayData = DailyWeatherData(
//                        date: date,
//                        dayOfWeek: getDayOfWeekLabel(for: date),
//                        condition: weatherDescription,
//                        iconName: weatherIconName,
//                        iconColor: weatherIconColor,
//                        highTemp: currentTemperature + tempVariation + 5,
//                        lowTemp: currentTemperature + tempVariation - 8,
//                        precipitationProbability: Int.random(in: 0...40)
//                    )
//                    weeklyData.append(dayData)
//                }
//            }
//            
//            weeklyForecast = weeklyData
//            
//        } catch {
//            logger.error("Failed to load forecast data: \(error)")
//        }
//    }
//    
//    private func loadWeatherAlerts(for location: CLLocation) async {
//        // In a real implementation, this would fetch current weather alerts
//        // For demonstration, we'll create sample alerts based on conditions
//        
//        var alerts: [WeatherAlert] = []
//        
//        // Example: High temperature alert
//        if currentTemperature > 95 {
//            let alert = WeatherAlert(
//                id: UUID(),
//                title: "Excessive Heat Warning",
//                description: "Dangerously hot conditions with temperatures exceeding 95°F. Limit outdoor activities and stay hydrated.",
//                severity: .warning,
//                area: "Local Area",
//                instructions: "Drink plenty of water, wear light clothing, and avoid prolonged sun exposure.",
//                expiresAt: Calendar.current.date(byAdding: .hour, value: 8, to: Date())
//            )
//            alerts.append(alert)
//        }
//        
//        // Example: High UV alert
//        if uvIndex > 8 {
//            let alert = WeatherAlert(
//                id: UUID(),
//                title: "High UV Index",
//                description: "Very high UV levels detected. Unprotected skin can burn in less than 15 minutes.",
//                severity: .advisory,
//                area: "Local Area",
//                instructions: "Use sunscreen SPF 30+, wear protective clothing, and seek shade during peak hours.",
//                expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: Date())
//            )
//            alerts.append(alert)
//        }
//        
//        weatherAlerts = alerts
//    }
//    
//    private func loadHistoricalData(for location: CLLocation) async {
//        guard let modelContext = modelContext else { return }
//        
//        let calendar = Calendar.current
//        
//        // Load yesterday's temperature
//        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
//            yesterdayTemperature = await getHistoricalTemperature(for: yesterday, at: location) ?? (currentTemperature - Double.random(in: -10...10))
//        }
//        
//        // Load last week's temperature
//        if let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date()) {
//            lastWeekTemperature = await getHistoricalTemperature(for: lastWeek, at: location) ?? (currentTemperature - Double.random(in: -15...15))
//        }
//        
//        // Load historical average for this date
//        historicalAverageTemperature = await getHistoricalAverage(for: Date(), at: location) ?? currentTemperature
//    }
//    
//    private func loadTriggerPredictions(for location: CLLocation, with weatherData: WeatherData) async {
//        guard let modelContext = modelContext else { return }
//        
//        // Fetch active reminders
//        let descriptor = FetchDescriptor<WeatherReminder>(
//            predicate: #Predicate { reminder in
//                reminder.isCurrentlyActive && reminder.triggerCondition != nil
//            }
//        )
//        
//        do {
//            let activeReminders = try modelContext.fetch(descriptor)
//            var predictions: [TriggerPrediction] = []
//            
//            for reminder in activeReminders {
//                if let prediction = await createTriggerPrediction(for: reminder, with: weatherData) {
//                    predictions.append(prediction)
//                }
//            }
//            
//            // Sort by likelihood (highest first)
//            triggerPredictions = predictions.sorted { $0.likelihood > $1.likelihood }
//            
//        } catch {
//            logger.error("Failed to load trigger predictions: \(error)")
//        }
//    }
//    
//    private func createTriggerPrediction(for reminder: WeatherReminder, with weatherData: WeatherData) async -> TriggerPrediction? {
//        guard let condition = reminder.triggerCondition else { return nil }
//        
//        // Calculate likelihood based on current conditions and forecast
//        let likelihood = calculateTriggerLikelihood(condition: condition, weatherData: weatherData)
//        
//        // Estimate trigger time based on forecast trends
//        let estimatedTime = await estimateTriggerTime(condition: condition, currentWeather: weatherData)
//        
//        return TriggerPrediction(
//            reminderId: reminder.id,
//            reminderTitle: reminder.displayTitle,
//            reminderIcon: reminder.category.iconName,
//            conditionDescription: formatConditionDescription(condition),
//            currentTemperature: weatherData.temperature,
//            targetTemperature: condition.targetTemperature,
//            likelihood: likelihood,
//            estimatedTriggerTime: estimatedTime
//        )
//    }
//    
//    private func calculateTriggerLikelihood(condition: TriggerCondition, weatherData: WeatherData) -> Double {
//        // Simple likelihood calculation based on temperature difference
//        let currentTemp = condition.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
//        let targetTemp = condition.targetTemperature
//        let difference = abs(currentTemp - targetTemp)
//        
//        // Calculate likelihood based on how close we are to the target
//        switch condition.comparisonType {
//        case .above:
//            if currentTemp > targetTemp {
//                return 1.0 // Already triggered
//            } else {
//                // Likelihood increases as we get closer to target
//                return max(0.0, 1.0 - (difference / 20.0))
//            }
//            
//        case .below:
//            if currentTemp < targetTemp {
//                return 1.0 // Already triggered
//            } else {
//                return max(0.0, 1.0 - (difference / 20.0))
//            }
//            
//        case .equals:
//            let tolerance = condition.temperatureTolerance
//            if difference <= tolerance {
//                return 1.0 // Already triggered
//            } else {
//                return max(0.0, 1.0 - ((difference - tolerance) / 10.0))
//            }
//            
//        case .between:
//            guard let minTemp = condition.minTemperature,
//                  let maxTemp = condition.maxTemperature else { return 0.0 }
//            
//            if currentTemp >= minTemp && currentTemp <= maxTemp {
//                return 1.0 // Already triggered
//            } else {
//                let distanceToRange = min(abs(currentTemp - minTemp), abs(currentTemp - maxTemp))
//                return max(0.0, 1.0 - (distanceToRange / 15.0))
//            }
//        }
//    }
//    
//    private func estimateTriggerTime(condition: TriggerCondition, currentWeather: WeatherData) async -> Date? {
//        // Simple estimation based on daily temperature patterns
//        // In a real app, this would use sophisticated forecast analysis
//        
//        let currentTemp = condition.useFeelsLike ? currentWeather.apparentTemperature : currentWeather.temperature
//        let targetTemp = condition.targetTemperature
//        
//        let calendar = Calendar.current
//        let now = Date()
//        
//        // If already triggered, return nil
//        if currentWeather.evaluateCondition(condition) {
//            return nil
//        }
//        
//        // Estimate based on typical daily temperature patterns
//        switch condition.comparisonType {
//        case .above:
//            if currentTemp < targetTemp {
//                // Temperature typically peaks in afternoon
//                if let afternoon = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now),
//                   afternoon > now {
//                    return afternoon
//                } else {
//                    // Tomorrow afternoon
//                    return calendar.date(byAdding: .day, value: 1, to: afternoon)
//                }
//            }
//            
//        case .below:
//            if currentTemp > targetTemp {
//                // Temperature typically lowest in early morning
//                if let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now),
//                   morning > now {
//                    return morning
//                } else {
//                    // Tomorrow morning
//                    return calendar.date(byAdding: .day, value: 1, to: morning)
//                }
//            }
//            
//        default:
//            break
//        }
//        
//        return nil
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func handleWeatherDataError(_ error: Error) async {
//        // Handle errors gracefully - maybe show cached data or default values
//        logger.error("Weather data error: \(error.localizedDescription)")
//        
//        // Try to load cached data
//        if let location = currentLocation,
//           let cachedData = await weatherService.getCachedWeatherData(for: location) {
//            await updateCurrentWeatherData(cachedData)
//        }
//    }
//    
//    private func getHistoricalTemperature(for date: Date, at location: CLLocation) async -> Double? {
//        guard let modelContext = modelContext else { return nil }
//        
//        let calendar = Calendar.current
//        let startOfDay = calendar.startOfDay(for: date)
//        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
//        
//        let predicate = #Predicate<WeatherData> { weather in
//            weather.timestamp >= startOfDay && weather.timestamp < endOfDay
//        }
//        
//        let descriptor = FetchDescriptor<WeatherData>(
//            predicate: predicate,
//            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .reverse)]
//        )
//        
//        do {
//            let results = try modelContext.fetch(descriptor)
//            return results.first?.temperature
//        } catch {
//            logger.error("Failed to fetch historical temperature: \(error)")
//            return nil
//        }
//    }
//    
//    private func getHistoricalAverage(for date: Date, at location: CLLocation) async -> Double? {
//        // In a real app, this would calculate average temperature for this date over multiple years
//        // For now, return a reasonable estimate
//        let calendar = Calendar.current
//        let month = calendar.component(.month, from: date)
//        
//        // Rough seasonal averages (for temperate climate)
//        switch month {
//        case 12, 1, 2: return 35 // Winter
//        case 3, 4, 5: return 55 // Spring
//        case 6, 7, 8: return 75 // Summer
//        case 9, 10, 11: return 60 // Fall
//        default: return 60
//        }
//    }
//    
//    private func getWeatherIconAndColor(for condition: WeatherCondition) -> (String, Color) {
//        switch condition {
//        case .clear:
//            return ("sun.max.fill", .orange)
//        case .partlyCloudy:
//            return ("cloud.sun.fill", .yellow)
//        case .cloudy, .overcast:
//            return ("cloud.fill", .gray)
//        case .rain, .lightRain:
//            return ("cloud.rain.fill", .blue)
//        case .heavyRain:
//            return ("cloud.heavyrain.fill", .blue)
//        case .thunderstorm:
//            return ("cloud.bolt.rain.fill", .purple)
//        case .snow, .lightSnow:
//            return ("cloud.snow.fill", .cyan)
//        case .heavySnow:
//            return ("cloud.heavyrain.fill", .cyan)
//        case .fog, .mist:
//            return ("cloud.fog.fill", .gray)
//        default:
//            return ("questionmark.circle.fill", .gray)
//        }
//    }
//    
//    private func getWeatherIconName(for condition: WeatherCondition) -> String {
//        return getWeatherIconAndColor(for: condition).0
//    }
//    
//    private func getWeatherIconColor(for condition: WeatherCondition) -> Color {
//        return getWeatherIconAndColor(for: condition).1
//    }
//    
//    private func getDayOfWeekLabel(for date: Date) -> String {
//        let calendar = Calendar.current
//        if calendar.isDateInToday(date) {
//            return "Today"
//        } else if calendar.isDateInTomorrow(date) {
//            return "Tomorrow"
//        } else {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "EEE"
//            return formatter.string(from: date)
//        }
//    }
//    
//    private func formatConditionDescription(_ condition: TriggerCondition) -> String {
//        switch condition.comparisonType {
//        case .above:
//            return "When temp > \(condition.targetTemperature, specifier: "%.0f")°"
//        case .below:
//            return "When temp < \(condition.targetTemperature, specifier: "%.0f")°"
//        case .equals:
//            return "When temp ≈ \(condition.targetTemperature, specifier: "%.0f")°"
//        case .between:
//            if let min = condition.minTemperature, let max = condition.maxTemperature {
//                return "When temp \(min, specifier: "%.0f")°-\(max, specifier: "%.0f")°"
//            }
//            return "Temperature range"
//        }
//    }
//}
