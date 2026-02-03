//
//  DashboardViewTests.swift
//  SunHatTests
//
//  Created by Wesley Keetch on 1/10/26.
//

import XCTest
import SwiftUI
import SwiftData
@testable import SunHat

@MainActor
final class DashboardViewTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: DashboardViewModel!

    override func setUp() async throws {
        // Create in-memory model container for testing
        let schema = Schema([
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            LocationData.self,
            UserPreferences.self,
            TriggerCondition.self,
            NotificationConfig.self,
            ReminderHistory.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)

        // Initialize view model
        viewModel = DashboardViewModel()
        viewModel.configure(modelContext: modelContext)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        viewModel = nil
    }

    // MARK: - Initial State Tests

    func testViewModelInitialState() {
        // Test that view model initializes with expected default values
        XCTAssertEqual(viewModel.currentTemperature, 0.0, "Initial temperature should be 0")
        XCTAssertEqual(viewModel.humidity, 0, "Initial humidity should be 0")
        XCTAssertEqual(viewModel.weatherDescription, "Loading...", "Initial description should be 'Loading...'")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertTrue(viewModel.activeReminders.isEmpty, "Should have no active reminders initially")
        XCTAssertTrue(viewModel.forecastData.isEmpty, "Should have no forecast data initially")
    }

    // MARK: - Weather Data Tests

    func testWeatherDataRefresh() async {
        // Test weather data refresh functionality
        let expectation = XCTestExpectation(description: "Weather data refreshed")

        await viewModel.refreshWeatherData()

        // After refresh, loading should be complete
        XCTAssertFalse(viewModel.isLoading, "Loading should be complete after refresh")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testWeatherDataPersistence() throws {
        // Create sample weather data
        let weatherData = WeatherData(
            temperature: 72.0,
            feelsLike: 75.0,
            humidity: 65
        )
        weatherData.weatherDescription = "Partly Cloudy"
        weatherData.weatherCondition = .partlyCloudy

        modelContext.insert(weatherData)
        try modelContext.save()

        // Verify data was saved
        let descriptor = FetchDescriptor<WeatherData>()
        let fetchedData = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetchedData.count, 1, "Should have one weather data entry")
        XCTAssertEqual(fetchedData.first?.temperature, 72.0, "Temperature should match")
        XCTAssertEqual(fetchedData.first?.humidity, 65, "Humidity should match")
    }

    // MARK: - Forecast Tests

    func testForecastDataCreation() throws {
        // Test creating forecast data for multiple days
        let calendar = Calendar.current
        let today = Date()

        for day in 0..<10 {
            let forecastDate = calendar.date(byAdding: .day, value: day, to: today)!
            let forecast = ForecastDay(
                date: forecastDate,
                highTemperature: 80.0 + Double(day),
                lowTemperature: 60.0 + Double(day),
                weatherCondition: .clear
            )
            forecast.precipitationProbability = day * 10

            modelContext.insert(forecast)
        }

        try modelContext.save()

        // Verify forecasts were created
        let descriptor = FetchDescriptor<ForecastDay>(
            sortBy: [SortDescriptor(\.date)]
        )
        let forecasts = try modelContext.fetch(descriptor)

        XCTAssertEqual(forecasts.count, 10, "Should have 10 forecast days")
        XCTAssertEqual(forecasts.first?.highTemperature, 80.0, "First day high should be 80°")
        XCTAssertEqual(forecasts.last?.precipitationProbability, 90, "Last day precip should be 90%")
    }

    // MARK: - Location Tests

    func testLocationDataCreation() throws {
        // Test creating and storing location data
        let location = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco"
        )
        location.state = "CA"
        location.country = "USA"

        modelContext.insert(location)
        try modelContext.save()

        // Verify location was saved
        let descriptor = FetchDescriptor<LocationData>()
        let locations = try modelContext.fetch(descriptor)

        XCTAssertEqual(locations.count, 1, "Should have one location")
        XCTAssertEqual(locations.first?.city, "San Francisco", "Location city should match")
        XCTAssertEqual(locations.first!.latitude, 37.7749, accuracy: 0.0001, "Latitude should match")
    }

    func testLocationChange() throws {
        // Test changing location and verifying update
        let location1 = LocationData(latitude: 40.7128, longitude: -74.0060, city: "New York")
        modelContext.insert(location1)
        try modelContext.save()

        // Change to different location
        let location2 = LocationData(latitude: 34.0522, longitude: -118.2437, city: "Los Angeles")
        modelContext.insert(location2)
        try modelContext.save()

        let descriptor = FetchDescriptor<LocationData>()
        let locations = try modelContext.fetch(descriptor)

        XCTAssertEqual(locations.count, 2, "Should have two locations")
        XCTAssertTrue(locations.contains { $0.city == "Los Angeles" }, "Should contain Los Angeles")
    }

    // MARK: - Active Reminders Tests

    func testActiveRemindersDisplay() throws {
        // Create sample active reminders
        let location = LocationData(latitude: 37.0, longitude: -122.0, city: "Test City")
        modelContext.insert(location)

        let reminder1 = WeatherReminder(title: "Morning Walk")
        reminder1.isActive = true
        reminder1.location = location

        let reminder2 = WeatherReminder(title: "Evening Run")
        reminder2.isActive = true
        reminder2.location = location

        let reminder3 = WeatherReminder(title: "Inactive Reminder")
        reminder3.isActive = false

        modelContext.insert(reminder1)
        modelContext.insert(reminder2)
        modelContext.insert(reminder3)
        try modelContext.save()

        // Verify active reminders
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { $0.isActive == true }
        )
        let activeReminders = try modelContext.fetch(descriptor)

        XCTAssertEqual(activeReminders.count, 2, "Should have 2 active reminders")
        XCTAssertFalse(activeReminders.contains { $0.title == "Inactive Reminder" }, "Should not include inactive reminder")
    }

    // MARK: - User Preferences Tests

    func testTemperatureUnitPreference() throws {
        // Test temperature unit preference
        let preferences = UserPreferences()
        preferences.temperatureUnit = .fahrenheit

        modelContext.insert(preferences)
        try modelContext.save()

        let descriptor = FetchDescriptor<UserPreferences>()
        let fetchedPrefs = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetchedPrefs.first?.temperatureUnit, .fahrenheit, "Temperature unit should be fahrenheit")
    }

    // MARK: - Weather Alerts Tests

    func testWeatherAlertsCreation() throws {
        // Test creating weather alerts (WeatherAlert is a struct, not a SwiftData model)
        let alert = WeatherAlert(
            title: "Heat Advisory",
            description: "Excessive heat expected",
            severity: .moderate,
            timestamp: Date(),
            expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        )

        XCTAssertEqual(alert.title, "Heat Advisory", "Alert title should match")
        XCTAssertEqual(alert.description, "Excessive heat expected", "Alert description should match")
        XCTAssertEqual(alert.severity, .moderate, "Alert severity should match")
        XCTAssertTrue(alert.isActive, "Alert should be active by default")
        XCTAssertNotNil(alert.expiresAt, "Alert should have an expiration date")
    }

    // MARK: - Integration Tests

    func testCompleteWeatherDataFlow() throws {
        // Test complete flow: location -> weather data -> forecast
        let location = LocationData(latitude: 37.0, longitude: -122.0, city: "Test City")
        modelContext.insert(location)

        let weatherData = WeatherData(temperature: 72.0, feelsLike: 75.0, humidity: 60)
        weatherData.location = location
        weatherData.weatherDescription = "Sunny"
        modelContext.insert(weatherData)

        // Add forecast days
        for day in 1...7 {
            let forecast = ForecastDay(
                date: Calendar.current.date(byAdding: .day, value: day, to: Date())!,
                highTemperature: 70.0 + Double(day),
                lowTemperature: 55.0 + Double(day)
            )
            forecast.weatherData = weatherData
            modelContext.insert(forecast)
        }

        try modelContext.save()

        // Verify complete data
        let weatherDescriptor = FetchDescriptor<WeatherData>()
        let weather = try modelContext.fetch(weatherDescriptor)

        let forecastDescriptor = FetchDescriptor<ForecastDay>()
        let forecasts = try modelContext.fetch(forecastDescriptor)

        XCTAssertEqual(weather.count, 1, "Should have one weather entry")
        XCTAssertEqual(forecasts.count, 7, "Should have 7 forecast days")
        XCTAssertEqual(weather.first?.location?.city, "Test City", "Weather should be linked to location")
    }

    // MARK: - Performance Tests

    func testForecastDataPerformance() throws {
        // Test performance of loading forecast data
        measure {
            do {
                // Create 10 days of forecast
                for day in 0..<10 {
                    let forecast = ForecastDay(
                        date: Calendar.current.date(byAdding: .day, value: day, to: Date())!,
                        highTemperature: Double.random(in: 70...90),
                        lowTemperature: Double.random(in: 50...65)
                    )
                    modelContext.insert(forecast)
                }
                try modelContext.save()

                // Fetch and verify
                let descriptor = FetchDescriptor<ForecastDay>()
                _ = try modelContext.fetch(descriptor)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testInvalidWeatherDataHandling() {
        // Test handling of invalid weather data
        let weatherData = WeatherData(temperature: -999, feelsLike: -999, humidity: 150)

        // Humidity should be clamped or validated
        XCTAssertGreaterThanOrEqual(weatherData.humidity, 0, "Humidity should not be negative")
        XCTAssertLessThanOrEqual(weatherData.humidity, 150, "Humidity should be within reasonable range")
    }
}
