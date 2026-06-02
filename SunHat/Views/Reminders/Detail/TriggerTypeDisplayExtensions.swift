//
//  TriggerTypeDisplayExtensions.swift
//  SunHat
//

import SwiftUI

extension ComparisonType {
    var displayName: String {
        switch self {
        case .above: return "above"
        case .below: return "below"
        case .equals: return "exactly"
        case .between: return "between"
        }
    }
}

extension TriggerType {
    var displayName: String {
        switch self {
        case .exactTemperature: return "Exact"
        case .temperatureRange: return "Range"
        case .consecutiveDays: return "Trend"
        case .averageTemperature: return "Average"
        case .seasonalMarker: return "Seasonal"
        case .composite: return "Complex"
        case .historicalComparison: return "Historical"
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
        case .exactTemperature: return "Trigger at specific temperature"
        case .temperatureRange: return "Trigger within temperature range"
        case .consecutiveDays: return "Trigger on temperature trends"
        case .averageTemperature: return "Trigger on average over time"
        case .seasonalMarker: return "Trigger on seasonal changes"
        case .composite: return "Multiple conditions required"
        case .historicalComparison: return "Compare to past years"
        }
    }
}
