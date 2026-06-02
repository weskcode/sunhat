//
//  NextReadyReminderSnapshot.swift
//  SunHat
//

import Foundation

struct NextReadyReminderSnapshot: Equatable, Sendable {
    let id: UUID?
    let title: String
    let subtitle: String
    let systemImageName: String
    let isReady: Bool

    static let unavailable = NextReadyReminderSnapshot(
        id: nil,
        title: "No Ready Reminder",
        subtitle: "SunHat is watching your weather tasks.",
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
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Reminder" : title
    }

    var compactTriggerSummary: String {
        guard let triggerCondition else {
            return "Ready when the weather matches."
        }

        if let minTemperature = triggerCondition.minTemperature,
           let maxTemperature = triggerCondition.maxTemperature {
            return "\(Int(minTemperature))-\(Int(maxTemperature))°"
        }

        return "\(Int(triggerCondition.targetTemperature))° \(triggerCondition.comparisonType.rawValue)"
    }
}
