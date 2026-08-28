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

        #expect(snapshot.title == String(localized: "Untitled Reminder", comment: "Fallback title for a reminder with no title, shown on compact surfaces"))
    }

    @Test("Compact snapshot uses category icon and default trigger copy")
    func snapshotUsesCategoryIconAndDefaultTriggerCopy() {
        let snapshot = NextReadyReminderSelector.snapshot(from: [
            makeReminder(title: "Morning run", category: .exercise)
        ])

        #expect(snapshot.systemImageName == "figure.run")
        #expect(snapshot.subtitle == String(localized: "Ready when the weather matches.", comment: "Compact surface summary when a reminder has no specific trigger condition"))
    }

    @Test("Snapshot round-trips through Codable for widget/watch transport")
    func snapshotRoundTripsThroughCodable() throws {
        let original = NextReadyReminderSelector.snapshot(from: [
            makeReminder(title: "Morning run", category: .exercise, priority: .urgent)
        ])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NextReadyReminderSnapshot.self, from: data)

        #expect(decoded == original)
    }

    @Test("The unavailable snapshot round-trips through Codable")
    func unavailableSnapshotRoundTrips() throws {
        let data = try JSONEncoder().encode(NextReadyReminderSnapshot.unavailable)
        let decoded = try JSONDecoder().decode(NextReadyReminderSnapshot.self, from: data)

        #expect(decoded == .unavailable)
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
