//
//  WeatherViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import Combine
import os.log

@MainActor
final class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var currentLocationName = "Loading location..."
    
    // Current weather data
    @Published var currentTemperature: Double = 0
    @Published var feelsLikeTemperature: Double = 0
    @Published var weatherDescription = "Clear"
    @Published var weatherIconName = "sun.max.fill"
    @Published var weatherIconColor: Color = .orange
    @Published var highTemperature: Double = 0
    @Published var lowTemperature: Double = 0
    
    // Detailed metrics
    @Published var humidity: Int = 0
    @Published var windSpeed: Double = 0
    @Published var windDirection = "N"
    @Published var windGust: Double = 0
    @Published var visibility: Double = 0
    @Published var pressure: Double = 0
    @Published var uvIndex: Double = 0
    @Published var dewPoint: Double = 0
    
    // Air quality and sun data
    @Published var airQualityIndex: Int = 0
    @Published var pm25: Double = 0
    @Published var sunrise: Date?
    @Published var sunset: Date?
    @Published var dayLength: TimeInterval?
    
    // Historical comparison
    @Published var yesterdayTemperature: Double = 0
    @Published var lastWeekTemperature: Double = 0
    @Published var historicalAverageTemperature: Double = 0
    
    // Forecast data
    @Published var hourlyForecast: [HourlyWeatherData] = []
    @Published var weeklyForecast: [DailyWeatherData] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var triggerPredictions: [TriggerPrediction] = []
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private let weatherService = WeatherService.shared
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "WeatherViewModel")
    private var cancellables = Set<AnyCancellable>()
    private var currentLocation: CLLocation?
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        Task {
            await weatherService.configure(modelContext: modelContext)
            await loadInitialData()
        }
    }
    
    // MARK: - Private Setup
    
    private func setupBindings() {
        // Observe weather service loading state
        weatherService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        weatherService.$lastUpdateTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastUpdateTime, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func refreshWeatherData() async {
        logger.debug("Refreshing weather data")
        
        guard let location = await getCurrentLocation() else {
            logger.warning("No location available for weather refresh")
            return
        }
        
        await loadWeatherData(for: location, forceRefresh: true)
    }
    
    // MARK: - Private Data Loading
    
    private func loadInitialData() async {
        guard let location = await getCurrentLocation() else {
            logger.warning("No location available for initial data load")
            return
        }
        
        await loadWeatherData(for: location, forceRefresh: false)
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        // In a real app, this would integrate with LocationPermissionManager
        // For now, return a default location (could be user's saved location)
        if let currentLocation = currentLocation {
            return currentLocation
        }
        
        // Default to a sample location (could be from user preferences)
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        currentLocation = defaultLocation
        currentLocationName = "San Francisco, CA"
        
        return defaultLocation
    }
    
    private func loadWeatherData(for location: CLLocation, forceRefresh: Bool) async {
        do {
            let weatherData = try await weatherService.fetchCurrentWeather(for: location, forceRefresh: forceRefresh)
            
            await updateCurrentWeatherData(weatherData)
            await loadForecastData(for: location)
            await loadHistoricalData(for: location)
            await loadTriggerPredictions(for: location, with: weatherData)
            
            logger.info("Successfully loaded weather data for location: \(location.coordinate)")
            
        } catch {
            logger.error("Failed to load weather data: \(error.localizedDescription)")
            await handleWeatherDataError(error)
        }
    }
    
    private func updateCurrentWeatherData(_ weatherData: WeatherData) async {
        currentTemperature = weatherData.temperature
        feelsLikeTemperature = weatherData.apparentTemperature
        weatherDescription = weatherData.weatherDescription.isEmpty ? weatherData.weatherCondition.rawValue.capitalized : weatherData.weatherDescription
        
        // Set weather icon based on condition
        (weatherIconName, weatherIconColor) = getWeatherIconAndColor(for: weatherData.weatherCondition)
        
        // Update detailed metrics
        humidity = weatherData.humidity
        windSpeed = weatherData.windSpeed
        windDirection = weatherData.windDirectionCardinal
        windGust = weatherData.windGust ?? 0
        visibility = weatherData.visibility
        pressure = weatherData.pressure
        uvIndex = weatherData.uvIndex
        dewPoint = weatherData.dewPoint
        
        // Air quality data
        airQualityIndex = weatherData.airQualityIndex ?? 0
        pm25 = weatherData.pm25 ?? 0
        
        // Sun data
        sunrise = weatherData.sunrise
        sunset = weatherData.sunset
        dayLength = weatherData.dayLength
        
        // Set high/low from forecast if available
        if let todayForecast = weatherData.forecastDays.first {
            highTemperature = todayForecast.highTemperature
            lowTemperature = todayForecast.lowTemperature
        } else {
            // Estimate from current temperature
            highTemperature = currentTemperature + 5
            lowTemperature = currentTemperature - 8
        }
    }
    
    private func loadForecastData(for location: CLLocation) async {
        // Load hourly forecast for next 24 hours
        await loadHourlyForecast(for: location)
        
        // Load weekly forecast
        await loadWeeklyForecast(for: location)
        
        // Load weather alerts
        await loadWeatherAlerts(for: location)
    }
    
    private func loadHourlyForecast(for location: CLLocation) async {
        // In a real implementation, this would fetch hourly forecast data
        // For now, generate sample data based on current conditions
        
        var forecast: [HourlyWeatherData] = []
        let currentHour = Calendar.current.dateInterval(of: .hour, for: Date())?.start ?? Date()
        
        for i in 0..<24 {
            guard let hour = Calendar.current.date(byAdding: .hour, value: i, to: currentHour) else { continue }
            
            // Simulate temperature variation throughout the day
            let tempVariation = sin(Double(i) * .pi / 12) * 10 // ±10 degree variation
            let hourlyTemp = currentTemperature + tempVariation
            
            let hourData = HourlyWeatherData(
                hour: hour,
                temperature: hourlyTemp,
                condition: weatherDescription,
                iconName: weatherIconName,
                iconColor: weatherIconColor,
                precipitationProbability: max(0, humidity - 50) // Simple precipitation estimate
            )
            
            forecast.append(hourData)
        }
        
        hourlyForecast = forecast
    }
    
    private func loadWeeklyForecast(for location: CLLocation) async {
        guard let modelContext = modelContext else { return }
        
        // Try to load existing forecast data from SwiftData
        let descriptor = FetchDescriptor<ForecastDay>(
            sortBy: [SortDescriptor(\ForecastDay.date)]
        )
        
        do {
            let forecastDays = try modelContext.fetch(descriptor)
            
            var weeklyData: [DailyWeatherData] = []
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            for i in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: i, to: today) else { continue }
                
                // Find existing forecast for this date or create sample data
                if let existingForecast = forecastDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    let dayData = DailyWeatherData(
                        date: date,
                        dayOfWeek: getDayOfWeekLabel(for: date),
                        condition: existingForecast.weatherDescription,
                        iconName: getWeatherIconName(for: existingForecast.weatherCondition),
                        iconColor: getWeatherIconColor(for: existingForecast.weatherCondition),
                        highTemp: existingForecast.highTemperature,
                        lowTemp: existingForecast.lowTemperature,
                        precipitationProbability: existingForecast.precipitationProbability
                    )
                    weeklyData.append(dayData)
                } else {
                    // Generate sample forecast data
                    let tempVariation = Double.random(in: -15...15)
                    let dayData = DailyWeatherData(
                        date: date,
                        dayOfWeek: getDayOfWeekLabel(for: date),
                        condition: weatherDescription,
                        iconName: weatherIconName,
                        iconColor: weatherIconColor,
                        highTemp: currentTemperature + tempVariation + 5,
                        lowTemp: currentTemperature + tempVariation - 8,
                        precipitationProbability: Int.random(in: 0...40)
                    )
                    weeklyData.append(dayData)
                }
            }
            
            weeklyForecast = weeklyData
            
        } catch {
            logger.error("Failed to load forecast data: \(error)")
        }
    }
    
    private func loadWeatherAlerts(for location: CLLocation) async {
        // In a real implementation, this would fetch current weather alerts
        // For demonstration, we'll create sample alerts based on conditions
        
        var alerts: [WeatherAlert] = []
        
        // Example: High temperature alert
        if currentTemperature > 95 {
            let alert = WeatherAlert(
                id: UUID(),
                title: "Excessive Heat Warning",
                description: "Dangerously hot conditions with temperatures exceeding 95°F. Limit outdoor activities and stay hydrated.",
                severity: .warning,
                area: "Local Area",
                instructions: "Drink plenty of water, wear light clothing, and avoid prolonged sun exposure.",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 8, to: Date())
            )
            alerts.append(alert)
        }
        
        // Example: High UV alert
        if uvIndex > 8 {
            let alert = WeatherAlert(
                id: UUID(),
                title: "High UV Index",
                description: "Very high UV levels detected. Unprotected skin can burn in less than 15 minutes.",
                severity: .advisory,
                area: "Local Area",
                instructions: "Use sunscreen SPF 30+, wear protective clothing, and seek shade during peak hours.",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: Date())
            )
            alerts.append(alert)
        }
        
        weatherAlerts = alerts
    }
    
    private func loadHistoricalData(for location: CLLocation) async {
        guard let modelContext = modelContext else { return }
        
        let calendar = Calendar.current
        
        // Load yesterday's temperature
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
            yesterdayTemperature = await getHistoricalTemperature(for: yesterday, at: location) ?? (currentTemperature - Double.random(in: -10...10))
        }
        
        // Load last week's temperature
        if let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date()) {
            lastWeekTemperature = await getHistoricalTemperature(for: lastWeek, at: location) ?? (currentTemperature - Double.random(in: -15...15))
        }
        
        // Load historical average for this date
        historicalAverageTemperature = await getHistoricalAverage(for: Date(), at: location) ?? currentTemperature
    }
    
    private func loadTriggerPredictions(for location: CLLocation, with weatherData: WeatherData) async {
        guard let modelContext = modelContext else { return }
        
        // Fetch active reminders
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isCurrentlyActive && reminder.triggerCondition != nil
            }
        )
        
        do {
            let activeReminders = try modelContext.fetch(descriptor)
            var predictions: [TriggerPrediction] = []
            
            for reminder in activeReminders {
                if let prediction = await createTriggerPrediction(for: reminder, with: weatherData) {
                    predictions.append(prediction)
                }
            }
            
            // Sort by likelihood (highest first)
            triggerPredictions = predictions.sorted { $0.likelihood > $1.likelihood }
            
        } catch {
            logger.error("Failed to load trigger predictions: \(error)")
        }
    }
    
    private func createTriggerPrediction(for reminder: WeatherReminder, with weatherData: WeatherData) async -> TriggerPrediction? {
        guard let condition = reminder.triggerCondition else { return nil }
        
        // Calculate likelihood based on current conditions and forecast
        let likelihood = calculateTriggerLikelihood(condition: condition, weatherData: weatherData)
        
        // Estimate trigger time based on forecast trends
        let estimatedTime = await estimateTriggerTime(condition: condition, currentWeather: weatherData)
        
        return TriggerPrediction(
            reminderId: reminder.id,
            reminderTitle: reminder.displayTitle,
            reminderIcon: reminder.category.iconName,
            conditionDescription: formatConditionDescription(condition),
            currentTemperature: weatherData.temperature,
            targetTemperature: condition.targetTemperature,
            likelihood: likelihood,
            estimatedTriggerTime: estimatedTime
        )
    }
    
    private func calculateTriggerLikelihood(condition: TriggerCondition, weatherData: WeatherData) -> Double {
        // Simple likelihood calculation based on temperature difference
        let currentTemp = condition.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
        let targetTemp = condition.targetTemperature
        let difference = abs(currentTemp - targetTemp)
        
        // Calculate likelihood based on how close we are to the target
        switch condition.comparisonType {
        case .above:
            if currentTemp > targetTemp {
                return 1.0 // Already triggered
            } else {
                // Likelihood increases as we get closer to target
                return max(0.0, 1.0 - (difference / 20.0))
            }
            
        case .below:
            if currentTemp < targetTemp {
                return 1.0 // Already triggered
            } else {
                return max(0.0, 1.0 - (difference / 20.0))
            }
            
        case .equals:
            let tolerance = condition.temperatureTolerance
            if difference <= tolerance {
                return 1.0 // Already triggered
            } else {
                return max(0.0, 1.0 - ((difference - tolerance) / 10.0))
            }
            
        case .between:
            guard let minTemp = condition.minTemperature,
                  let maxTemp = condition.maxTemperature else { return 0.0 }
            
            if currentTemp >= minTemp && currentTemp <= maxTemp {
                return 1.0 // Already triggered
            } else {
                let distanceToRange = min(abs(currentTemp - minTemp), abs(currentTemp - maxTemp))
                return max(0.0, 1.0 - (distanceToRange / 15.0))
            }
        }
    }
    
    private func estimateTriggerTime(condition: TriggerCondition, currentWeather: WeatherData) async -> Date? {
        // Simple estimation based on daily temperature patterns
        // In a real app, this would use sophisticated forecast analysis
        
        let currentTemp = condition.useFeelsLike ? currentWeather.apparentTemperature : currentWeather.temperature
        let targetTemp = condition.targetTemperature
        
        let calendar = Calendar.current
        let now = Date()
        
        // If already triggered, return nil
        if currentWeather.evaluateCondition(condition) {
            return nil
        }
        
        // Estimate based on typical daily temperature patterns
        switch condition.comparisonType {
        case .above:
            if currentTemp < targetTemp {
                // Temperature typically peaks in afternoon
                if let afternoon = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now),
                   afternoon > now {
                    return afternoon
                } else {
                    // Tomorrow afternoon
                    return calendar.date(byAdding: .day, value: 1, to: afternoon)
                }
            }
            
        case .below:
            if currentTemp > targetTemp {
                // Temperature typically lowest in early morning
                if let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now),
                   morning > now {
                    return morning
                } else {
                    // Tomorrow morning
                    return calendar.date(byAdding: .day, value: 1, to: morning)
                }
            }
            
        default:
            break
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func handleWeatherDataError(_ error: Error) async {
        // Handle errors gracefully - maybe show cached data or default values
        logger.error("Weather data error: \(error.localizedDescription)")
        
        // Try to load cached data
        if let location = currentLocation,
           let cachedData = await weatherService.getCachedWeatherData(for: location) {
            await updateCurrentWeatherData(cachedData)
        }
    }
    
    private func getHistoricalTemperature(for date: Date, at location: CLLocation) async -> Double? {
        guard let modelContext = modelContext else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = #Predicate<WeatherData> { weather in
            weather.timestamp >= startOfDay && weather.timestamp < endOfDay
        }
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .reverse)]
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first?.temperature
        } catch {
            logger.error("Failed to fetch historical temperature: \(error)")
            return nil
        }
    }
    
    private func getHistoricalAverage(for date: Date, at location: CLLocation) async -> Double? {
        // In a real app, this would calculate average temperature for this date over multiple years
        // For now, return a reasonable estimate
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        
        // Rough seasonal averages (for temperate climate)
        switch month {
        case 12, 1, 2: return 35 // Winter
        case 3, 4, 5: return 55 // Spring
        case 6, 7, 8: return 75 // Summer
        case 9, 10, 11: return 60 // Fall
        default: return 60
        }
    }
    
    private func getWeatherIconAndColor(for condition: WeatherCondition) -> (String, Color) {
        switch condition {
        case .clear:
            return ("sun.max.fill", .orange)
        case .partlyCloudy:
            return ("cloud.sun.fill", .yellow)
        case .cloudy, .overcast:
            return ("cloud.fill", .gray)
        case .rain, .lightRain:
            return ("cloud.rain.fill", .blue)
        case .heavyRain:
            return ("cloud.heavyrain.fill", .blue)
        case .thunderstorm:
            return ("cloud.bolt.rain.fill", .purple)
        case .snow, .lightSnow:
            return ("cloud.snow.fill", .cyan)
        case .heavySnow:
            return ("cloud.heavyrain.fill", .cyan)
        case .fog, .mist:
            return ("cloud.fog.fill", .gray)
        default:
            return ("questionmark.circle.fill", .gray)
        }
    }
    
    private func getWeatherIconName(for condition: WeatherCondition) -> String {
        return getWeatherIconAndColor(for: condition).0
    }
    
    private func getWeatherIconColor(for condition: WeatherCondition) -> Color {
        return getWeatherIconAndColor(for: condition).1
    }
    
    private func getDayOfWeekLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
    
    private func formatConditionDescription(_ condition: TriggerCondition) -> String {
        switch condition.comparisonType {
        case .above:
            return "When temp > \(condition.targetTemperature, specifier: "%.0f")°"
        case .below:
            return "When temp < \(condition.targetTemperature, specifier: "%.0f")°"
        case .equals:
            return "When temp ≈ \(condition.targetTemperature, specifier: "%.0f")°"
        case .between:
            if let min = condition.minTemperature, let max = condition.maxTemperature {
                return "When temp \(min, specifier: "%.0f")°-\(max, specifier: "%.0f")°"
            }
            return "Temperature range"
        }
    }
}