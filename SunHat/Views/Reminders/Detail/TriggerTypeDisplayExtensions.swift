//
//  TriggerTypeDisplayExtensions.swift
//  SunHat
//

import SwiftUI

extension ComparisonType {
    var displayName: String {
        switch self {
        case .above: return String(localized: "above", comment: "Temperature comparison word, e.g. 'temperature is above 70°'")
        case .below: return String(localized: "below", comment: "Temperature comparison word, e.g. 'temperature is below 70°'")
        case .equals: return String(localized: "exactly", comment: "Temperature comparison word, e.g. 'temperature is exactly 70°'")
        case .between: return String(localized: "between", comment: "Temperature comparison word, e.g. 'temperature is between 60° and 70°'")
        }
    }
}

extension TriggerType {
    var displayName: String {
        switch self {
        case .exactTemperature: return String(localized: "Exact", comment: "Trigger type name: exact temperature match")
        case .temperatureRange: return String(localized: "Range", comment: "Trigger type name: temperature range")
        case .consecutiveDays: return String(localized: "Trend", comment: "Trigger type name: consecutive days trend")
        case .averageTemperature: return String(localized: "Average", comment: "Trigger type name: average temperature")
        case .seasonalMarker: return String(localized: "Seasonal", comment: "Trigger type name: seasonal marker")
        case .composite: return String(localized: "Complex", comment: "Trigger type name: multiple combined conditions")
        case .historicalComparison: return String(localized: "Historical", comment: "Trigger type name: historical comparison")
        }
    }

    var iconName: String {
        switch self {
        case .exactTemperature: return "thermometer.medium"
        case .temperatureRange: return "thermometer.variable"
        case .consecutiveDays: return "arrow.up.right"
        case .averageTemperature: return "chart.line.uptrend.xyaxis"
        case .seasonalMarker: return "leaf.fill"
        case .composite: return "gearshape.2"
        case .historicalComparison: return "clock.arrow.circlepath"
        }
    }

    var iconColor: Color {
        switch self {
        case .exactTemperature: return .blue
        case .temperatureRange: return .green
        case .consecutiveDays: return .orange
        case .averageTemperature: return .purple
        case .seasonalMarker: return .brown
        case .composite: return .red
        case .historicalComparison: return .indigo
        }
    }

    var descriptionText: String {
        switch self {
        case .exactTemperature: return String(localized: "Trigger at specific temperature", comment: "Trigger type description")
        case .temperatureRange: return String(localized: "Trigger within temperature range", comment: "Trigger type description")
        case .consecutiveDays: return String(localized: "Trigger on temperature trends", comment: "Trigger type description")
        case .averageTemperature: return String(localized: "Trigger on average over time", comment: "Trigger type description")
        case .seasonalMarker: return String(localized: "Trigger on seasonal changes", comment: "Trigger type description")
        case .composite: return String(localized: "Multiple conditions required", comment: "Trigger type description")
        case .historicalComparison: return String(localized: "Compare to past years", comment: "Trigger type description")
        }
    }
}
