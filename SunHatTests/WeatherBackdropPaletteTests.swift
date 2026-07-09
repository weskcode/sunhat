//
//  WeatherBackdropPaletteTests.swift
//  SunHatTests
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct WeatherBackdropPaletteTests {
    @Test(
        "Precipitation and obstruction conditions always win, regardless of temperature or cloud cover",
        arguments: [
            (WeatherCondition.rain, WeatherBackdropPalette.stormBlue),
            (.drizzle, .stormBlue),
            (.thunderstorm, .stormBlue),
            (.snow, .frozenBlue),
            (.sleet, .frozenBlue),
            (.hail, .frozenBlue),
            (.cloudy, .overcastBlue),
            (.overcast, .overcastBlue),
            (.fog, .overcastBlue),
            (.windy, .overcastBlue)
        ]
    )
    func conditionBasedMappingIgnoresTemperatureAndCloudCover(condition: WeatherCondition, expected: WeatherBackdropPalette) {
        let data = WeatherData(temperature: 95, feelsLike: 95, humidity: 50)
        data.weatherCondition = condition
        data.cloudCover = 0

        #expect(WeatherBackdropPalette.palette(for: data) == expected)
    }

    @Test(
        "Clear, partly cloudy, and unknown conditions fall through to cloud cover and temperature",
        arguments: [WeatherCondition.clear, .partlyCloudy, .unknown]
    )
    func fallthroughConditionsUseCloudCoverAndTemperature(condition: WeatherCondition) {
        let overcast = WeatherData(temperature: 90, feelsLike: 90, humidity: 50)
        overcast.weatherCondition = condition
        overcast.cloudCover = 90
        #expect(WeatherBackdropPalette.palette(for: overcast) == .overcastBlue)

        let cold = WeatherData(temperature: 30, feelsLike: 25, humidity: 50)
        cold.weatherCondition = condition
        cold.cloudCover = 10
        #expect(WeatherBackdropPalette.palette(for: cold) == .frozenBlue)

        let warm = WeatherData(temperature: 90, feelsLike: 90, humidity: 50)
        warm.weatherCondition = condition
        warm.cloudCover = 10
        #expect(WeatherBackdropPalette.palette(for: warm) == .brightBlue)

        let mild = WeatherData(temperature: 60, feelsLike: 60, humidity: 50)
        mild.weatherCondition = condition
        mild.cloudCover = 10
        #expect(WeatherBackdropPalette.palette(for: mild) == .calmBlue)
    }

    @Test("Cloud cover at or above the threshold takes priority over a hot temperature")
    func cloudCoverThresholdBeatsWarmTemperature() {
        let data = WeatherData(temperature: 100, feelsLike: 100, humidity: 50)
        data.weatherCondition = .clear
        data.cloudCover = WeatherBackdropPalette.cloudyCloudCoverThreshold

        #expect(WeatherBackdropPalette.palette(for: data) == .overcastBlue)
    }

    @Test("Cloud cover one below the threshold falls through to temperature checks")
    func cloudCoverJustBelowThresholdFallsThrough() {
        let data = WeatherData(temperature: 100, feelsLike: 100, humidity: 50)
        data.weatherCondition = .clear
        data.cloudCover = WeatherBackdropPalette.cloudyCloudCoverThreshold - 1

        #expect(WeatherBackdropPalette.palette(for: data) == .brightBlue)
    }

    @Test("Temperature exactly at the warm threshold is bright, one below is calm")
    func warmThresholdBoundary() {
        let atThreshold = WeatherData(temperature: WeatherBackdropPalette.warmThresholdF, feelsLike: 0, humidity: 50)
        atThreshold.weatherCondition = .clear
        atThreshold.cloudCover = 0
        #expect(WeatherBackdropPalette.palette(for: atThreshold) == .brightBlue)

        let belowThreshold = WeatherData(temperature: WeatherBackdropPalette.warmThresholdF - 1, feelsLike: 0, humidity: 50)
        belowThreshold.weatherCondition = .clear
        belowThreshold.cloudCover = 0
        #expect(WeatherBackdropPalette.palette(for: belowThreshold) == .calmBlue)
    }

    @Test("Temperature exactly at the cold threshold is frozen, one above is calm")
    func coldThresholdBoundary() {
        let atThreshold = WeatherData(temperature: WeatherBackdropPalette.coldThresholdF, feelsLike: 0, humidity: 50)
        atThreshold.weatherCondition = .clear
        atThreshold.cloudCover = 0
        #expect(WeatherBackdropPalette.palette(for: atThreshold) == .frozenBlue)

        let aboveThreshold = WeatherData(temperature: WeatherBackdropPalette.coldThresholdF + 1, feelsLike: 0, humidity: 50)
        aboveThreshold.weatherCondition = .clear
        aboveThreshold.cloudCover = 0
        #expect(WeatherBackdropPalette.palette(for: aboveThreshold) == .calmBlue)
    }
}
