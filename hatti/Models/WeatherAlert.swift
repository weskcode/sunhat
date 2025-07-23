//
//  WeatherAlert.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI

struct WeatherAlert: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let severity: WeatherAlertSeverity
    let type: WeatherAlertType
    let area: String
    let instructions: String?
    let timestamp: Date
    let expiresAt: Date?
    let isActive: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        severity: WeatherAlertSeverity,
        type: WeatherAlertType = .general,
        area: String = "Local Area",
        instructions: String? = nil,
        timestamp: Date = Date(),
        expiresAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.type = type
        self.area = area
        self.instructions = instructions
        self.timestamp = timestamp
        self.expiresAt = expiresAt
        self.isActive = isActive
    }
}

enum WeatherAlertSeverity: String, Codable, CaseIterable, Sendable {
    case minor = "minor"
    case moderate = "moderate"
    case severe = "severe"
    case extreme = "extreme"
    case warning = "warning"
    case advisory = "advisory"
    case watch = "watch"
}

enum WeatherAlertType: String, Codable, CaseIterable, Sendable {
    case general = "general"
    case temperature = "temperature"
    case precipitation = "precipitation"
    case wind = "wind"
    case uv = "uv"
    case airQuality = "air_quality"
    case frost = "frost"
    case heat = "heat"
    case storm = "storm"
    case flood = "flood"
    case tornado = "tornado"
    case hurricane = "hurricane"
    case blizzard = "blizzard"
    case fire = "fire"
}

extension WeatherAlert {
    var iconName: String {
        switch type {
        case .temperature, .heat:
            return "thermometer.sun.fill"
        case .precipitation:
            return "cloud.rain.fill"
        case .wind:
            return "wind"
        case .uv:
            return "sun.max.fill"
        case .airQuality:
            return "leaf.fill"
        case .frost:
            return "thermometer.snowflake"
        case .storm:
            return "cloud.bolt.rain.fill"
        case .flood:
            return "water.waves"
        case .tornado:
            return "tornado"
        case .hurricane:
            return "hurricane"
        case .blizzard:
            return "cloud.snow.fill"
        case .fire:
            return "flame.fill"
        case .general:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var severityColor: Color {
        switch severity {
        case .minor, .advisory:
            return .blue
        case .moderate, .watch:
            return .yellow
        case .severe, .warning:
            return .orange
        case .extreme:
            return .red
        }
    }
    
    var priorityLevel: Int {
        switch severity {
        case .minor: return 1
        case .moderate: return 2
        case .advisory: return 3
        case .watch: return 4
        case .warning: return 5
        case .severe: return 6
        case .extreme: return 7
        }
    }
    
    /// Converts WeatherAlert to WeatherAlertDisplay for UI display
    func toWeatherAlertDisplay() -> WeatherAlertDisplay {
        return WeatherAlertDisplay(
            id: self.id,
            title: self.title,
            description: self.description,
            severity: self.severity,
            type: self.type,
            area: self.area,
            instructions: self.instructions,
            expiresAt: self.expiresAt,
            isActive: self.isActive
        )
    }
}