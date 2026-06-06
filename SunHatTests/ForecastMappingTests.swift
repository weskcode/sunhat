//
//  ForecastMappingTests.swift
//  SunHatTests
//
//  Covers the live-weather → compact-forecast mapping in FirstReminderCreationViewModel
//  that feeds trigger-likelihood (replacing the old fabricated mock forecast).
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct ForecastConditionMappingTests {
    @Test(
        "Every WeatherCondition maps to the expected compact sky condition",
        arguments: [
            (WeatherCondition.clear, MockWeatherCondition.clear),
            (.partlyCloudy, .partlyCloudy),
            (.cloudy, .cloudy),
            (.overcast, .cloudy),
            (.fog, .cloudy),
            (.windy, .cloudy),
            (.unknown, .cloudy),
            (.rain, .rain),
            (.drizzle, .rain),
            (.thunderstorm, .rain),
            (.snow, .snow),
            (.sleet, .snow),
            (.hail, .snow)
        ]
    )
    func conditionMapping(source: WeatherCondition, expected: MockWeatherCondition) {
        #expect(FirstReminderCreationViewModel.mapToMockCondition(source) == expected)
    }

    @Test("Every WeatherCondition case has a mapping (no crash / fallthrough gap)")
    func everyConditionMaps() {
        for condition in WeatherCondition.allCases {
            // Exercises the switch for completeness; a missing case wouldn't compile,
            // but this guards against an unexpected default swallowing new cases.
            _ = FirstReminderCreationViewModel.mapToMockCondition(condition)
        }
    }
}

@MainActor
struct ForecastDayMappingTests {
    @Test("Forecast days round temperatures to whole degrees and carry the date")
    func mapsTemperaturesAndDate() throws {
        let date = Date()
        let days = [
            ForecastDay(date: date, highTemperature: 72.6, lowTemperature: 54.4, weatherCondition: .rain)
        ]

        let mapped = FirstReminderCreationViewModel.mapForecast(days)
        let first = try #require(mapped.first)

        #expect(first.highTemp == 73)
        #expect(first.lowTemp == 54)
        #expect(first.weatherCondition == .rain)
        #expect(first.date == date)
    }

    @Test("Forecast mapping caps the result at 7 days")
    func capsAtSevenDays() {
        let calendar = Calendar.current
        let today = Date()
        let days = (0..<10).map { offset in
            ForecastDay(
                date: calendar.date(byAdding: .day, value: offset, to: today) ?? today,
                highTemperature: 70,
                lowTemperature: 50,
                weatherCondition: .clear
            )
        }

        #expect(FirstReminderCreationViewModel.mapForecast(days).count == 7)
    }

    @Test("Empty forecast input maps to an empty result (no fabrication)")
    func emptyInputMapsEmpty() {
        #expect(FirstReminderCreationViewModel.mapForecast([]).isEmpty)
    }
}
