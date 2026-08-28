//
//  NextReadyReminderSnapshot.swift
//  SunHat
//

import Foundation

/// Compact, transport-ready description of the highest-priority ready reminder.
/// `Codable` so it can back a WidgetKit `TimelineEntry` and travel over
/// `WatchConnectivity` to a watch complication. `Sendable` for actor/timeline boundaries.
struct NextReadyReminderSnapshot: Equatable, Sendable, Codable {
    let id: UUID?
    let title: String
    let subtitle: String
    let systemImageName: String
    let isReady: Bool

    static let unavailable = NextReadyReminderSnapshot(
        id: nil,
        title: String(localized: "No Ready Reminder", comment: "Compact surface title when no reminder is currently ready"),
        subtitle: String(localized: "SunHat is watching your weather tasks.", comment: "Compact surface subtitle when no reminder is currently ready"),
        systemImageName: "bell",
        isReady: false
    )
}

enum NextReadyReminderSelector {
    static func snapshot(from reminders: [WeatherReminderDisplay]) -> NextReadyReminderSnapshot {
        guard let reminder = reminders
            .filter(\.isReadyForCompactSurfaces)
            .sorted(by: compactReminderSort)
            .first else {
            return .unavailable
        }

        return NextReadyReminderSnapshot(
            id: reminder.id,
            title: reminder.displayTitle,
            subtitle: reminder.compactTriggerSummary,
            systemImageName: reminder.category.iconName,
            isReady: true
        )
    }

    private static func compactReminderSort(_ first: WeatherReminderDisplay, _ second: WeatherReminderDisplay) -> Bool {
        let firstPriorityOrder = first.priority.sortOrder
        let secondPriorityOrder = second.priority.sortOrder

        if firstPriorityOrder != secondPriorityOrder {
            return firstPriorityOrder < secondPriorityOrder
        }

        return first.createdDate > second.createdDate
    }
}

private extension WeatherReminderDisplay {
    var isReadyForCompactSurfaces: Bool {
        isActive && !isCompleted && !isPaused
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Untitled Reminder", comment: "Fallback title for a reminder with no title, shown on compact surfaces") : title
    }

    var compactTriggerSummary: String {
        guard let triggerCondition else {
            return String(localized: "Ready when the weather matches.", comment: "Compact surface summary when a reminder has no specific trigger condition")
        }

        if let minTemperature = triggerCondition.minTemperature,
           let maxTemperature = triggerCondition.maxTemperature {
            return "\(Int(minTemperature))-\(Int(maxTemperature))°"
        }

        return "\(Int(triggerCondition.targetTemperature))° \(triggerCondition.comparisonType.rawValue)"
    }
}
