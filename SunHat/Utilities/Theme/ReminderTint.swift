//
//  ReminderTint.swift
//  SunHat
//

import SwiftUI

/// The stable palette behind the creation screen's color picker. Raw values
/// are persisted on WeatherReminder.customTintName, so they must never change
/// or be localized.
/// Nonisolated: a pure value table that must be readable from nonisolated
/// model types (WeatherReminder) as well as MainActor views.
nonisolated enum ReminderTint: String, CaseIterable {
    case blue, purple, pink, red, orange, yellow, green, teal, cyan, indigo, mint, brown

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .mint: return .mint
        case .brown: return .brown
        }
    }

    /// Maps one of the picker's preset Colors back to its stable name.
    static func name(for color: Color) -> String? {
        allCases.first { $0.color == color }?.rawValue
    }
}

extension WeatherReminder {
    /// The user-chosen tint, or nil when the category default should be used.
    var displayTint: Color? {
        customTintName.flatMap { ReminderTint(rawValue: $0)?.color }
    }
}

extension WeatherReminderDisplay {
    var displayTint: Color? {
        customTintName.flatMap { ReminderTint(rawValue: $0)?.color }
    }
}
