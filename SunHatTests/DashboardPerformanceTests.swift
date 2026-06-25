//
//  DashboardPerformanceTests.swift
//  SunHatTests
//

import XCTest
import SwiftData
@testable import SunHat

@MainActor
final class DashboardPerformanceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
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

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    func testForecastDataPerformance() throws {
        measure {
            do {
                for day in 0..<10 {
                    let forecast = ForecastDay(
                        date: Calendar.current.date(byAdding: .day, value: day, to: Date())!,
                        highTemperature: Double.random(in: 70...90),
                        lowTemperature: Double.random(in: 50...65)
                    )
                    modelContext.insert(forecast)
                }
                try modelContext.save()

                let descriptor = FetchDescriptor<ForecastDay>()
                _ = try modelContext.fetch(descriptor)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}
