//
//  WeatherBackdropPalette.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import Foundation

enum WeatherBackdropPalette: String, CaseIterable, Sendable {
    case calmBlue
    case brightBlue
    case overcastBlue
    case stormBlue
    case frozenBlue

    static let warmThresholdF = 78.0
    static let coldThresholdF = 45.0
    static let cloudyCloudCoverThreshold = 55

    static func palette(for weatherData: WeatherData) -> WeatherBackdropPalette {
        switch weatherData.weatherCondition {
        case .rain, .drizzle, .thunderstorm:
            return .stormBlue
        case .snow, .sleet, .hail:
            return .frozenBlue
        case .cloudy, .overcast, .fog, .windy:
            return .overcastBlue
        case .clear, .partlyCloudy, .unknown:
            break
        }

        if weatherData.cloudCover >= cloudyCloudCoverThreshold {
            return .overcastBlue
        }

        if weatherData.temperature <= coldThresholdF {
            return .frozenBlue
        }

        if weatherData.temperature >= warmThresholdF {
            return .brightBlue
        }

        return .calmBlue
    }
}
