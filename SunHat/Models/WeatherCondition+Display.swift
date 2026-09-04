//
//  WeatherCondition+Display.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/2/26.
//

import SwiftUI

extension WeatherCondition {
    var iconName: String {
        switch self {
        case .clear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy, .overcast:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .fog:
            return "cloud.fog.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .clear:
            return .orange
        case .partlyCloudy:
            return .yellow
        case .cloudy, .overcast:
            return .gray
        case .rain, .thunderstorm:
            return .blue
        case .snow:
            return .cyan
        case .fog:
            return .gray
        default:
            return .gray
        }
    }
}
