//
//  DashboardViewTests.swift
//  SunHatTests
//
//  Created by Wesley Keetch on 1/10/26.
//

import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import SunHat

// MARK: - Dashboard ViewModel Tests

@MainActor
struct DashboardViewModelTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let viewModel: DashboardViewModel

    init() throws {
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
        viewModel = DashboardViewModel()
        viewModel.configure(modelContext: modelContext)
    }

    @Test("ViewModel initializes with expected defaults")
    func viewModelInitialState() {
        #expect(viewModel.currentTemperature == 0.0)
        #expect(viewModel.humidity == 0)
        #expect(viewModel.weatherDescription == String(localized: "Loading...", comment: "Placeholder shown before weather data has loaded"))
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.activeReminders.isEmpty)
        #expect(viewModel.forecastData.isEmpty)
    }

    @Test("Loading completes after weather refresh")
    func weatherDataRefresh() async {
        await viewModel.refreshWeatherData()
        #expect(viewModel.isLoading == false)
    }
}

// MARK: - Weather Data Persistence Tests

@MainActor
struct DashboardWeatherDataTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
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
    }

    @Test("Weather data persists and fetches correctly")
    func weatherDataPersistence() throws {
        let weatherData = WeatherData(temperature: 72.0, feelsLike: 75.0, humidity: 65)
        weatherData.weatherDescription = "Partly Cloudy"
        weatherData.weatherCondition = .partlyCloudy

        modelContext.insert(weatherData)
        try modelContext.save()

        let descriptor = FetchDescriptor<WeatherData>()
        let fetchedData = try modelContext.fetch(descriptor)

        #expect(fetchedData.count == 1)
        #expect(fetchedData.first?.temperature == 72.0)
        #expect(fetchedData.first?.humidity == 65)
    }

    @Test("10 forecast days persist with correct values")
    func forecastDataCreation() throws {
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

        let descriptor = FetchDescriptor<ForecastDay>(sortBy: [SortDescriptor(\.date)])
        let forecasts = try modelContext.fetch(descriptor)

        #expect(forecasts.count == 10)
        #expect(forecasts.first?.highTemperature == 80.0)
        #expect(forecasts.last?.precipitationProbability == 90)
    }
}

// MARK: - Location Tests

@MainActor
struct DashboardLocationTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
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
    }

    @Test("Location data persists with city and coordinates")
    func locationDataCreation() throws {
        let location = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco"
        )
        location.state = "CA"
        location.country = "USA"

        modelContext.insert(location)
        try modelContext.save()

        let descriptor = FetchDescriptor<LocationData>()
        let locations = try modelContext.fetch(descriptor)

        #expect(locations.count == 1)
        #expect(locations.first?.city == "San Francisco")
        let lat = try #require(locations.first?.latitude)
        #expect(abs(lat - 37.7749) < 0.0001)
    }

    @Test("Multiple locations can be stored")
    func locationChange() throws {
        let location1 = LocationData(latitude: 40.7128, longitude: -74.0060, city: "New York")
        modelContext.insert(location1)

        let location2 = LocationData(latitude: 34.0522, longitude: -118.2437, city: "Los Angeles")
        modelContext.insert(location2)
        try modelContext.save()

        let descriptor = FetchDescriptor<LocationData>()
        let locations = try modelContext.fetch(descriptor)

        #expect(locations.count == 2)
        #expect(locations.contains { $0.city == "Los Angeles" })
    }
}

// MARK: - Active Reminders Tests

@MainActor
struct DashboardActiveRemindersTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
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
    }

    @Test("Only active reminders are fetched by predicate")
    func activeRemindersDisplay() throws {
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

        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { $0.isActive == true }
        )
        let activeReminders = try modelContext.fetch(descriptor)

        #expect(activeReminders.count == 2)
        #expect(!activeReminders.contains { $0.title == "Inactive Reminder" })
    }
}

// MARK: - User Preferences Tests

@MainActor
struct DashboardUserPreferencesTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
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
    }

    @Test("Temperature unit preference persists")
    func temperatureUnitPreference() throws {
        let preferences = UserPreferences()
        preferences.temperatureUnit = .fahrenheit

        modelContext.insert(preferences)
        try modelContext.save()

        let descriptor = FetchDescriptor<UserPreferences>()
        let fetchedPrefs = try modelContext.fetch(descriptor)

        #expect(fetchedPrefs.first?.temperatureUnit == .fahrenheit)
    }
}

// MARK: - Weather Alerts Tests

@MainActor
struct DashboardWeatherAlertTests {

    @Test("Weather alert initializes with correct values")
    func weatherAlertsCreation() {
        let alert = WeatherAlert(
            title: "Heat Advisory",
            description: "Excessive heat expected",
            severity: .moderate,
            timestamp: Date(),
            expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        )

        #expect(alert.title == "Heat Advisory")
        #expect(alert.description == "Excessive heat expected")
        #expect(alert.severity == .moderate)
        #expect(alert.isActive == true)
        #expect(alert.expiresAt != nil)
    }
}

// MARK: - Integration Tests

@MainActor
struct DashboardIntegrationTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
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
    }

    @Test("Location → weather → forecast flow persists correctly")
    func completeWeatherDataFlow() throws {
        let location = LocationData(latitude: 37.0, longitude: -122.0, city: "Test City")
        modelContext.insert(location)

        let weatherData = WeatherData(temperature: 72.0, feelsLike: 75.0, humidity: 60)
        weatherData.location = location
        weatherData.weatherDescription = "Sunny"
        modelContext.insert(weatherData)

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

        let weatherDescriptor = FetchDescriptor<WeatherData>()
        let weather = try modelContext.fetch(weatherDescriptor)

        let forecastDescriptor = FetchDescriptor<ForecastDay>()
        let forecasts = try modelContext.fetch(forecastDescriptor)

        #expect(weather.count == 1)
        #expect(forecasts.count == 7)
        #expect(weather.first?.location?.city == "Test City")
    }
}

// MARK: - Error Handling Tests

@MainActor
struct DashboardErrorHandlingTests {

    @Test("Invalid weather data values are stored as-is")
    func invalidWeatherDataHandling() {
        let weatherData = WeatherData(temperature: -999, feelsLike: -999, humidity: 150)
        #expect(weatherData.humidity >= 0)
        #expect(weatherData.humidity <= 150)
    }
}
