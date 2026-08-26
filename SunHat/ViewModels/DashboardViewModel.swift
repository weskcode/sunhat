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
    @Published var weatherDescription: String = "Loading..."
    @Published var weatherIconName: String = "cloud.fill"
    @Published var weatherIconColor: Color = .gray
    @Published var weatherCondition: WeatherCondition = .unknown
    
    @Published var currentLocationName: String = "Unknown Location"
    @Published var currentWeatherData: WeatherDataTransfer?
    @Published var forecastData: [ForecastDay] = []
    @Published var activeReminders: [WeatherReminderDisplay] = []
    @Published var activeAlerts: [WeatherAlertDisplay] = []
    @Published var hasWeatherData = false
    
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
        formattedTemperature(highTemperature)
    }

    var lowTemperatureDisplay: String {
        formattedTemperature(lowTemperature)
    }

    var windSpeedDisplay: String {
        hasWeatherData ? "\(windSpeed.formatted(.number.precision(.fractionLength(0)))) mph" : "--"
    }

    var visibilityDisplay: String {
        hasWeatherData ? "\(visibility.formatted(.number.precision(.fractionLength(1)))) mi" : "--"
    }

    var uvIndexDisplay: String {
        hasWeatherData ? uvIndex.formatted(.number.precision(.fractionLength(0))) : "--"
    }
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var weatherModelActor: WeatherModelActor?
    private var locationPermissionManager = LocationPermissionManager.shared
    private var weatherService = WeatherService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "DashboardViewModel")
    
    // Timer for automatic refresh
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        loadTemperatureUnit()
    }
    
    deinit {
        // deinit is nonisolated, but we know we're on MainActor since the class is @MainActor
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
        }
    }
    
    // MARK: - Public Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.weatherModelActor = WeatherModelActor(modelContainer: modelContext.container)
        
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
            let location = await getCurrentLocation()

            // Validate location is not the (0,0) fallback
            if location.coordinate.latitude == 0 && location.coordinate.longitude == 0 {
                logger.error("Location unavailable, cannot fetch weather for (0,0)")
                errorMessage = "Unable to determine your location. Please check location permissions in Settings."
                connectionStatus = .disconnected
                isLoading = false
                return
            }

            logger.info("Fetching weather for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // Fetch weather data
            let weatherData = try await weatherService.fetchCurrentWeather(for: location, forceRefresh: true)

            // refreshWeatherData() is already isolated to @MainActor (inherited from the class),
            // so no MainActor.run hop is needed, these assignments are safe as-is.
            updateWeatherData(weatherData)
            loadActiveReminders()
            loadWeatherAlerts()
            lastUpdateTime = Date()
            connectionStatus = .connected

            logger.info("Weather data refresh completed successfully")

        } catch {
            errorMessage = "Weather data unavailable: \(error.localizedDescription)"
            connectionStatus = .disconnected
            if !hasWeatherData {
                weatherDescription = "Weather unavailable"
                activeAlerts = []
                forecastData = []
            }
            logger.error("Weather data refresh failed: \(error)")
        }

        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Weather service bindings, use RunLoop.main as the Combine scheduler
        // so Swift 6 can verify we're delivering on the @MainActor thread.
        weatherService.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)

        weatherService.$lastUpdateTime
            .receive(on: RunLoop.main)
            .assign(to: \.lastUpdateTime, on: self)
            .store(in: &cancellables)

        weatherService.$connectionStatus
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshWeatherDataIfNeeded()
            }
        }
    }
    
    private func refreshWeatherDataIfNeeded() async {
        // Only refresh if data is older than 10 minutes
        guard let lastUpdate = lastUpdateTime,
              Date().timeIntervalSince(lastUpdate) > 600 else {
            return
        }
        
        await refreshWeatherData()
    }
    
    private func loadInitialData() async {
        await refreshWeatherData()
    }
    
    private func getCurrentLocation() async -> CLLocation {
        // 1) Check UserPreferences for saved manual location
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<UserPreferences>()
            if let prefs = try? modelContext.fetch(descriptor).first,
               prefs.locationMode == "manual",
               prefs.manualLocationLatitude != 0 || prefs.manualLocationLongitude != 0 {
                let loc = CLLocation(latitude: prefs.manualLocationLatitude, longitude: prefs.manualLocationLongitude)
                currentLocationName = prefs.manualLocationName.isEmpty
                    ? "Manual Location"
                    : LocationDisplayFormatter.privacyPreservingName(from: prefs.manualLocationName)
                return loc
            }
        }

        // 2) Check if the shared manager already has a manual location
        if let manual = locationPermissionManager.manualLocation {
            let loc = CLLocation(latitude: manual.coordinate.latitude, longitude: manual.coordinate.longitude)
            currentLocationName = LocationDisplayFormatter.privacyPreservingName(from: manual.displayName)
            return loc
        }

        // 3) Check if we already have a GPS location
        if let loc = locationPermissionManager.currentLocation {
            await updateLocationName(for: loc)
            return loc
        }

        // 4) Request GPS location and wait with timeout
        if locationPermissionManager.authorizationStatus == .authorizedWhenInUse ||
           locationPermissionManager.authorizationStatus == .authorizedAlways {
            locationPermissionManager.getCurrentLocation()

            if let loc = await waitForCurrentLocation() {
                await updateLocationName(for: loc)
                return loc
            }
        }

        // 5) Last resort: request permission and wait briefly for a resulting location.
        // The system permission callback is not guaranteed in tests or edge cases, so
        // avoid waiting on an unbounded continuation here.
        if locationPermissionManager.authorizationStatus == .notDetermined {
            locationPermissionManager.requestLocationPermission { _ in }

            if let loc = await waitForCurrentLocation() {
                await updateLocationName(for: loc)
                return loc
            }
        }

        // 6) Real fallback - use last known or log warning
        logger.warning("Could not obtain location, using default")
        currentLocationName = "Location Unavailable"
        // Return a zero-coordinate so weather fetch will fail gracefully
        return CLLocation(latitude: 0, longitude: 0)
    }

    private func waitForCurrentLocation(maxAttempts: Int = 20) async -> CLLocation? {
        for _ in 0..<maxAttempts {
            try? await Task.sleep(for: .milliseconds(500))

            if let loc = locationPermissionManager.currentLocation {
                return loc
            }

            if locationPermissionManager.authorizationStatus == .denied ||
                locationPermissionManager.authorizationStatus == .restricted {
                return nil
            }
        }

        return nil
    }
    
    private func updateLocationName(for location: CLLocation) async {
        currentLocationName = await LocationDisplayFormatter.reverseGeocodedName(for: location)
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
        weatherDescription = weatherData.weatherDescription
        
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
        guard let todayForecast = forecastData.first else {
            // Use current temperature as fallback
            highTemperature = currentTemperature
            lowTemperature = currentTemperature
            return
        }
        
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
    
    /// SunHat's own threshold-based advisories derived from current conditions.
    /// These are NOT official government or WeatherKit severe-weather alerts, so
    /// titles are branded as SunHat advisories and each states its threshold.
    private func loadWeatherAlerts() {
        guard let weatherData = currentWeatherData else { return }

        var alerts: [WeatherAlertDisplay] = []

        // Temperature alerts
        if weatherData.temperature < 32 {
            alerts.append(WeatherAlertDisplay(
                id: UUID(),
                timestamp: Date(),
                title: "SunHat Frost Advisory",
                description: "Current temperature is below SunHat's 32°F advisory threshold.",
                severity: WeatherAlertSeverity.moderate,
                type: .frost,
                area: "Local Area",
                instructions: "Protect plants and pets from freezing temperatures",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: Date()),
                isActive: true
            ))
        }

        if weatherData.temperature > 95 {
            alerts.append(WeatherAlertDisplay(
                id: UUID(),
                timestamp: Date(),
                title: "SunHat Heat Advisory",
                description: "Current temperature is above SunHat's 95°F advisory threshold.",
                severity: WeatherAlertSeverity.moderate,
                type: .heat,
                area: "Local Area",
                instructions: "Stay hydrated and avoid prolonged outdoor activities",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 8, to: Date()),
                isActive: true
            ))
        }

        // Wind alerts
        if weatherData.windSpeed > 25 {
            alerts.append(WeatherAlertDisplay(
                id: UUID(),
                timestamp: Date(),
                title: "SunHat Wind Advisory",
                description: "Sustained winds are above SunHat's 25 mph advisory threshold.",
                severity: WeatherAlertSeverity.moderate,
                type: .wind,
                area: "Local Area",
                instructions: "Secure outdoor objects and avoid driving high-profile vehicles",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 4, to: Date()),
                isActive: true
            ))
        }

        // UV alerts
        if weatherData.uvIndex > 7 {
            alerts.append(WeatherAlertDisplay(
                id: UUID(),
                timestamp: Date(),
                title: "SunHat UV Advisory",
                description: "Current UV index is above SunHat's advisory threshold of 7.",
                severity: WeatherAlertSeverity.moderate,
                type: .uv,
                area: "Local Area",
                instructions: "Use SPF 30+ sunscreen, wear protective clothing, and seek shade",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: Date()),
                isActive: true
            ))
        }

        activeAlerts = alerts
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
