//
//  TriggerEngineTests.swift
//  SunHatTests
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftData
import CoreLocation
import Testing
@testable import SunHat

// MARK: - TriggerCondition Model Tests

@MainActor
struct TriggerConditionModelTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let testLocation: CLLocation

    init() throws {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    }

    @Test("Exact temperature condition stores correct values")
    func triggerConditionCreation() {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        #expect(condition.triggerType == .exactTemperature)
        #expect(condition.targetTemperature == 70.0)
        #expect(condition.comparisonType == .above)
    }

    @Test("Temperature range condition stores min and max")
    func temperatureRangeCondition() {
        let condition = TriggerCondition(
            triggerType: .temperatureRange,
            targetTemperature: 70.0,
            comparisonType: .between
        )
        condition.minTemperature = 65.0
        condition.maxTemperature = 75.0

        #expect(condition.triggerType == .temperatureRange)
        #expect(condition.minTemperature == 65.0)
        #expect(condition.maxTemperature == 75.0)
    }

    @Test("Composite condition stores humidity and wind requirements")
    func compositeCondition() {
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 70.0,
            comparisonType: .above
        )
        condition.requiresHumidity = true
        condition.targetHumidity = 50.0
        condition.humidityTolerance = 10.0
        condition.requiresWindSpeed = true
        condition.maxWindSpeed = 10.0

        #expect(condition.triggerType == .composite)
        #expect(condition.requiresHumidity == true)
        #expect(condition.targetHumidity == 50.0)
        #expect(condition.requiresWindSpeed == true)
        #expect(condition.maxWindSpeed == 10.0)
    }

    @Test("Seasonal marker condition stores seasonal type")
    func seasonalCondition() {
        let condition = TriggerCondition(
            triggerType: .seasonalMarker,
            targetTemperature: 32.0,
            comparisonType: .below
        )
        condition.seasonalType = .firstFrost

        #expect(condition.triggerType == .seasonalMarker)
        #expect(condition.seasonalType == .firstFrost)
    }

    @Test("Consecutive days condition stores day count")
    func consecutiveDaysCondition() {
        let condition = TriggerCondition(
            triggerType: .consecutiveDays,
            targetTemperature: 60.0,
            comparisonType: .above
        )
        condition.consecutiveDays = 3

        #expect(condition.triggerType == .consecutiveDays)
        #expect(condition.consecutiveDays == 3)
    }
}

// MARK: - WeatherReminder Model Tests

@MainActor
struct WeatherReminderModelTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
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

    @Test("Reminder creation sets defaults")
    func reminderCreation() {
        let reminder = WeatherReminder(
            title: "Test Reminder",
            reminderDescription: "Test description"
        )

        #expect(reminder.title == "Test Reminder")
        #expect(reminder.reminderDescription == "Test description")
        #expect(reminder.isActive == true)
    }

    @Test("Reminder persists with condition")
    func reminderWithCondition() throws {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        let reminder = WeatherReminder(title: "Test Reminder")
        reminder.triggerCondition = condition

        modelContext.insert(reminder)
        try modelContext.save()

        #expect(reminder.triggerCondition != nil)
        #expect(reminder.triggerCondition?.targetTemperature == 70.0)
    }

    @Test("Reminder persists with location")
    func reminderWithLocation() throws {
        let reminder = WeatherReminder(title: "Location Test")

        let locationData = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco"
        )
        reminder.location = locationData

        modelContext.insert(reminder)
        try modelContext.save()

        #expect(reminder.location != nil)
        #expect(reminder.location?.city == "San Francisco")
    }
}

// MARK: - Weather Condition Evaluation Tests

@MainActor
struct WeatherConditionEvaluationTests {

    @Test("Exact temperature matches within tolerance")
    func exactTemperatureWithTolerance() {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .equals
        )
        condition.temperatureTolerance = 5.0

        let weatherData = WeatherData(temperature: 72.0, feelsLike: 72.0, humidity: 60)
        #expect(weatherData.evaluateCondition(condition) == true)

        weatherData.temperature = 80.0
        #expect(weatherData.evaluateCondition(condition) == false)
    }

    @Test("Composite condition evaluates above threshold")
    func compositeConditionWithAbove() {
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        let weatherData = WeatherData(temperature: 75.0, feelsLike: 75.0, humidity: 60)
        #expect(weatherData.evaluateCondition(condition) == true)

        weatherData.temperature = 65.0
        #expect(weatherData.evaluateCondition(condition) == false)
    }

    @Test("Range condition matches between min and max")
    func rangeConditionEvaluation() {
        let condition = TriggerCondition(
            triggerType: .temperatureRange,
            targetTemperature: 70.0,
            comparisonType: .between
        )
        condition.minTemperature = 65.0
        condition.maxTemperature = 75.0

        let weatherData = WeatherData(temperature: 70.0, feelsLike: 70.0, humidity: 60)
        #expect(weatherData.evaluateCondition(condition) == true)

        weatherData.temperature = 80.0
        #expect(weatherData.evaluateCondition(condition) == false)
    }

    @Test("Composite condition evaluates below threshold")
    func compositeConditionWithBelow() {
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 32.0,
            comparisonType: .below
        )

        let weatherData = WeatherData(temperature: 28.0, feelsLike: 25.0, humidity: 80)
        #expect(weatherData.evaluateCondition(condition) == true)

        weatherData.temperature = 40.0
        #expect(weatherData.evaluateCondition(condition) == false)
    }

    @Test("Composite condition uses feels-like temperature")
    func feelsLikeWithComposite() {
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 80.0,
            comparisonType: .above
        )
        condition.useFeelsLike = true

        let weatherData = WeatherData(temperature: 75.0, feelsLike: 85.0, humidity: 80)
        #expect(weatherData.evaluateCondition(condition) == true)
    }
}

// MARK: - Enum Tests

@MainActor
struct TriggerEnumTests {

    @Test(
        "All trigger types have non-empty raw values",
        arguments: [
            TriggerType.exactTemperature,
            TriggerType.temperatureRange,
            TriggerType.consecutiveDays,
            TriggerType.averageTemperature,
            TriggerType.composite,
            TriggerType.seasonalMarker,
            TriggerType.historicalComparison
        ]
    )
    func triggerTypeRawValues(type: TriggerType) {
        #expect(type.rawValue.isEmpty == false)
    }

    @Test(
        "All comparison types have non-empty raw values",
        arguments: [ComparisonType.above, .below, .between, .equals]
    )
    func comparisonTypeRawValues(type: ComparisonType) {
        #expect(type.rawValue.isEmpty == false)
    }
}

// MARK: - Mock Data Helpers

extension TriggerConditionModelTests {
    func createTestWeatherData(temperature: Double, location: CLLocation) -> WeatherData {
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        let weatherData = WeatherData(
            temperature: temperature,
            feelsLike: temperature + 2.0,
            humidity: 60
        )
        weatherData.location = locationData
        weatherData.windSpeed = 5.0
        weatherData.weatherCondition = .clear

        return weatherData
    }

    func createTestForecast(days: Int, baseTemperature: Double) -> [ForecastDay] {
        var forecast: [ForecastDay] = []
        let calendar = Calendar.current

        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: i, to: Date()) ?? Date()
            let temp = baseTemperature + Double(i) * 2.0

            let forecastDay = ForecastDay(
                date: date,
                highTemperature: temp + 5.0,
                lowTemperature: temp - 5.0,
                weatherCondition: .clear
            )

            forecast.append(forecastDay)
        }

        return forecast
    }
}
