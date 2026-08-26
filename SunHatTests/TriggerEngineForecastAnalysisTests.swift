//
//  TriggerEngineForecastAnalysisTests.swift
//  SunHatTests
//
//  Regression coverage for the July 2026 audit fixes in
//  TriggerEngine+ForecastAnalysis: zero-tolerance equality confidence (§5.5)
//  and 24/48-hour dry-period evaluation across the forecast window (§5.4).
//

import CoreLocation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct TriggerEngineForecastAnalysisTests {
    private let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

    // MARK: - Fixtures

    private func makeEngine() async throws -> TriggerEngine {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self
        ])
        let container = try await MainActor.run {
            try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
        return await TriggerEngine.shared(modelContainer: container)
    }

    private func makeConditionData(
        targetTemperature: Double = 70,
        tolerance: Double = 2,
        comparisonType: ComparisonType = .above,
        requiresPrecipitation: Bool = false,
        precipitationRequirement: PrecipitationRequirement = .none
    ) -> TriggerConditionData {
        TriggerConditionData(
            id: UUID(),
            triggerType: requiresPrecipitation ? .composite : .exactTemperature,
            targetTemperature: targetTemperature,
            temperatureTolerance: tolerance,
            useFeelsLike: false,
            minTemperature: nil,
            maxTemperature: nil,
            consecutiveDays: 0,
            averagingPeriod: 0,
            comparisonType: comparisonType,
            seasonalType: nil,
            historicalComparisonDays: 0,
            requiresHumidity: false,
            targetHumidity: nil,
            humidityTolerance: 10,
            requiresWindSpeed: false,
            maxWindSpeed: nil,
            requiresPrecipitation: requiresPrecipitation,
            precipitationRequirement: precipitationRequirement,
            timeOfDayStart: nil,
            timeOfDayEnd: nil,
            isEnabled: true,
            createdAt: Date(),
            lastEvaluated: nil,
            evaluationCount: 0,
            successfulTriggers: 0,
            selectedSkyConditionsRaw: "",
            conditionModeRaw: "include",
            hasSkyConditionFilter: false
        )
    }

    private func makeForecastDay(
        daysOut: Int,
        precipitationProbability: Int = 0,
        precipitationAmount: Double = 0,
        condition: WeatherCondition = .clear
    ) -> ForecastDayTransfer {
        let date = Calendar.current.date(byAdding: .day, value: daysOut, to: Date()) ?? Date()
        return ForecastDayTransfer(
            date: date,
            highTemperature: 75,
            lowTemperature: 55,
            averageTemperature: 65,
            weatherCondition: condition,
            precipitationProbability: precipitationProbability,
            precipitationAmount: precipitationAmount,
            precipitationType: precipitationAmount > 0 ? .rain : PrecipitationType.none,
            windSpeed: 5,
            humidity: 50,
            cloudCover: 20
        )
    }

    private func makeWeatherTransfer(
        temperature: Double,
        forecastDays: [ForecastDayTransfer] = []
    ) -> WeatherDataTransfer {
        WeatherDataTransfer(
            timestamp: Date(),
            temperature: temperature,
            apparentTemperature: temperature,
            humidity: 50,
            windSpeed: 5,
            pressure: 30,
            visibility: 10,
            uvIndex: 4,
            dewPoint: 50,
            windDirectionDegrees: 180,
            windGust: nil,
            precipitationAmount: 0,
            precipitationProbability: 0,
            cloudCoverage: 20,
            airQualityIndex: nil,
            pm25: nil,
            sunrise: nil,
            sunset: nil,
            weatherCondition: .clear,
            weatherDescription: "Clear",
            locationLatitude: location.coordinate.latitude,
            locationLongitude: location.coordinate.longitude,
            forecastDays: forecastDays
        )
    }

    // MARK: - Zero tolerance (§5.5)

    @Test("Exact match at zero temperature tolerance yields full, finite confidence")
    func zeroToleranceExactMatchIsFinite() async throws {
        let engine = try await makeEngine()
        let condition = makeConditionData(targetTemperature: 70, tolerance: 0, comparisonType: .equals)
        let weather = makeWeatherTransfer(temperature: 70)

        let result = await engine.evaluateComposite(
            condition,
            reminderId: condition.id,
            location: location,
            weatherData: weather
        )

        #expect(result.triggered)
        #expect(result.confidence.isFinite)
        #expect(result.confidence == 1.0)
    }

    // MARK: - Dry-period windows (§5.4)

    @Test("48h dry requirement fails when rain is forecast on day 2, even if it's dry now")
    func dryPeriodFailsOnRainLaterInWindow() async throws {
        let engine = try await makeEngine()
        let condition = makeConditionData(
            targetTemperature: 50,
            comparisonType: .above,
            requiresPrecipitation: true,
            precipitationRequirement: .noPrecipitationFor48Hours
        )
        let forecast = [
            makeForecastDay(daysOut: 0),
            makeForecastDay(daysOut: 1),
            makeForecastDay(daysOut: 2, precipitationProbability: 80, precipitationAmount: 0.4, condition: .rain)
        ]
        let weather = makeWeatherTransfer(temperature: 70, forecastDays: forecast)

        let result = await engine.evaluateComposite(
            condition,
            reminderId: condition.id,
            location: location,
            weatherData: weather
        )

        #expect(!result.triggered)
    }

    @Test("48h dry requirement passes when every covering forecast day is dry")
    func dryPeriodPassesWhenWindowIsDry() async throws {
        let engine = try await makeEngine()
        let condition = makeConditionData(
            targetTemperature: 50,
            comparisonType: .above,
            requiresPrecipitation: true,
            precipitationRequirement: .noPrecipitationFor48Hours
        )
        let forecast = [
            makeForecastDay(daysOut: 0, precipitationProbability: 5),
            makeForecastDay(daysOut: 1, precipitationProbability: 10),
            makeForecastDay(daysOut: 2, precipitationProbability: 0),
            makeForecastDay(daysOut: 3, precipitationProbability: 0)
        ]
        let weather = makeWeatherTransfer(temperature: 70, forecastDays: forecast)

        let result = await engine.evaluateComposite(
            condition,
            reminderId: condition.id,
            location: location,
            weatherData: weather
        )

        #expect(result.triggered)
        #expect(result.confidence.isFinite)
    }

    @Test("24h dry requirement fails without forecast coverage of the window")
    func dryPeriodRequiresForecastCoverage() async throws {
        let engine = try await makeEngine()
        let condition = makeConditionData(
            targetTemperature: 50,
            comparisonType: .above,
            requiresPrecipitation: true,
            precipitationRequirement: .noPrecipitationFor24Hours
        )
        let weather = makeWeatherTransfer(temperature: 70, forecastDays: [])

        let result = await engine.evaluateComposite(
            condition,
            reminderId: condition.id,
            location: location,
            weatherData: weather
        )

        #expect(!result.triggered)
    }

    @Test("24h dry-period coverage is bucketed by calendar day, not a raw hour cutoff")
    func dryPeriodCoverageToleratesNonMidnightForecastTimestamps() async throws {
        let engine = try await makeEngine()
        let calendar = Calendar.current

        // Simulate "now" early in the day and forecast entries stamped at an
        // arbitrary later hour (providers don't guarantee midnight, WeatherAPI's
        // own hourly-aggregate lookup normalizes via startOfDay for the same
        // reason). A raw `date <= now + 24h` cutoff would put windowEnd at
        // tomorrow 01:00, wrongly dropping a tomorrow entry stamped at noon even
        // though it's clearly the very next calendar day.
        let now = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: Date()) ?? Date()
        let todayStamped = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let tomorrowStamped = calendar.date(byAdding: .day, value: 1, to: todayStamped) ?? now

        let forecastDays = [
            ForecastDayTransfer(
                date: todayStamped,
                highTemperature: 75, lowTemperature: 55, averageTemperature: 65,
                weatherCondition: .clear, precipitationProbability: 5, precipitationAmount: 0,
                precipitationType: .none, windSpeed: 5, humidity: 50, cloudCover: 20
            ),
            ForecastDayTransfer(
                date: tomorrowStamped,
                highTemperature: 75, lowTemperature: 55, averageTemperature: 65,
                weatherCondition: .clear, precipitationProbability: 5, precipitationAmount: 0,
                precipitationType: .none, windSpeed: 5, humidity: 50, cloudCover: 20
            )
        ]

        let result = await engine.evaluateDryPeriod(
            hoursRequired: 24,
            currentIsWet: false,
            forecastDays: forecastDays,
            wetConditions: [.rain, .drizzle, .snow, .sleet, .hail, .thunderstorm],
            startingAt: now
        )

        #expect(result.met)
        #expect(result.confidence.isFinite)
    }
}
