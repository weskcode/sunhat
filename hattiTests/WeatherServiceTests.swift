//
//  WeatherServiceTests.swift
//  hattiTests
//
//  Created by Wesley Keetch on 7/20/25.
//

import XCTest
import SwiftData
import CoreLocation
@testable import hatti

final class WeatherServiceTests: XCTestCase {
    var weatherService: WeatherService!
    var modelContext: ModelContext!
    var testLocation: CLLocation!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            WeatherData.self,
            LocationData.self,
            ForecastDay.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(container)
        
        weatherService = WeatherService.shared
        await weatherService.configure(modelContext: modelContext, openWeatherMapKey: "test-api-key")
        
        // Test location (San Francisco)
        testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    
    override func tearDown() async throws {
        weatherService = nil
        modelContext = nil
        testLocation = nil
        try await super.tearDown()
    }
    
    @MainActor
    func testWeatherServiceConfiguration() async throws {
        // Test that the service is properly configured
        XCTAssertNotNil(weatherService)
        
        // Test configuration manager
        let configManager = WeatherServiceManager.shared
        XCTAssertNotNil(configManager.configuration)
        XCTAssertEqual(configManager.configuration.enabledProviders.count, 2)
    }
    
    func testWeatherErrorTypes() {
        // Test various error types
        let networkError = WeatherError.networkUnavailable
        XCTAssertEqual(networkError.errorDescription, "Network connection unavailable")
        XCTAssertNotNil(networkError.failureReason)
        XCTAssertNotNil(networkError.recoverySuggestion)
        
        let rateLimitError = WeatherError.rateLimitExceeded(retryAfter: 60)
        XCTAssertTrue(rateLimitError.errorDescription?.contains("60 seconds") ?? false)
        
        let providerError = WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        XCTAssertTrue(providerError.errorDescription?.contains("Apple WeatherKit") ?? false)
    }
    
    func testWeatherDataModel() throws {
        // Test WeatherData creation and validation
        let weatherData = WeatherData(
            temperature: 72.5,
            feelsLike: 74.0,
            humidity: 65
        )
        
        XCTAssertEqual(weatherData.temperature, 72.5)
        XCTAssertEqual(weatherData.feelsLike, 74.0)
        XCTAssertEqual(weatherData.humidity, 65)
        XCTAssertFalse(weatherData.isExpired)
        XCTAssertFalse(weatherData.isFreezingTemperature)
    }
    
    func testLocationDataModel() throws {
        // Test LocationData creation
        let locationData = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco",
            timeZoneIdentifier: "America/Los_Angeles"
        )
        
        XCTAssertEqual(locationData.latitude, 37.7749)
        XCTAssertEqual(locationData.longitude, -122.4194)
        XCTAssertEqual(locationData.city, "San Francisco")
        XCTAssertEqual(locationData.displayName, "San Francisco")
        
        // Test distance calculation
        let otherLocation = LocationData(latitude: 37.7849, longitude: -122.4094)
        let distance = locationData.distance(from: otherLocation)
        XCTAssertGreaterThan(distance, 0)
    }
    
    func testTriggerConditionEvaluation() throws {
        // Test temperature trigger evaluation
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )
        
        let weatherData = WeatherData(
            temperature: 75.0,
            feelsLike: 75.0,
            humidity: 50
        )
        
        XCTAssertTrue(weatherData.evaluateCondition(condition))
        
        // Test below threshold
        weatherData.temperature = 65.0
        XCTAssertFalse(weatherData.evaluateCondition(condition))
    }
    
    func testForecastDayModel() throws {
        // Test ForecastDay creation
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let forecastDay = ForecastDay(
            date: tomorrow,
            highTemperature: 80.0,
            lowTemperature: 60.0,
            weatherCondition: .partlyCloudy
        )
        
        XCTAssertEqual(forecastDay.highTemperature, 80.0)
        XCTAssertEqual(forecastDay.lowTemperature, 60.0)
        XCTAssertEqual(forecastDay.averageTemperature, 70.0)
        XCTAssertEqual(forecastDay.weatherCondition, .partlyCloudy)
        XCTAssertNotNil(forecastDay.dayOfWeek)
    }
    
    func testWeatherProviderEnum() {
        // Test provider enumeration
        let appleProvider = WeatherProvider.appleWeatherKit
        let openWeatherProvider = WeatherProvider.openWeatherMap
        
        XCTAssertEqual(appleProvider.displayName, "Apple WeatherKit")
        XCTAssertEqual(openWeatherProvider.displayName, "OpenWeatherMap")
        XCTAssertLessThan(appleProvider.priority, openWeatherProvider.priority)
        
        let allProviders = WeatherProvider.allCases
        XCTAssertEqual(allProviders.count, 2)
    }
    
    func testWeatherConditionMapping() {
        // Test weather condition enum
        let conditions: [WeatherCondition] = [.clear, .partlyCloudy, .rain, .snow, .thunderstorm]
        
        for condition in conditions {
            XCTAssertFalse(condition.rawValue.isEmpty)
        }
        
        XCTAssertEqual(WeatherCondition.clear.rawValue, "clear")
        XCTAssertEqual(WeatherCondition.partlyCloudy.rawValue, "partly_cloudy")
    }
    
    func testReminderCategoryEnum() {
        // Test reminder categories
        let categories = ReminderCategory.allCases
        XCTAssertGreaterThan(categories.count, 5)
        
        let outdoorCategory = ReminderCategory.outdoor
        XCTAssertEqual(outdoorCategory.displayName, "Outdoor Activities")
        XCTAssertEqual(outdoorCategory.iconName, "figure.hiking")
        
        let gardeningCategory = ReminderCategory.gardening
        XCTAssertEqual(gardeningCategory.displayName, "Gardening")
        XCTAssertEqual(gardeningCategory.iconName, "leaf")
    }
    
    func testConfigurationValidation() {
        // Test configuration validation
        let manager = WeatherServiceManager.shared
        
        let validConfig = WeatherServiceConfiguration(
            openWeatherMapAPIKey: "valid-api-key-123456789",
            enabledProviders: [.appleWeatherKit, .openWeatherMap]
        )
        
        manager.configuration = validConfig
        let errors = manager.validateConfiguration()
        XCTAssertTrue(errors.isEmpty)
        
        let invalidConfig = WeatherServiceConfiguration(
            openWeatherMapAPIKey: "",
            enabledProviders: []
        )
        
        manager.configuration = invalidConfig
        let invalidErrors = manager.validateConfiguration()
        XCTAssertFalse(invalidErrors.isEmpty)
    }
    
    @MainActor
    func testCacheExpiration() async throws {
        // Test cache expiration logic
        let weatherData = WeatherData(
            temperature: 70.0,
            feelsLike: 70.0,
            humidity: 50
        )
        
        // Set expiration to past date
        weatherData.expiresAt = Calendar.current.date(byAdding: .minute, value: -30, to: Date())
        
        XCTAssertTrue(weatherData.isExpired)
        
        // Set expiration to future date
        weatherData.expiresAt = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
        
        XCTAssertFalse(weatherData.isExpired)
    }
    
    func testTemperatureComparisons() {
        // Test temperature-related calculations
        let weatherData = WeatherData(
            temperature: 32.0,
            feelsLike: 30.0,
            humidity: 80
        )
        
        XCTAssertTrue(weatherData.isFreezingTemperature)
        
        weatherData.temperature = 72.0
        XCTAssertFalse(weatherData.isFreezingTemperature)
        
        // Test apparent temperature
        weatherData.windChill = 25.0
        weatherData.temperature = 35.0
        XCTAssertEqual(weatherData.apparentTemperature, 25.0) // Should use wind chill for cold temps
        
        weatherData.heatIndex = 85.0
        weatherData.temperature = 82.0
        weatherData.windChill = nil
        XCTAssertEqual(weatherData.apparentTemperature, 85.0) // Should use heat index for hot temps
    }
    
    func testPerformanceWeatherDataCreation() {
        measure {
            for _ in 0..<1000 {
                let _ = WeatherData(
                    temperature: Double.random(in: -20...120),
                    feelsLike: Double.random(in: -20...120),
                    humidity: Int.random(in: 0...100)
                )
            }
        }
    }
}

// MARK: - Mock Weather API for Testing

class MockWeatherAPI: WeatherAPI {
    let provider: WeatherProvider = .openWeatherMap
    
    var shouldFail = false
    var mockWeatherData: WeatherData?
    var mockForecast: [ForecastDay] = []
    
    var isAvailable: Bool {
        get async { !shouldFail }
    }
    
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherData {
        if shouldFail {
            throw WeatherError.serviceUnavailable(provider: provider)
        }
        
        return mockWeatherData ?? WeatherData(
            temperature: 72.0,
            feelsLike: 74.0,
            humidity: 60
        )
    }
    
    func fetchForecast(for location: CLLocation, days: Int) async throws -> [ForecastDay] {
        if shouldFail {
            throw WeatherError.serviceUnavailable(provider: provider)
        }
        
        return mockForecast
    }
    
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherData {
        let current = try await fetchCurrentWeather(for: location)
        let forecast = try await fetchForecast(for: location, days: 7)
        current.forecastDays = forecast
        return current
    }
}