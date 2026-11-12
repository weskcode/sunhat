//
//  DashboardViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import CoreData
import Combine
import os

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentTemperature: Double = 0.0
    @Published var feelsLikeTemperature: Double = 0.0
    @Published var highTemperature: Double = 0.0
    @Published var lowTemperature: Double = 0.0
    @Published var humidity: Int = 0
    @Published var windSpeed: Double = 0.0
    @Published var visibility: Double = 0.0
    @Published var uvIndex: Double = 0.0
    @Published var weatherDescription: String = String(localized: "Loading...", comment: "Placeholder shown before weather data has loaded")
    @Published var weatherIconName: String = "cloud.fill"
    @Published var weatherIconColor: Color = .gray
    @Published var weatherCondition: WeatherCondition = .unknown

    @Published var currentLocationName: String = String(localized: "Unknown Location", comment: "Placeholder shown before the user's location is resolved")
    @Published var currentWeatherData: WeatherDataTransfer?
    @Published var forecastData: [ForecastDay] = []
    @Published var activeReminders: [WeatherReminderDisplay] = []
    @Published var hasWeatherData = false
    @Published private(set) var hasDailyForecast = false
    @Published private var reminderEvaluations: [TriggerEvaluationResult] = []

    var readyReminders: [WeatherReminderDisplay] {
        activeReminders.filter { reminder in
            reminderEvaluations.contains { result in
                result.reminderId == reminder.id && result.triggered &&
                    now().timeIntervalSince(result.evaluationTime) <= 15 * 60 &&
                    result.conditionData == reminder.triggerCondition &&
                    result.weatherData?.locationLatitude == reminder.location?.latitude &&
                    result.weatherData?.locationLongitude == reminder.location?.longitude
            }
        }
    }
    
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit

    var currentTemperatureDisplay: String {
        formattedTemperature(currentTemperature)
    }

    var feelsLikeTemperatureDisplay: String {
        formattedTemperature(feelsLikeTemperature)
    }

    var highTemperatureDisplay: String {
        hasDailyForecast ? formattedTemperature(highTemperature) : "--"
    }

    var lowTemperatureDisplay: String {
        hasDailyForecast ? formattedTemperature(lowTemperature) : "--"
    }

    var windSpeedDisplay: String {
        guard hasWeatherData else { return "--" }
        switch temperatureUnit {
        case .fahrenheit:
            return String(localized: "\(windSpeed.formatted(.number.precision(.fractionLength(0)))) mph", comment: "Wind speed in miles per hour")
        case .celsius:
            let kmh = windSpeed * 1.60934
            return String(localized: "\(kmh.formatted(.number.precision(.fractionLength(0)))) km/h", comment: "Wind speed in kilometers per hour")
        }
    }

    var visibilityDisplay: String {
        guard hasWeatherData else { return "--" }
        switch temperatureUnit {
        case .fahrenheit:
            return String(localized: "\(visibility.formatted(.number.precision(.fractionLength(1)))) mi", comment: "Visibility distance in miles")
        case .celsius:
            let km = visibility * 1.60934
            return String(localized: "\(km.formatted(.number.precision(.fractionLength(1)))) km", comment: "Visibility distance in kilometers")
        }
    }

    var uvIndexDisplay: String {
        hasWeatherData ? uvIndex.formatted(.number.precision(.fractionLength(0))) : "--"
    }
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var weatherModelActor: WeatherModelActor?
    private let locationManager: any LocationManaging
    private var weatherService = WeatherService.shared
    private let triggerEngineManager: TriggerEngineManager
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "DashboardViewModel")
    
    // Periodic refresh loop. A Task instead of a Timer so deinit can cancel it
    // from any thread (Task.cancel is nonisolated; Timer.invalidate is not).
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(
        triggerEngineManager: TriggerEngineManager = .shared,
        locationManager: any LocationManaging = LocationPermissionManagerAdapter(locationPermissionManager: .shared),
        now: @escaping () -> Date = Date.init
    ) {
        self.triggerEngineManager = triggerEngineManager
        self.locationManager = locationManager
        self.now = now
        setupBindings()
        loadTemperatureUnit()
    }

    deinit {
        refreshTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.weatherModelActor = WeatherModelActor(modelContainer: modelContext.container)
        loadActiveReminders()
        // init() already called loadTemperatureUnit(), but modelContext was
        // still nil then, so it silently fell back to the locale default and
        // never got a second chance to read the user's actual preference.
        loadTemperatureUnit()

        Task {
            await weatherService.configure(modelContainer: modelContext.container)
            await loadInitialData()
        }
        
        setupRefreshTimer()
    }
    
    func refreshWeatherData() async {
        logger.info("Starting weather data refresh")

        guard modelContext != nil else {
            logger.error("No model context available")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Get current location
            guard let location = await getCurrentLocation() else {
                logger.error("Location unavailable, cannot fetch weather")
                errorMessage = String(localized: "Unable to determine your location. Please check location permissions in Settings.", comment: "Dashboard error when no location can be resolved for a weather refresh")
                connectionStatus = .disconnected
                isLoading = false
                return
            }

            logger.info("Fetching weather for location: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private)")

            // Fetch weather data
            let weatherData = try await weatherService.fetchCurrentWeather(for: location, forceRefresh: true)

            // refreshWeatherData() is already isolated to @MainActor (inherited from the class),
            // so no MainActor.run hop is needed, these assignments are safe as-is.
            updateWeatherData(weatherData)
            loadActiveReminders()
            lastUpdateTime = weatherData.timestamp
            connectionStatus = Date().timeIntervalSince(weatherData.timestamp) < 15 * 60 ? .connected : .disconnected

            logger.info("Weather data refresh completed successfully")

            // Fresh weather may satisfy a reminder's condition. Evaluation
            // fetches weather per reminder location (not just this
            // dashboard's own location), so it runs as an independent task
            // rather than blocking this refresh's own isLoading state.
            Task {
                await self.triggerEngineManager.evaluateAllReminders()
            }

        } catch is CancellationError {
            // A superseded refresh is not an error; leave current state as-is.
            isLoading = false
            return
        } catch {
            errorMessage = String(localized: "Weather data unavailable: \(error.localizedDescription)", comment: "Dashboard error banner; the placeholder is the underlying error message")
            connectionStatus = .disconnected
            if !hasWeatherData {
                weatherDescription = String(localized: "Weather unavailable", comment: "Dashboard placeholder when no weather data could be loaded")
                forecastData = []
            }
            logger.error("Weather data refresh failed: \(error)")
        }

        isLoading = false
    }
    
    func weatherData(for reminder: WeatherReminderDisplay) -> WeatherDataTransfer? {
        guard let weather = currentWeatherData, let location = reminder.location else { return nil }
        let reminderLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let weatherLocation = CLLocation(latitude: weather.locationLatitude, longitude: weather.locationLongitude)
        guard reminderLocation.distance(from: weatherLocation) <= 1_000 else { return nil }
        return weather
    }

    // MARK: - Private Methods
    
    private func setupBindings() {
        // Weather service bindings, use RunLoop.main as the Combine scheduler
        // so Swift 6 can verify we're delivering on the @MainActor thread.
        weatherService.$lastUpdateTime
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.lastUpdateTime = $0 }
            .store(in: &cancellables)

        weatherService.$connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.connectionStatus = $0 }
            .store(in: &cancellables)

        triggerEngineManager.$evaluationResults
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.reminderEvaluations = $0 }
            .store(in: &cancellables)

        // Reactive updates when SwiftData model context saves.
        // SwiftData surfaces changes via NSManagedObjectContextDidSave
        // because it is backed by Core Data internally.
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadActiveReminders()
            }
            .store(in: &cancellables)
    }
    
    private func setupRefreshTimer() {
        let interval = refreshInterval
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                await self?.refreshWeatherDataIfNeeded()
            }
        }
    }
    
    private func refreshWeatherDataIfNeeded() async {
        // Retry an initial failure as well as weather older than 10 minutes.
        guard !isLoading else { return }
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) <= 600 {
            return
        }
        
        await refreshWeatherData()
    }
    
    private func loadInitialData() async {
        await refreshWeatherData()
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        // 1) Check UserPreferences for saved manual location
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<UserPreferences>()
            if let prefs = try? modelContext.fetch(descriptor).first,
               prefs.locationMode == "manual",
               prefs.manualLocationLatitude != 0 || prefs.manualLocationLongitude != 0 {
                let loc = CLLocation(latitude: prefs.manualLocationLatitude, longitude: prefs.manualLocationLongitude)
                currentLocationName = prefs.manualLocationName.isEmpty
                    ? String(localized: "Manual Location", comment: "Dashboard location label for an unnamed manually entered location")
                    : LocationDisplayFormatter.privacyPreservingName(from: prefs.manualLocationName)
                return loc
            }
        }

        if let resolved = await locationManager.currentLocation() {
            currentLocationName = resolved.name
            return resolved.location
        }
        currentLocationName = String(localized: "Location Unavailable", comment: "Dashboard location label when no location can be determined")
        return nil
    }

    @MainActor
    private func updateWeatherData(_ weatherData: WeatherData) {
        currentWeatherData = ModelDataConverter.convertWeatherData(weatherData)
        hasWeatherData = true
        currentTemperature = convertTemperature(weatherData.temperature)
        feelsLikeTemperature = convertTemperature(weatherData.feelsLike)
        humidity = weatherData.humidity
        windSpeed = weatherData.windSpeed
        visibility = weatherData.visibility
        uvIndex = weatherData.uvIndex
        weatherDescription = weatherData.weatherDescription.isEmpty
            ? weatherData.weatherCondition.displayName
            : weatherData.weatherDescription
        
        updateWeatherIcon(for: weatherData.weatherCondition)
        loadForecastData(from: weatherData)
        updateHighLowTemperatures()
    }
    
    private func updateWeatherIcon(for condition: WeatherCondition) {
        weatherCondition = condition
        let (iconName, color) = weatherIconConfig(for: condition)
        weatherIconName = iconName
        weatherIconColor = color
    }
    
    private func weatherIconConfig(for condition: WeatherCondition) -> (String, Color) {
        switch condition {
        case .clear:
            return ("sun.max.fill", .yellow)
        case .partlyCloudy:
            return ("cloud.sun.fill", .orange)
        case .cloudy:
            return ("cloud.fill", .gray)
        case .overcast:
            return ("smoke.fill", .gray)
        case .rain:
            return ("cloud.rain.fill", .blue)
        case .thunderstorm:
            return ("cloud.bolt.rain.fill", .purple)
        case .snow:
            return ("cloud.snow.fill", .white)
        case .fog:
            return ("cloud.fog.fill", .gray)
        case .sleet:
            return ("cloud.sleet.fill", .cyan)
        case .hail:
            return ("cloud.hail.fill", .white)
        default:
            return ("cloud.fill", .gray)
        }
    }
    
    private func loadForecastData(from weatherData: WeatherData) {
        forecastData = weatherData.forecastDays.sorted { $0.date < $1.date }
    }
    
    private func updateHighLowTemperatures() {
        guard let todayForecast = forecastData.first(where: { Calendar.current.isDateInToday($0.date) }) else {
            hasDailyForecast = false
            return
        }
        hasDailyForecast = true
        highTemperature = convertTemperature(todayForecast.highTemperature)
        lowTemperature = convertTemperature(todayForecast.lowTemperature)
    }

    private func loadActiveReminders() {
        guard let weatherModelActor = weatherModelActor else { 
            logger.error("WeatherModelActor not available")
            return 
        }
        
        Task {
            do {
                let reminderDisplays = try await weatherModelActor.fetchActiveRemindersForDisplay()
                
                await MainActor.run {
                    // Sort by priority first (urgent -> high -> normal -> low), then by creation date
                    self.activeReminders = reminderDisplays.sorted { first, second in
                        let firstPriorityOrder = first.priority.sortOrder
                        let secondPriorityOrder = second.priority.sortOrder
                        
                        if firstPriorityOrder != secondPriorityOrder {
                            return firstPriorityOrder < secondPriorityOrder
                        } else {
                            return first.createdDate > second.createdDate
                        }
                    }
                    logger.debug("Loaded \(self.activeReminders.count) active reminders")
                }
            } catch {
                await MainActor.run {
                    logger.error("Failed to load active reminders: \(error.localizedDescription)")
                    activeReminders = []
                }
            }
        }
    }
    
    private func loadTemperatureUnit() {
        // Load from user preferences
        guard let modelContext = modelContext else {
            temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
            return
        }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        
        do {
            let preferences = try modelContext.fetch(descriptor)
            temperatureUnit = preferences.first?.temperatureUnit ?? (Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit)
        } catch {
            temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        }
    }
    
    private func convertTemperature(_ fahrenheit: Double) -> Double {
        switch temperatureUnit {
        case .fahrenheit:
            return fahrenheit
        case .celsius:
            return (fahrenheit - 32) * 5 / 9
        }
    }

    private func formattedTemperature(_ temperature: Double) -> String {
        hasWeatherData ? temperature.formatted(.number.precision(.fractionLength(0))) : "--"
    }
}

// MARK: - CLLocationManagerDelegate
// Location delegate logic is now handled by the shared LocationPermissionManager.
// DashboardViewModel observes its published properties instead.

// Note: WeatherAlert model moved to WeatherAlert.swift for consistency
