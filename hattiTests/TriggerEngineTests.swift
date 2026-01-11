//
//  TriggerEngineTests.swift
//  hattiTests
//
//  Created by Wesley Keetch on 7/20/25.
//

import XCTest
import SwiftData
import CoreLocation
@testable import hatti

final class TriggerEngineTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testLocation: CLLocation!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
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

        // Test location (San Francisco)
        testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        testLocation = nil
        try await super.tearDown()
    }

    // MARK: - TriggerCondition Model Tests

    @MainActor
    func testTriggerConditionCreation() throws {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        XCTAssertEqual(condition.triggerType, .exactTemperature)
        XCTAssertEqual(condition.targetTemperature, 70.0)
        XCTAssertEqual(condition.comparisonType, .above)
    }

    @MainActor
    func testTemperatureRangeCondition() throws {
        let condition = TriggerCondition(
            triggerType: .temperatureRange,
            targetTemperature: 70.0,
            comparisonType: .between
        )
        condition.minTemperature = 65.0
        condition.maxTemperature = 75.0

        XCTAssertEqual(condition.triggerType, .temperatureRange)
        XCTAssertEqual(condition.minTemperature, 65.0)
        XCTAssertEqual(condition.maxTemperature, 75.0)
    }

    @MainActor
    func testCompositeCondition() throws {
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

        XCTAssertEqual(condition.triggerType, .composite)
        XCTAssertTrue(condition.requiresHumidity)
        XCTAssertEqual(condition.targetHumidity, 50.0)
        XCTAssertTrue(condition.requiresWindSpeed)
        XCTAssertEqual(condition.maxWindSpeed, 10.0)
    }

    @MainActor
    func testSeasonalCondition() throws {
        let condition = TriggerCondition(
            triggerType: .seasonalMarker,
            targetTemperature: 32.0,
            comparisonType: .below
        )
        condition.seasonalType = .firstFrost

        XCTAssertEqual(condition.triggerType, .seasonalMarker)
        XCTAssertEqual(condition.seasonalType, .firstFrost)
    }

    @MainActor
    func testConsecutiveDaysCondition() throws {
        let condition = TriggerCondition(
            triggerType: .consecutiveDays,
            targetTemperature: 60.0,
            comparisonType: .above
        )
        condition.consecutiveDays = 3

        XCTAssertEqual(condition.triggerType, .consecutiveDays)
        XCTAssertEqual(condition.consecutiveDays, 3)
    }

    // MARK: - WeatherReminder Model Tests

    @MainActor
    func testReminderCreation() throws {
        let reminder = WeatherReminder(
            title: "Test Reminder",
            reminderDescription: "Test description"
        )

        XCTAssertEqual(reminder.title, "Test Reminder")
        XCTAssertEqual(reminder.reminderDescription, "Test description")
        XCTAssertTrue(reminder.isActive)
    }

    @MainActor
    func testReminderWithCondition() throws {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        let reminder = WeatherReminder(title: "Test Reminder")
        reminder.triggerCondition = condition

        modelContext.insert(reminder)
        try modelContext.save()

        XCTAssertNotNil(reminder.triggerCondition)
        XCTAssertEqual(reminder.triggerCondition?.targetTemperature, 70.0)
    }

    @MainActor
    func testReminderWithLocation() throws {
        let reminder = WeatherReminder(title: "Location Test")

        let locationData = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco"
        )
        reminder.location = locationData

        modelContext.insert(reminder)
        try modelContext.save()

        XCTAssertNotNil(reminder.location)
        XCTAssertEqual(reminder.location?.city, "San Francisco")
    }

    // MARK: - Weather Condition Evaluation Tests
    // Note: exactTemperature type uses tolerance-based matching, not above/below comparison
    // Composite type uses evaluateTemperatureCondition which respects comparisonType

    @MainActor
    func testExactTemperatureWithTolerance() throws {
        // exactTemperature uses tolerance matching
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .equals
        )
        condition.temperatureTolerance = 5.0  // Match within 5 degrees

        let weatherData = WeatherData(
            temperature: 72.0,  // Within 5 degrees of 70
            feelsLike: 72.0,
            humidity: 60
        )

        let result = weatherData.evaluateCondition(condition)
        XCTAssertTrue(result)

        // Test outside tolerance
        weatherData.temperature = 80.0  // Outside 5 degrees of 70
        let resultOutside = weatherData.evaluateCondition(condition)
        XCTAssertFalse(resultOutside)
    }

    @MainActor
    func testCompositeConditionWithAbove() throws {
        // Composite type respects comparisonType
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 70.0,
            comparisonType: .above
        )

        let weatherData = WeatherData(
            temperature: 75.0,  // Above 70
            feelsLike: 75.0,
            humidity: 60
        )

        let result = weatherData.evaluateCondition(condition)
        XCTAssertTrue(result)

        // Test below threshold
        weatherData.temperature = 65.0
        let resultBelow = weatherData.evaluateCondition(condition)
        XCTAssertFalse(resultBelow)
    }

    @MainActor
    func testRangeConditionEvaluation() throws {
        let condition = TriggerCondition(
            triggerType: .temperatureRange,
            targetTemperature: 70.0,
            comparisonType: .between
        )
        condition.minTemperature = 65.0
        condition.maxTemperature = 75.0

        let weatherData = WeatherData(
            temperature: 70.0,
            feelsLike: 70.0,
            humidity: 60
        )

        let result = weatherData.evaluateCondition(condition)
        XCTAssertTrue(result)

        // Test outside range
        weatherData.temperature = 80.0
        let resultOutside = weatherData.evaluateCondition(condition)
        XCTAssertFalse(resultOutside)
    }

    @MainActor
    func testCompositeConditionWithBelow() throws {
        // Composite type with below comparison
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 32.0,
            comparisonType: .below
        )

        let weatherData = WeatherData(
            temperature: 28.0,  // Below 32
            feelsLike: 25.0,
            humidity: 80
        )

        let result = weatherData.evaluateCondition(condition)
        XCTAssertTrue(result)

        // Test above threshold
        weatherData.temperature = 40.0
        let resultAbove = weatherData.evaluateCondition(condition)
        XCTAssertFalse(resultAbove)
    }

    @MainActor
    func testFeelsLikeWithComposite() throws {
        // Composite with useFeelsLike
        let condition = TriggerCondition(
            triggerType: .composite,
            targetTemperature: 80.0,
            comparisonType: .above
        )
        condition.useFeelsLike = true

        let weatherData = WeatherData(
            temperature: 75.0,  // Actual temp below threshold
            feelsLike: 85.0,    // Feels like above threshold
            humidity: 80
        )

        let result = weatherData.evaluateCondition(condition)
        XCTAssertTrue(result)  // Should trigger based on feels-like
    }

    // MARK: - TriggerType Enum Tests

    @MainActor
    func testTriggerTypeValues() {
        let types: [TriggerType] = [
            .exactTemperature,
            .temperatureRange,
            .consecutiveDays,
            .averageTemperature,
            .composite,
            .seasonalMarker,
            .historicalComparison
        ]

        XCTAssertEqual(types.count, 7)

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    // MARK: - ComparisonType Enum Tests

    @MainActor
    func testComparisonTypeValues() {
        let types: [ComparisonType] = [.above, .below, .between, .equals]

        XCTAssertEqual(types.count, 4)

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testReminderCreationPerformance() throws {
        measure {
            for i in 0..<100 {
                let condition = TriggerCondition(
                    triggerType: .exactTemperature,
                    targetTemperature: Double(60 + (i % 30)),
                    comparisonType: .above
                )

                let reminder = WeatherReminder(title: "Performance Test \(i)")
                reminder.triggerCondition = condition

                modelContext.insert(reminder)
            }

            try? modelContext.save()
        }
    }

    @MainActor
    func testConditionEvaluationPerformance() {
        let conditions: [TriggerCondition] = (0..<100).map { i in
            TriggerCondition(
                triggerType: .exactTemperature,
                targetTemperature: Double(50 + i),
                comparisonType: .above
            )
        }

        let weatherData = WeatherData(
            temperature: 75.0,
            feelsLike: 75.0,
            humidity: 60
        )

        measure {
            for condition in conditions {
                _ = weatherData.evaluateCondition(condition)
            }
        }
    }
}

// MARK: - Mock Data Helpers

extension TriggerEngineTests {

    @MainActor
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

    @MainActor
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
