//
//  TriggerEnginePerformanceTests.swift
//  SunHatTests
//

import XCTest
import SwiftData
@testable import SunHat

final class TriggerEnginePerformanceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

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

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

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
