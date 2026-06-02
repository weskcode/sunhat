//
//  WeatherViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import os

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

