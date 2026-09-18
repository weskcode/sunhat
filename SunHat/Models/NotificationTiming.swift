//
//  NotificationTiming.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation

enum NotificationTiming: String, CaseIterable, Codable {
    case immediate = "immediate"
    case fifteenMinutes = "fifteen_minutes"
    case thirtyMinutes = "thirty_minutes"
    case oneHour = "one_hour"
    case twoHours = "two_hours"
    case fourHours = "four_hours"
    case sixHours = "six_hours"
    case twelveHours = "twelve_hours"
    case oneDayBefore = "one_day_before"
    
    var displayName: String {
        switch self {
        case .immediate:
            return String(localized: "Immediately", comment: "Notification timing option")
        case .fifteenMinutes:
            return String(localized: "15 minutes before", comment: "Notification timing option")
        case .thirtyMinutes:
            return String(localized: "30 minutes before", comment: "Notification timing option")
        case .oneHour:
            return String(localized: "1 hour before", comment: "Notification timing option")
        case .twoHours:
            return String(localized: "2 hours before", comment: "Notification timing option")
        case .fourHours:
            return String(localized: "4 hours before", comment: "Notification timing option")
        case .sixHours:
            return String(localized: "6 hours before", comment: "Notification timing option")
        case .twelveHours:
            return String(localized: "12 hours before", comment: "Notification timing option")
        case .oneDayBefore:
            return String(localized: "1 day before", comment: "Notification timing option")
        }
    }
    
    var icon: String {
        switch self {
        case .immediate:
            return "bolt.fill"
        case .fifteenMinutes:
            return "clock.badge.fill"
        case .thirtyMinutes:
            return "clock.fill"
        case .oneHour:
            return "clock.arrow.circlepath"
        case .twoHours:
            return "timer"
        case .fourHours:
            return "hourglass"
        case .sixHours:
            return "hourglass.tophalf.filled"
        case .twelveHours:
            return "moon.fill"
        case .oneDayBefore:
            return "calendar.badge.clock"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        case .twoHours:
            return 2 * 60 * 60
        case .fourHours:
            return 4 * 60 * 60
        case .sixHours:
            return 6 * 60 * 60
        case .twelveHours:
            return 12 * 60 * 60
        case .oneDayBefore:
            return 24 * 60 * 60
        }
    }
}

// ActivityCategory and ConditionType enums moved to avoid redeclaration conflicts
// ActivityCategory is defined in UserPreferences.swift as ActivityInterest
// ConditionType is defined in TriggerCondition.swift as TriggerType

enum TemperatureUnit: String, CaseIterable, Codable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"
    
    var symbol: String {
        switch self {
        case .fahrenheit:
            return "°F"
        case .celsius:
            return "°C"
        }
    }
    
    var shortName: String {
        switch self {
        case .fahrenheit:
            return String(localized: "Fahrenheit", comment: "Temperature unit name")
        case .celsius:
            return String(localized: "Celsius", comment: "Temperature unit name")
        }
    }

    /// Converts a canonical Fahrenheit-stored temperature into this unit for
    /// display/editing. Weather data and `TriggerCondition` values are always
    /// stored in Fahrenheit (matching the raw WeatherKit/OpenWeatherMap unit),
    /// so this is the single conversion every display site should use.
    func fromFahrenheit(_ fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: return fahrenheit
        case .celsius: return (fahrenheit - 32) * 5 / 9
        }
    }

    /// Inverse of `fromFahrenheit`: converts a value edited in this unit back
    /// to canonical Fahrenheit for storage.
    func toFahrenheit(_ value: Double) -> Double {
        switch self {
        case .fahrenheit: return value
        case .celsius: return value * 9 / 5 + 32
        }
    }

    /// Converts a temperature *difference* (e.g. a ± tolerance), scale only,
    /// no zero-point offset — unlike `fromFahrenheit`, which converts an
    /// absolute reading.
    func fromFahrenheitDelta(_ delta: Double) -> Double {
        switch self {
        case .fahrenheit: return delta
        case .celsius: return delta * 5 / 9
        }
    }
}
