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

        let snapshot = NextReadyReminderSelector.snapshot(from: reminders, matchingReminderIDs: Set(reminders.map(\.id)))

        #expect(snapshot == .unavailable)
    }

    @Test("Highest priority ready reminder is selected first")
    func highestPriorityReminderIsSelected() {
        let now = Date()
        let normal = makeReminder(title: "Normal task", priority: .normal, createdDate: now.addingTimeInterval(60))
        let urgent = makeReminder(title: "Urgent task", priority: .urgent, createdDate: now)

        let snapshot = NextReadyReminderSelector.snapshot(from: [normal, urgent], matchingReminderIDs: [normal.id, urgent.id])

        #expect(snapshot.title == "Urgent task")
        #expect(snapshot.isReady == true)
    }

    @Test("Newer reminders win when priority matches")
    func newerReminderWinsWhenPriorityMatches() {
        let now = Date()
        let older = makeReminder(title: "Older task", createdDate: now)
        let newer = makeReminder(title: "Newer task", createdDate: now.addingTimeInterval(60))

        let snapshot = NextReadyReminderSelector.snapshot(from: [older, newer], matchingReminderIDs: [older.id, newer.id])

        #expect(snapshot.title == "Newer task")
    }

    @Test("Blank compact reminder titles use an untitled fallback")
    func blankTitlesUseFallback() {
        let reminder = makeReminder(title: "   ")
        let snapshot = NextReadyReminderSelector.snapshot(from: [reminder], matchingReminderIDs: [reminder.id])

        #expect(snapshot.title == String(localized: "Untitled Reminder", comment: "Fallback title for a reminder with no title, shown on compact surfaces"))
    }

    @Test("Compact snapshot uses category icon and default trigger copy")
    func snapshotUsesCategoryIconAndDefaultTriggerCopy() {
        let reminder = makeReminder(title: "Morning run", category: .exercise)
        let snapshot = NextReadyReminderSelector.snapshot(from: [reminder], matchingReminderIDs: [reminder.id])

        #expect(snapshot.systemImageName == "figure.run")
        #expect(snapshot.subtitle == String(localized: "Ready when the weather matches.", comment: "Compact surface summary when a reminder has no specific trigger condition"))
    }

    @Test("Snapshot round-trips through Codable for widget/watch transport")
    func snapshotRoundTripsThroughCodable() throws {
        let reminder = makeReminder(title: "Morning run", category: .exercise, priority: .urgent)
        let original = NextReadyReminderSelector.snapshot(from: [reminder], matchingReminderIDs: [reminder.id])

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

    @Test("Range summaries show both saved bounds in the selected unit")
    func rangeSummaryUsesSavedBounds() {
        let condition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        condition.minTemperature = 85
        condition.maxTemperature = 100
        let display = ModelDataConverter.convertTriggerCondition(condition)
        #expect(display.temperatureSummary(unit: .fahrenheit) == "When temperature is between 85° and 100°")
        #expect(display.temperatureSummary(unit: .celsius) == "When temperature is between 29° and 38°")
    }

    @Test("Incomplete ranges do not describe one target as between")
    func incompleteRangeDoesNotUseDefaultTarget() {
        let condition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        condition.minTemperature = 85
        let display = ModelDataConverter.convertTriggerCondition(condition)
        #expect(display.temperatureSummary(unit: .fahrenheit) == String(localized: "No trigger condition set"))
    }

    @Test("An active reminder is not ready without a matching evaluation")
    func activeDoesNotImplyReady() {
        let reminder = makeReminder(title: "Unmatched task")
        #expect(NextReadyReminderSelector.snapshot(from: [reminder]) == .unavailable)
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
