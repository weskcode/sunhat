//
//  NextReadyReminderSelectorTests.swift
//  SunHatTests
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct NextReadyReminderSelectorTests {
    @Test("Empty reminders return the unavailable compact snapshot")
    func emptyRemindersReturnUnavailableSnapshot() {
        let snapshot = NextReadyReminderSelector.snapshot(from: [])

        #expect(snapshot == .unavailable)
    }

    @Test("Inactive completed and paused reminders are not exposed to compact surfaces")
    func inactiveRemindersAreExcluded() {
        let reminders = [
            makeReminder(title: "Inactive", isActive: false),
            makeReminder(title: "Completed", isCompleted: true),
            makeReminder(title: "Paused", isPaused: true)
        ]

        let snapshot = NextReadyReminderSelector.snapshot(from: reminders)

        #expect(snapshot == .unavailable)
    }

    @Test("Highest priority ready reminder is selected first")
    func highestPriorityReminderIsSelected() {
        let now = Date()
        let normal = makeReminder(title: "Normal task", priority: .normal, createdDate: now.addingTimeInterval(60))
        let urgent = makeReminder(title: "Urgent task", priority: .urgent, createdDate: now)

        let snapshot = NextReadyReminderSelector.snapshot(from: [normal, urgent])

        #expect(snapshot.title == "Urgent task")
        #expect(snapshot.isReady == true)
    }

    @Test("Newer reminders win when priority matches")
    func newerReminderWinsWhenPriorityMatches() {
        let now = Date()
        let older = makeReminder(title: "Older task", createdDate: now)
        let newer = makeReminder(title: "Newer task", createdDate: now.addingTimeInterval(60))

        let snapshot = NextReadyReminderSelector.snapshot(from: [older, newer])

        #expect(snapshot.title == "Newer task")
    }

    @Test("Blank compact reminder titles use an untitled fallback")
    func blankTitlesUseFallback() {
        let snapshot = NextReadyReminderSelector.snapshot(from: [
            makeReminder(title: "   ")
        ])

        #expect(snapshot.title == "Untitled Reminder")
    }

    @Test("Compact snapshot uses category icon and default trigger copy")
    func snapshotUsesCategoryIconAndDefaultTriggerCopy() {
        let snapshot = NextReadyReminderSelector.snapshot(from: [
            makeReminder(title: "Morning run", category: .exercise)
        ])

        #expect(snapshot.systemImageName == "figure.run")
        #expect(snapshot.subtitle == "Ready when the weather matches.")
    }

    private func makeReminder(
        id: UUID = UUID(),
        title: String,
        category: ReminderCategory = .general,
        isActive: Bool = true,
        isCompleted: Bool = false,
        isPaused: Bool = false,
        priority: ReminderPriority = .normal,
        createdDate: Date = Date()
    ) -> WeatherReminderDisplay {
        WeatherReminderDisplay(
            id: id,
            title: title,
            reminderDescription: "",
            category: category,
            isActive: isActive,
            isCompleted: isCompleted,
            isPaused: isPaused,
            priority: priority,
            createdDate: createdDate,
            lastTriggered: nil,
            triggerCondition: nil,
            location: nil
        )
    }
}
