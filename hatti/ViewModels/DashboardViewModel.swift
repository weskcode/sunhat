//
//  DashboardViewModel.swift
//  hatti
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
final class DashboardViewModel: NSObject, ObservableObject {
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
    
    @Published var currentLocationName: String = "Unknown Location"
    @Published var currentWeatherData: WeatherDataTransfer?
    @Published var forecastData: [ForecastDay] = []
    @Published var activeReminders: [WeatherReminderDisplay] = []
    @Published var activeAlerts: [WeatherAlertDisplay] = []
    
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var weatherModelActor: WeatherModelActor?
    private var locationManager = CLLocationManager()
    private var weatherService = WeatherService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "com.hatti.app", category: "DashboardViewModel")
    
    // Timer for automatic refresh
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
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
        
        guard let modelContext = modelContext else {
            logger.error("No model context available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current location
            let location = await getCurrentLocation()
            
            // Fetch weather data
            let weatherData = try await weatherService.fetchCurrentWeather(for: location, forceRefresh: true)
            
            await MainActor.run {
                updateWeatherData(weatherData)
                loadActiveReminders()
                loadWeatherAlerts()
                lastUpdateTime = Date()
                connectionStatus = .connected
            }
            
            logger.info("Weather data refresh completed successfully")
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                connectionStatus = .disconnected
            }
            logger.error("Weather data refresh failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupBindings() {
        // Weather service bindings
        weatherService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        weatherService.$lastUpdateTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastUpdateTime, on: self)
            .store(in: &cancellables)
        
        weatherService.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // Reactive updates when active reminders change
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
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
        // First try to get last known location
        if let lastLocation = locationManager.location {
            await updateLocationName(for: lastLocation)
            return lastLocation
        }
        
        // Request location if not available
        locationManager.requestLocation()
        
        // Return default location if location services fail
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        await updateLocationName(for: defaultLocation)
        return defaultLocation
    }
    
    private func updateLocationName(for location: CLLocation) async {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let city = placemark.locality ?? ""
                let state = placemark.administrativeArea ?? ""
                currentLocationName = "\(city), \(state)"
            }
        } catch {
            logger.warning("Failed to reverse geocode location: \(error.localizedDescription)")
            currentLocationName = "Current Location"
        }
    }
    
    @MainActor
    private func updateWeatherData(_ weatherData: WeatherData) {
        currentWeatherData = ModelDataConverter.convertWeatherData(weatherData)
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
    
    private func loadWeatherAlerts() {
        // In a real implementation, this would fetch from a weather alert service
        // For now, we'll check for severe weather conditions
        guard let weatherData = currentWeatherData else { return }
        
        var alerts: [WeatherAlertDisplay] = []
        
        // Temperature alerts
        if weatherData.temperature < 32 {
            alerts.append(WeatherAlertDisplay(
                id: UUID(),
                timestamp: Date(),
                title: "Freezing Temperature Alert",
                description: "Temperature has dropped below freezing. Protect plants and pets.",
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
                title: "Extreme Heat Warning",
                description: "Temperature is dangerously high. Stay hydrated and avoid outdoor activities.",
                severity: WeatherAlertSeverity.severe,
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
                title: "High Wind Advisory",
                description: "Sustained winds exceed 25 mph. Secure outdoor objects.",
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
                title: "High UV Index",
                description: "UV index is very high. Use sun protection when outdoors.",
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
}

// MARK: - CLLocationManagerDelegate

extension DashboardViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            await updateLocationName(for: location)
            await refreshWeatherData()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed with error: \(error.localizedDescription)")
        
        // Use default location
        Task { @MainActor in
            let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
            await updateLocationName(for: defaultLocation)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            case .denied, .restricted:
                logger.warning("Location access denied")
                currentLocationName = "Location Access Denied"
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            @unknown default:
                logger.warning("Unknown location authorization status")
            }
        }
    }
}

// Note: WeatherAlert model moved to WeatherAlert.swift for consistency
