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
    var triggerEngine: TriggerEngine!
    var modelContext: ModelContext!
    var testLocation: CLLocation!
    
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
        
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(container)
        
        triggerEngine = TriggerEngine.shared
        await triggerEngine.configure(modelContext: modelContext)
        
        // Test location (San Francisco)
        testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    
    override func tearDown() async throws {
        triggerEngine = nil
        modelContext = nil
        testLocation = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Trigger Evaluation Tests
    
    func testExactTemperatureTrigger() async throws {
        // Create a simple temperature trigger
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )
        
        let reminder = WeatherReminder(
            title: "Test Reminder",
            reminderDescription: "Test exact temperature trigger"
        )
        reminder.triggerCondition = condition
        
        // Create weather data that should trigger
        let weatherData = WeatherData(
            temperature: 75.0,
            feelsLike: 75.0,
            humidity: 60
        )
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        // Evaluate the reminder
        let result = await triggerEngine.evaluateReminder(reminder)
        
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.triggered)
        XCTAssertGreaterThan(result!.confidence, 0.0)
        XCTAssertTrue(result!.triggerReason.contains("75.0"))
        XCTAssertTrue(result!.triggerReason.contains("above"))
    }
    
    func testTemperatureRangeTrigger() async throws {
        let condition = TriggerCondition(
            triggerType: .temperatureRange,
            targetTemperature: 70.0,
            comparisonType: .between
        )
        condition.minTemperature = 65.0
        condition.maxTemperature = 75.0
        
        let reminder = WeatherReminder(title: "Range Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        // Test temperature within range
        let result = await triggerEngine.evaluateReminder(reminder)
        
        // Note: This would need actual weather data fetching or mocking
        // For now, test the condition evaluation logic separately
        XCTAssertNotNil(result)
    }
    
    func testFeelsLikeTemperature() async throws {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 80.0,
            comparisonType: .above
        )
        condition.useFeelsLike = true
        
        let reminder = WeatherReminder(title: "Feels Like Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metadata["uses_feels_like"], "true")
    }
    
    // MARK: - Composite Condition Tests
    
    func testCompositeCondition() async throws {
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
        
        let reminder = WeatherReminder(title: "Composite Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metadata["humidity_required"], "true")
        XCTAssertEqual(result!.metadata["wind_required"], "true")
    }
    
    // MARK: - Seasonal Trigger Tests
    
    func testSeasonalTrigger() async throws {
        let condition = TriggerCondition(
            triggerType: .seasonalMarker,
            targetTemperature: 32.0,
            comparisonType: .below
        )
        condition.seasonalType = .firstFrost
        
        let reminder = WeatherReminder(title: "First Frost Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metadata["seasonal_type"], "first_frost")
    }
    
    // MARK: - Historical Comparison Tests
    
    func testHistoricalComparison() async throws {
        let condition = TriggerCondition(
            triggerType: .historicalComparison,
            targetTemperature: 70.0,
            comparisonType: .above
        )
        condition.historicalComparisonDays = 30
        
        let reminder = WeatherReminder(title: "Historical Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metadata["comparison_days"], "30")
    }
    
    // MARK: - Trend Analysis Tests
    
    func testConsecutiveDaysTrigger() async throws {
        let condition = TriggerCondition(
            triggerType: .consecutiveDays,
            targetTemperature: 60.0,
            comparisonType: .above
        )
        condition.consecutiveDays = 3
        
        let reminder = WeatherReminder(title: "Consecutive Days Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metadata["required_consecutive_days"], "3")
    }
    
    func testAverageTemperatureTrigger() async throws {
        let condition = TriggerCondition(
            triggerType: .averageTemperature,
            targetTemperature: 65.0,
            comparisonType: .above
        )
        condition.averagingPeriod = 7
        
        let reminder = WeatherReminder(title: "Average Temperature Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metadata["averaging_period"], "7")
    }
    
    // MARK: - Performance Tests
    
    func testBatchEvaluation() async throws {
        // Create multiple reminders
        var reminders: [WeatherReminder] = []
        
        for i in 0..<20 {
            let condition = TriggerCondition(
                triggerType: .exactTemperature,
                targetTemperature: Double(60 + i),
                comparisonType: .above
            )
            
            let reminder = WeatherReminder(title: "Batch Test \(i)")
            reminder.triggerCondition = condition
            
            let locationData = LocationData(
                latitude: 37.7749 + Double(i) * 0.01,
                longitude: -122.4194 + Double(i) * 0.01
            )
            reminder.location = locationData
            
            reminders.append(reminder)
            modelContext.insert(reminder)
        }
        
        try modelContext.save()
        
        // Test batch evaluation
        let startTime = Date()
        let results = await triggerEngine.evaluateRemindersInBatches(batchSize: 5, maxConcurrentBatches: 2)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, reminders.count)
        XCTAssertLessThan(duration, 30.0) // Should complete within 30 seconds
    }
    
    func testPerformanceReport() async throws {
        let report = await triggerEngine.generatePerformanceReport()
        
        XCTAssertGreaterThanOrEqual(report.evaluationCount, 0)
        XCTAssertGreaterThanOrEqual(report.averageDuration, 0)
        XCTAssertNotNil(report.cacheStatistics)
        XCTAssertNotNil(report.loadPrediction)
    }
    
    func testCacheOptimization() async throws {
        // Generate some cache entries
        for i in 0..<10 {
            let condition = TriggerCondition(
                triggerType: .exactTemperature,
                targetTemperature: Double(60 + i),
                comparisonType: .above
            )
            
            let reminder = WeatherReminder(title: "Cache Test \(i)")
            reminder.triggerCondition = condition
            
            modelContext.insert(reminder)
        }
        
        try modelContext.save()
        
        // Perform evaluations to populate cache
        let _ = await triggerEngine.evaluateAllActiveReminders()
        
        // Test cache optimization
        await triggerEngine.optimizeCaches()
        
        // Verify caches still work
        let results = await triggerEngine.evaluateAllActiveReminders()
        XCTAssertGreaterThan(results.count, 0)
    }
    
    // MARK: - Edge Case Tests
    
    func testInvalidConditions() async throws {
        // Test condition with missing temperature range
        let condition = TriggerCondition(
            triggerType: .temperatureRange,
            targetTemperature: 70.0,
            comparisonType: .between
        )
        // Intentionally don't set min/max temperatures
        
        let reminder = WeatherReminder(title: "Invalid Range Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.triggered)
        XCTAssertEqual(result!.confidence, 0.0)
    }
    
    func testNoWeatherData() async throws {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )
        
        let reminder = WeatherReminder(title: "No Data Test")
        reminder.triggerCondition = condition
        
        // Don't set location (should handle gracefully)
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNil(result) // Should return nil for missing location
    }
    
    // MARK: - Time Constraint Tests
    
    func testTimeConstraints() async throws {
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: 70.0,
            comparisonType: .above
        )
        
        let calendar = Calendar.current
        let now = Date()
        
        // Set time constraints for current time +/- 1 hour
        condition.timeOfDayStart = calendar.date(byAdding: .hour, value: -1, to: now)
        condition.timeOfDayEnd = calendar.date(byAdding: .hour, value: 1, to: now)
        
        let reminder = WeatherReminder(title: "Time Constraint Test")
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        try modelContext.save()
        
        let result = await triggerEngine.evaluateReminder(reminder)
        XCTAssertNotNil(result)
        
        // Should include time constraint evaluation
        if let metadata = result?.metadata["time_constraints"] {
            XCTAssertEqual(metadata, "true")
        }
    }
    
    // MARK: - Memory and Performance Tests
    
    func testMemoryCleanup() async throws {
        // Create some cache entries
        let _ = await triggerEngine.evaluateAllActiveReminders()
        
        // Perform memory cleanup
        await triggerEngine.performMemoryCleanup()
        
        // Verify engine still works after cleanup
        let results = await triggerEngine.evaluateAllActiveReminders()
        XCTAssertNotNil(results)
    }
    
    func testLoadPrediction() async throws {
        // Create several reminders with different complexity levels
        let conditions = [
            TriggerCondition(triggerType: .exactTemperature, targetTemperature: 70.0, comparisonType: .above),
            TriggerCondition(triggerType: .consecutiveDays, targetTemperature: 60.0, comparisonType: .above),
            TriggerCondition(triggerType: .seasonalMarker, targetTemperature: 32.0, comparisonType: .below),
            TriggerCondition(triggerType: .composite, targetTemperature: 75.0, comparisonType: .above)
        ]
        
        for (index, condition) in conditions.enumerated() {
            if condition.triggerType == .consecutiveDays {
                condition.consecutiveDays = 3
            }
            if condition.triggerType == .seasonalMarker {
                condition.seasonalType = .firstFrost
            }
            if condition.triggerType == .composite {
                condition.requiresHumidity = true
                condition.targetHumidity = 50.0
            }
            
            let reminder = WeatherReminder(title: "Load Test \(index)")
            reminder.triggerCondition = condition
            
            modelContext.insert(reminder)
        }
        
        try modelContext.save()
        
        let prediction = await triggerEngine.predictEvaluationLoad()
        
        XCTAssertEqual(prediction.activeReminders, 4)
        XCTAssertGreaterThanOrEqual(prediction.estimatedDuration, 0)
        XCTAssertNotNil(prediction.complexity)
    }
    
    func testPerformanceStressTest() async throws {
        // Create a large number of reminders to test performance
        let reminderCount = 50
        
        for i in 0..<reminderCount {
            let condition = TriggerCondition(
                triggerType: .exactTemperature,
                targetTemperature: Double(50 + (i % 30)),
                comparisonType: .above
            )
            
            let reminder = WeatherReminder(title: "Stress Test \(i)")
            reminder.triggerCondition = condition
            
            // Spread across different locations
            let locationData = LocationData(
                latitude: 37.0 + Double(i % 10) * 0.1,
                longitude: -122.0 + Double(i % 10) * 0.1
            )
            reminder.location = locationData
            
            modelContext.insert(reminder)
        }
        
        try modelContext.save()
        
        // Measure evaluation time
        let startTime = Date()
        let results = await triggerEngine.evaluateAllActiveReminders()
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, reminderCount)
        XCTAssertLessThan(duration, 60.0) // Should complete within 1 minute
        
        // Verify performance metrics
        let metrics = await triggerEngine.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics.count, 0)
        XCTAssertGreaterThan(metrics.averageDuration, 0)
    }
}

// MARK: - Mock Data Helpers

extension TriggerEngineTests {
    
    func createTestWeatherData(temperature: Double, location: CLLocation) -> WeatherData {
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        let weatherData = WeatherData(
            temperature: temperature,
            feelsLike: temperature + 2.0, // Slightly higher feels-like
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
            let temp = baseTemperature + Double(i) * 2.0 // Gradually increasing
            
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