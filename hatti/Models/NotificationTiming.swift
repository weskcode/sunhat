//
//  NotificationTiming.swift
//  hatti
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
            return "Immediately"
        case .fifteenMinutes:
            return "15 minutes before"
        case .thirtyMinutes:
            return "30 minutes before"
        case .oneHour:
            return "1 hour before"
        case .twoHours:
            return "2 hours before"
        case .fourHours:
            return "4 hours before"
        case .sixHours:
            return "6 hours before"
        case .twelveHours:
            return "12 hours before"
        case .oneDayBefore:
            return "1 day before"
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
            return "Fahrenheit"
        case .celsius:
            return "Celsius"
        }
    }
}