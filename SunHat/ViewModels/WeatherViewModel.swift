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
import CoreLocation
import os

@MainActor
final class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var locationName: String = String(localized: "Loading location...", comment: "Placeholder shown before the user's location is resolved")

    @Published var currentTemperature: Double = 0
    @Published var feelsLikeTemperature: Double = 0
    @Published var weatherDescription: String = String(localized: "Clear", comment: "Placeholder weather condition shown before weather data has loaded")
    @Published var weatherCondition: WeatherCondition = .unknown
    @Published var weatherIconName: String = "sun.max.fill"
    @Published var weatherIconColor: Color = .orange
    @Published var backdropPalette: WeatherBackdropPalette = .calmBlue
    @Published var hasWeatherData = false
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

    /// Historical comparison temperatures. `nil` means "not enough stored history".
    /// The UI shows an explicit unavailable state instead of a placeholder value.
    @Published var yesterdayTemp: Double?
    @Published var lastWeekTemp: Double?
    @Published var historicalAvgTemp: Double?

    @Published var hourlyForecast: [HourlyWeatherData] = []
    @Published var weeklyForecast: [DailyWeatherData] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var triggerPredictions: [TriggerPrediction] = []

    // MARK: - Private Properties
    private var weatherModelActor: WeatherModelActor?
    private var weatherService: any WeatherProviding
    private var locationManager: LocationManaging
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherVM")
    private var cancellables = Set<AnyCancellable>()
    private var selectedLocation: ReminderLocation = .currentLocation
    private var loadGeneration = 0
    private static let calendar = Calendar.current
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df
    }()

    // MARK: - Initialization

    /// Test/DI initializer: a model container is supplied up front and data loads immediately.
    init(
        modelContainer: ModelContainer,
        weatherService: any WeatherProviding,
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

    /// Production initializer for `@StateObject`. The model container is not yet
    /// available (the SwiftUI environment can't be read in a view `init`), so the
    /// owning view must call `configure(modelContainer:)` from `.task`/`.onAppear`.
    /// This avoids the previous `try! ModelContainer(...)` throwaway container that
    /// was disconnected from the app-group store.
    init(
        weatherService: any WeatherProviding = WeatherService.shared,
        locationManager: LocationManaging = LocationPermissionManagerAdapter(
            locationPermissionManager: LocationPermissionManager.shared
        )
    ) {
        self.weatherModelActor = nil
        self.weatherService = weatherService
        self.locationManager = locationManager

        Task { @MainActor in
            bindService()
        }
    }

    /// Supplies the real (shared, app-group) model container and kicks off the first load.
    /// Safe to call multiple times, only the first call wires up the actor.
    func configure(modelContainer: ModelContainer) {
        guard weatherModelActor == nil else { return }
        weatherModelActor = WeatherModelActor(modelContainer: modelContainer)
        Task { @MainActor in
            await loadAllData(forceRefresh: false)
        }
    }

    // MARK: - Service Bindings
    private func bindService() {
        weatherService.lastUpdateTimePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateTime)
    }

    // MARK: - Public
    func refresh() async {
        await loadAllData(forceRefresh: true)
    }

    func updateSelectedLocation(_ location: ReminderLocation) async {
        selectedLocation = location
        await loadAllData(forceRefresh: true)
    }

    // MARK: - Data Loading
    private func loadAllData(forceRefresh: Bool) async {
        loadGeneration += 1
        let generation = loadGeneration
        let selection = selectedLocation
        isLoading = true

        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        guard let locInfo = await resolveSelectedLocation(selection) else {
            guard generation == loadGeneration else { return }
            logger.warning("Location unavailable")
            hasWeatherData = false
            return
        }
        guard generation == loadGeneration else { return }

        locationName = locInfo.name

        do {
            let data = try await weatherService.fetchCurrentWeather(
                for: locInfo.location,
                forceRefresh: forceRefresh
            )
            guard generation == loadGeneration else { return }

            updateCurrent(from: data)
            computeDayLength()
            await loadForecasts(from: data, at: locInfo.location, generation: generation)
            await loadHistorical(at: locInfo.location, generation: generation)
            await loadTriggers(with: data, generation: generation)
            guard generation == loadGeneration else { return }
            logger.info("Weather data loaded for \(locInfo.name)")
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            logger.error("Error loading weather: \(error.localizedDescription)")
            hasWeatherData = false
        }
    }

    private func updateCurrent(from data: WeatherData) {
        currentTemperature = data.temperature
        feelsLikeTemperature = data.apparentTemperature
        weatherCondition = data.weatherCondition
        backdropPalette = WeatherBackdropPalette.palette(for: data)
        hasWeatherData = true
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

    private func resolveSelectedLocation(
        _ selection: ReminderLocation
    ) async -> (location: CLLocation, name: String)? {
        guard !selection.isCurrentLocation else {
            return await locationManager.currentLocation()
        }

        let coordinate = selection.coordinate.clCoordinate
        return (
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            LocationDisplayFormatter.privacyPreservingName(from: selection.displayName)
        )
    }

    private func computeDayLength() {
        if let rise = sunrise, let set = sunset {
            dayLength = set.timeIntervalSince(rise)
        }
    }

    private func loadForecasts(
        from weatherData: WeatherData,
        at location: CLLocation,
        generation: Int
    ) async {
        await loadHourly(at: location, generation: generation)
        guard generation == loadGeneration else { return }
        loadWeekly(from: weatherData.forecastDays)
        loadAlerts()
    }

    /// Loads the real provider hourly forecast. An empty array means the provider
    /// had no hourly data (or the fetch failed) and the UI shows an unavailable
    /// state, hours are never synthesized.
    private func loadHourly(at location: CLLocation, generation: Int) async {
        let hours = await weatherService.fetchHourlyForecast(for: location)
        guard generation == loadGeneration else { return }
        hourlyForecast = hours.map { hour in
            HourlyWeatherData(
                hour: hour.date,
                temperature: hour.temperature,
                condition: hour.weatherCondition.displayName,
                iconName: hour.weatherCondition.iconName,
                iconColor: hour.weatherCondition.iconColor,
                precipitationProbability: hour.precipitationChance
            )
        }
    }

    private func loadWeekly(from forecastDays: [ForecastDay]) {
        weeklyForecast = Self.dailyWeatherData(from: forecastDays)
    }

    /// SunHat's own threshold-based advisories. These are NOT official government or
    /// WeatherKit severe-weather alerts, so the copy is branded as a SunHat advisory
    /// and states the exact threshold that produced it.
    private func loadAlerts() {
        var alerts: [WeatherAlert] = []
        if currentTemperature > 95 {
            alerts.append(.init(
                id: .init(),
                title: String(localized: "SunHat Heat Advisory", comment: "Title of an in-app weather advisory; 'SunHat' is the app name and should not be translated"),
                description: String(localized: "Current temperature is above SunHat's 95°F advisory threshold.", comment: "In-app weather advisory description"),
                severity: .advisory,
                area: locationName,
                instructions: String(localized: "Stay hydrated and limit time outdoors", comment: "In-app weather advisory instructions"),
                expiresAt: Date().addingTimeInterval(8 * 3600)
            ))
        }
        if uvIndex > 8 {
            alerts.append(.init(
                id: .init(),
                title: String(localized: "SunHat UV Advisory", comment: "Title of an in-app weather advisory; 'SunHat' is the app name and should not be translated"),
                description: String(localized: "Current UV index (\(Int(uvIndex))) is above SunHat's advisory threshold of 8.", comment: "In-app weather advisory description"),
                severity: .advisory,
                area: locationName,
                instructions: String(localized: "Use sunscreen and seek shade midday", comment: "In-app weather advisory instructions"),
                expiresAt: Date().addingTimeInterval(6 * 3600)
            ))
        }
        weatherAlerts = alerts
    }

    /// Loads comparisons from actually stored weather history. Any value without
    /// enough stored data stays `nil`, the UI shows "Not enough history yet"
    /// rather than an invented placeholder.
    private func loadHistorical(at location: CLLocation, generation: Int) async {
        func temp(daysAgo: Int) async -> Double? {
            guard let date = Self.calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else {
                return nil
            }
            return await getHistoricalTemp(for: date, at: location)
        }

        let yesterday = await temp(daysAgo: 1)
        let lastWeek = await temp(daysAgo: 7)
        let monthlyAverage = await storedMonthlyAverage(at: location)
        guard generation == loadGeneration else { return }

        yesterdayTemp = yesterday
        lastWeekTemp = lastWeek
        historicalAvgTemp = monthlyAverage
    }

    private func loadTriggers(with data: WeatherData, generation: Int) async {
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
            guard generation == loadGeneration else { return }
            triggerPredictions = preds.sorted { $0.likelihood > $1.likelihood }
        } catch {
            logger.error("Trigger load error: \(error)")
        }
    }

    // MARK: - Helpers
    static func dailyWeatherData(from forecastDays: [ForecastDay]) -> [DailyWeatherData] {
        forecastDays
            .sorted { $0.date < $1.date }
            .prefix(7)
            .map { forecast in
                DailyWeatherData(
                    date: forecast.date,
                    dayOfWeek: label(for: forecast.date),
                    condition: forecast.weatherDescription.isEmpty
                        ? forecast.weatherCondition.displayName
                        : forecast.weatherDescription,
                    iconName: forecast.weatherCondition.iconName,
                    iconColor: forecast.weatherCondition.iconColor,
                    highTemp: forecast.highTemperature,
                    lowTemp: forecast.lowTemperature,
                    precipitationProbability: forecast.precipitationProbability
                )
            }
    }

    private static func label(for date: Date) -> String {
        if Self.calendar.isDateInToday(date) { return String(localized: "Today", comment: "Relative day label in the weekly forecast") }
        if Self.calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow", comment: "Relative day label in the weekly forecast") }
        return Self.dayFormatter.string(from: date)
    }

    private func label(for date: Date) -> String {
        Self.label(for: date)
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

    private func getHistoricalTemp(for date: Date, at location: CLLocation) async -> Double? {
        guard let weatherModelActor = weatherModelActor else {
            logger.error("WeatherModelActor not available")
            return nil
        }
        
        do {
            let weatherData = try await weatherModelActor.fetchHistoricalWeatherData(
                for: location,
                daysBack: 365
            )

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

    /// Average of stored temperatures at this location for the current month
    /// (any year). Returns `nil` when fewer than 3 samples exist, no fixed
    /// seasonal constants are ever substituted.
    private func storedMonthlyAverage(at location: CLLocation) async -> Double? {
        guard let weatherModelActor else { return nil }

        do {
            let stored = try await weatherModelActor.fetchHistoricalWeatherData(
                for: location,
                daysBack: 365
            )
            let currentMonth = Self.calendar.component(.month, from: Date())
            let samples = stored
                .filter { Self.calendar.component(.month, from: $0.timestamp) == currentMonth }
                .map(\.temperature)
            guard samples.count >= 3 else { return nil }
            return samples.reduce(0, +) / Double(samples.count)
        } catch {
            logger.error("Failed to compute stored monthly average: \(error)")
            return nil
        }
    }
    
    // MARK: - Display Calculation Helpers

    private func formatConditionDescription(_ condition: TriggerConditionData?) -> String {
        guard let condition = condition else { return String(localized: "No condition set", comment: "Trigger prediction summary when a reminder has no condition configured") }

        let tempStr = String(format: "%.1f°", condition.targetTemperature)

        switch condition.comparisonType {
        case .above:
            return String(localized: "When temp > \(tempStr)", comment: "Short trigger prediction summary; keep the '>' comparison symbol")
        case .below:
            return String(localized: "When temp < \(tempStr)", comment: "Short trigger prediction summary; keep the '<' comparison symbol")
        case .equals:
            return String(localized: "When temp = \(tempStr)", comment: "Short trigger prediction summary; keep the '=' comparison symbol")
        case .between:
            if let min = condition.minTemperature, let max = condition.maxTemperature {
                return String(localized: "When temp between \(String(format: "%.1f°", min)) and \(String(format: "%.1f°", max))", comment: "Short trigger prediction summary for a temperature range")
            }
            return String(localized: "When temp = \(tempStr)", comment: "Short trigger prediction summary; keep the '=' comparison symbol")
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
