//
//  WeatherServiceTests.swift
//  SunHatTests
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftData
import CoreLocation
import Testing
@testable import SunHat

// MARK: - Weather Service Configuration Tests

@MainActor
struct WeatherServiceConfigurationTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
        let schema = Schema([
            WeatherData.self,
            LocationData.self,
            ForecastDay.self,
            WeatherReminder.self,
            TriggerCondition.self,
            NotificationConfig.self,
            ReminderHistory.self,
            UserPreferences.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    @Test("WeatherService singleton is not nil after configure")
    func weatherServiceConfiguration() async {
        let weatherService = WeatherService.shared
        #expect(weatherService != nil)

        await weatherService.configure(modelContainer: modelContainer, openWeatherMapKey: "test-api-key")

        let configManager = WeatherServiceManager.shared
        #expect(configManager.configuration != nil)
    }

    @Test("Valid configuration passes validation")
    func configurationValidation() {
        let manager = WeatherServiceManager.shared

        let validConfig = WeatherServiceConfiguration(
            openWeatherMapAPIKey: "valid-api-key-123456789",
            enabledProviders: [.appleWeatherKit, .openWeatherMap]
        )

        manager.configuration = validConfig
        let errors = manager.validateConfiguration()
        #expect(errors.isEmpty)

        let invalidConfig = WeatherServiceConfiguration(
            openWeatherMapAPIKey: "",
            enabledProviders: []
        )

        manager.configuration = invalidConfig
        let invalidErrors = manager.validateConfiguration()
        #expect(!invalidErrors.isEmpty)
    }
}

// MARK: - Weather Error Tests

struct WeatherErrorTests {

    @Test("Network unavailable error has correct description")
    func networkError() {
        let networkError = WeatherError.networkUnavailable
        #expect(networkError.errorDescription == "Network connection unavailable")
        #expect(networkError.failureReason != nil)
        #expect(networkError.recoverySuggestion != nil)
    }

    @Test("Rate limit error includes retry duration")
    func rateLimitError() {
        let rateLimitError = WeatherError.rateLimitExceeded(retryAfter: 60)
        let description = rateLimitError.errorDescription ?? ""
        #expect(description.contains("60 seconds"))
    }

    @Test("Provider error includes provider name")
    func providerError() {
        let providerError = WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        let description = providerError.errorDescription ?? ""
        #expect(description.contains("Apple WeatherKit"))
    }
}

// MARK: - Weather Data Model Tests

@MainActor
struct WeatherDataModelTests {

    @Test("WeatherData initializes with correct values")
    func weatherDataModel() {
        let weatherData = WeatherData(temperature: 72.5, feelsLike: 74.0, humidity: 65)

        #expect(weatherData.temperature == 72.5)
        #expect(weatherData.feelsLike == 74.0)
        #expect(weatherData.humidity == 65)
        #expect(weatherData.isExpired == false)
        #expect(weatherData.isFreezingTemperature == false)
    }

    @Test("Past expiration date marks data as expired")
    func cacheExpiration() {
        let weatherData = WeatherData(temperature: 70.0, feelsLike: 70.0, humidity: 50)

        weatherData.expiresAt = Calendar.current.date(byAdding: .minute, value: -30, to: Date())
        #expect(weatherData.isExpired == true)

        weatherData.expiresAt = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
        #expect(weatherData.isExpired == false)
    }

    @Test("Freezing detection and apparent temperature calculations")
    func temperatureComparisons() {
        let weatherData = WeatherData(temperature: 32.0, feelsLike: 30.0, humidity: 80)
        #expect(weatherData.isFreezingTemperature == true)

        weatherData.temperature = 72.0
        #expect(weatherData.isFreezingTemperature == false)

        weatherData.windChill = 25.0
        weatherData.temperature = 35.0
        #expect(weatherData.apparentTemperature == 25.0)

        weatherData.heatIndex = 85.0
        weatherData.temperature = 82.0
        weatherData.windChill = nil
        #expect(weatherData.apparentTemperature == 85.0)
    }
}

// MARK: - Location Data Model Tests

@MainActor
struct WeatherLocationDataModelTests {

    @Test("LocationData stores coordinates, city, and computes distance")
    func locationDataModel() {
        let locationData = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco",
            timeZoneIdentifier: "America/Los_Angeles"
        )

        #expect(locationData.latitude == 37.7749)
        #expect(locationData.longitude == -122.4194)
        #expect(locationData.city == "San Francisco")
        #expect(locationData.displayName == "San Francisco")

        let otherLocation = LocationData(latitude: 37.7849, longitude: -122.4094)
        let distance = locationData.distance(from: otherLocation)
        #expect(distance > 0)
    }
}

// MARK: - Trigger Condition Evaluation Tests

@MainActor
struct WeatherTriggerConditionEvaluationTests {

    @Test("Composite above evaluates correctly")
    func triggerConditionEvaluation() {
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        let weatherData = WeatherData(temperature: 75.0, feelsLike: 75.0, humidity: 50)
        #expect(weatherData.evaluateCondition(condition) == true)

        weatherData.temperature = 65.0
        #expect(weatherData.evaluateCondition(condition) == false)
    }
}

// MARK: - ForecastDay Model Tests

@MainActor
struct WeatherForecastDayModelTests {

    @Test("ForecastDay stores temps and computes average")
    func forecastDayModel() throws {
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        let forecastDay = ForecastDay(
            date: tomorrow,
            highTemperature: 80.0,
            lowTemperature: 60.0,
            weatherCondition: .partlyCloudy
        )

        #expect(forecastDay.highTemperature == 80.0)
        #expect(forecastDay.lowTemperature == 60.0)
        #expect(forecastDay.averageTemperature == 70.0)
        #expect(forecastDay.weatherCondition == .partlyCloudy)
        #expect(forecastDay.dayOfWeek != nil)
    }
}

// MARK: - Provider Enum Tests

struct WeatherProviderEnumTests {

    @Test("Provider display names and priority ordering")
    func weatherProviderEnum() {
        let appleProvider = WeatherProvider.appleWeatherKit
        let openWeatherProvider = WeatherProvider.openWeatherMap

        #expect(appleProvider.displayName == "Apple WeatherKit")
        #expect(openWeatherProvider.displayName == "OpenWeatherMap")
        #expect(appleProvider.priority < openWeatherProvider.priority)

        let allProviders = WeatherProvider.allCases
        #expect(allProviders.count == 2)
    }

    @Test(
        "Weather condition raw values are non-empty",
        arguments: [WeatherCondition.clear, .partlyCloudy, .rain, .snow, .thunderstorm]
    )
    func weatherConditionMapping(condition: WeatherCondition) {
        #expect(condition.rawValue.isEmpty == false)
    }

    @Test("Known condition raw values match expected strings")
    func knownConditionRawValues() {
        #expect(WeatherCondition.clear.rawValue == "clear")
        #expect(WeatherCondition.partlyCloudy.rawValue == "partly_cloudy")
    }
}

// MARK: - Reminder Category Tests

@MainActor
struct WeatherReminderCategoryTests {

    @Test("Reminder categories have display names and icons")
    func reminderCategoryEnum() {
        let categories = ReminderCategory.allCases
        #expect(categories.count > 5)

        let outdoorCategory = ReminderCategory.outdoor
        #expect(outdoorCategory.displayName == "Outdoor Activities")
        #expect(outdoorCategory.iconName == "figure.hiking")

        let gardeningCategory = ReminderCategory.gardening
        #expect(gardeningCategory.displayName == "Gardening")
        #expect(gardeningCategory.iconName == "leaf")
    }
}

// MARK: - Mock Weather API for Testing

import XCTest

final class MockWeatherAPI: WeatherAPI, @unchecked Sendable {
    nonisolated let provider: WeatherProvider = .openWeatherMap

    var shouldFail = false
    var mockWeatherData: WeatherDataDTO?
    var mockForecast: [ForecastDayDTO] = []

    nonisolated var isAvailable: Bool {
        get async { !shouldFail }
    }

    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherDataDTO {
        if shouldFail {
            throw WeatherError.serviceUnavailable(provider: provider)
        }

        return mockWeatherData ?? WeatherDataDTO(
            temperature: 72.0,
            feelsLike: 74.0,
            humidity: 60,
            dewPoint: 55.0,
            pressure: 30.0,
            visibility: 10.0,
            uvIndex: 5.0,
            cloudCover: 30,
            windSpeed: 10.0,
            windDirection: 180,
            precipitationAmount: 0.0,
            precipitationType: .none,
            weatherCondition: .clear,
            dataSource: .openWeatherMap,
            accuracy: .medium,
            forecast: []
        )
    }

    func fetchForecast(for location: CLLocation, days: Int) async throws -> [ForecastDayDTO] {
        if shouldFail {
            throw WeatherError.serviceUnavailable(provider: provider)
        }

        return mockForecast
    }

    func fetchWeatherData(for location: CLLocation) async throws -> WeatherDataDTO {
        let current = try await fetchCurrentWeather(for: location)
        let forecast = try await fetchForecast(for: location, days: 7)

        return WeatherDataDTO(
            temperature: current.temperature,
            feelsLike: current.feelsLike,
            humidity: current.humidity,
            dewPoint: current.dewPoint,
            pressure: current.pressure,
            visibility: current.visibility,
            uvIndex: current.uvIndex,
            cloudCover: current.cloudCover,
            windSpeed: current.windSpeed,
            windDirection: current.windDirection,
            precipitationAmount: current.precipitationAmount,
            precipitationType: current.precipitationType,
            weatherCondition: current.weatherCondition,
            dataSource: current.dataSource,
            accuracy: current.accuracy,
            forecast: forecast
        )
    }
}
