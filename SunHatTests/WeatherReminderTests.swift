//
//  WeatherReminderTests.swift
//  SunHatTests
//
//  Covers WeatherReminder lifecycle, activation state, and trigger gating —
//  the core domain logic behind the app's reminders.
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct WeatherReminderTests {

    // MARK: - Display helpers

    @Test("Empty titles fall back to a placeholder display title")
    func displayTitleFallsBackWhenEmpty() {
        let reminder = WeatherReminder(title: "")
        #expect(reminder.displayTitle == "Untitled Reminder")
    }

    @Test("Non-empty titles are used verbatim as the display title")
    func displayTitleUsesProvidedTitle() {
        let reminder = WeatherReminder(title: "Water the plants")
        #expect(reminder.displayTitle == "Water the plants")
    }

    @Test("Short description prefers the reminder description when present")
    func shortDescriptionPrefersDescription() {
        let reminder = WeatherReminder(title: "Run", reminderDescription: "Morning jog")
        #expect(reminder.shortDescription == "Morning jog")
    }

    @Test("Short description falls back to generic copy with no description or condition")
    func shortDescriptionFallsBackToGeneric() {
        let reminder = WeatherReminder(title: "Run")
        #expect(reminder.shortDescription == "Weather reminder")
    }

    // MARK: - Status text state machine

    @Test("Inactive reminders report Inactive regardless of other flags")
    func statusTextInactiveTakesPriority() {
        let reminder = WeatherReminder(title: "Test")
        reminder.isActive = false
        reminder.isPaused = true
        #expect(reminder.statusText == "Inactive")
    }

    @Test("Paused active reminders report Paused")
    func statusTextPaused() {
        let reminder = WeatherReminder(title: "Test")
        reminder.isPaused = true
        #expect(reminder.statusText == "Paused")
    }

    @Test("Completed active reminders report Completed")
    func statusTextCompleted() {
        let reminder = WeatherReminder(title: "Test")
        reminder.isCompleted = true
        #expect(reminder.statusText == "Completed")
    }

    @Test("Snoozed reminders report Snoozed while the snooze window is in the future")
    func statusTextSnoozed() {
        let reminder = WeatherReminder(title: "Test")
        reminder.snoozedUntil = Date().addingTimeInterval(3600)
        #expect(reminder.statusText == "Snoozed")
    }

    @Test("Default reminders report Active")
    func statusTextActive() {
        let reminder = WeatherReminder(title: "Test")
        #expect(reminder.statusText == "Active")
    }

    // MARK: - isCurrentlyActive

    @Test("A fresh reminder is currently active")
    func freshReminderIsCurrentlyActive() {
        let reminder = WeatherReminder(title: "Test")
        #expect(reminder.isCurrentlyActive == true)
    }

    @Test("A snooze window in the future suppresses activity")
    func futureSnoozeSuppressesActivity() {
        let reminder = WeatherReminder(title: "Test")
        reminder.snoozedUntil = Date().addingTimeInterval(3600)
        #expect(reminder.isCurrentlyActive == false)
    }

    @Test("A snooze window in the past does not suppress activity")
    func pastSnoozeDoesNotSuppressActivity() {
        let reminder = WeatherReminder(title: "Test")
        reminder.snoozedUntil = Date().addingTimeInterval(-3600)
        #expect(reminder.isCurrentlyActive == true)
    }

    @Test("A scheduled start in the future suppresses activity")
    func futureStartSuppressesActivity() {
        let reminder = WeatherReminder(title: "Test")
        reminder.scheduledStartDate = Date().addingTimeInterval(3600)
        #expect(reminder.isCurrentlyActive == false)
    }

    @Test("A scheduled end in the past suppresses activity")
    func pastEndSuppressesActivity() {
        let reminder = WeatherReminder(title: "Test")
        reminder.scheduledEndDate = Date().addingTimeInterval(-3600)
        #expect(reminder.isCurrentlyActive == false)
    }

    @Test("Reaching the maximum trigger count suppresses activity")
    func maxTriggersReachedSuppressesActivity() {
        let reminder = WeatherReminder(title: "Test")
        reminder.maxTriggers = 3
        reminder.triggerCount = 3
        #expect(reminder.isCurrentlyActive == false)
    }

    @Test("Below the maximum trigger count the reminder stays active")
    func belowMaxTriggersStaysActive() {
        let reminder = WeatherReminder(title: "Test")
        reminder.maxTriggers = 3
        reminder.triggerCount = 2
        #expect(reminder.isCurrentlyActive == true)
    }

    // MARK: - canTrigger / cooldown

    @Test("A reminder with no notification config can trigger")
    func canTriggerWithoutConfig() {
        let reminder = WeatherReminder(title: "Test")
        #expect(reminder.canTrigger == true)
    }

    @Test("A reminder still within its cooldown window cannot trigger")
    func cannotTriggerDuringCooldown() {
        let reminder = WeatherReminder(title: "Test")
        let config = NotificationConfig()
        config.cooldownPeriodHours = 6
        reminder.notificationConfig = config
        reminder.lastTriggered = Date().addingTimeInterval(-3600) // 1 hour ago, cooldown is 6h
        #expect(reminder.canTrigger == false)
    }

    @Test("A reminder past its cooldown window can trigger again")
    func canTriggerAfterCooldown() {
        let reminder = WeatherReminder(title: "Test")
        let config = NotificationConfig()
        config.cooldownPeriodHours = 6
        reminder.notificationConfig = config
        reminder.lastTriggered = Date().addingTimeInterval(-7 * 3600) // 7 hours ago, cooldown is 6h
        #expect(reminder.canTrigger == true)
    }

    @Test("An inactive reminder can never trigger")
    func inactiveReminderCannotTrigger() {
        let reminder = WeatherReminder(title: "Test")
        reminder.isActive = false
        #expect(reminder.canTrigger == false)
    }

    // MARK: - Lifecycle mutations

    @Test("Triggering increments counts and records the trigger time")
    func triggerUpdatesCounters() throws {
        let reminder = WeatherReminder(title: "Test")
        let before = reminder.triggerCount

        reminder.trigger()

        #expect(reminder.triggerCount == before + 1)
        #expect(reminder.totalNotificationsSent == 1)
        #expect(reminder.lastTriggered != nil)
    }

    @Test("Triggering is a no-op once the reminder can no longer trigger")
    func triggerIsNoOpWhenNotAllowed() {
        let reminder = WeatherReminder(title: "Test")
        reminder.isActive = false

        reminder.trigger()

        #expect(reminder.triggerCount == 0)
        #expect(reminder.lastTriggered == nil)
    }

    @Test("Completing marks the reminder complete and records the completion")
    func completeMarksDone() throws {
        let reminder = WeatherReminder(title: "Test")

        reminder.complete()

        #expect(reminder.isCompleted == true)
        #expect(reminder.completedDate != nil)
        #expect(reminder.successfulCompletions == 1)
    }

    @Test("Snoozing sets a future snooze window")
    func snoozeSetsFutureWindow() throws {
        let reminder = WeatherReminder(title: "Test")

        reminder.snooze(for: 3)

        let snoozedUntil = try #require(reminder.snoozedUntil)
        #expect(snoozedUntil > Date())
        #expect(reminder.lastUserInteraction != nil)
    }

    @Test("Skipping increments the skipped count")
    func skipIncrementsCount() {
        let reminder = WeatherReminder(title: "Test")

        reminder.skip()

        #expect(reminder.skippedCount == 1)
        #expect(reminder.lastUserInteraction != nil)
    }

    @Test("Pausing then resuming toggles the paused flag and clears any snooze")
    func pauseThenResume() {
        let reminder = WeatherReminder(title: "Test")
        reminder.snoozedUntil = Date().addingTimeInterval(3600)

        reminder.pause()
        #expect(reminder.isPaused == true)

        reminder.resume()
        #expect(reminder.isPaused == false)
        #expect(reminder.snoozedUntil == nil)
    }

    @Test("Lifecycle actions append matching history entries")
    func lifecycleAppendsHistory() {
        let reminder = WeatherReminder(title: "Test")

        reminder.complete()
        reminder.skip()
        reminder.pause()
        reminder.resume()

        let actions = reminder.history.map(\.action)
        #expect(actions.contains(.completed))
        #expect(actions.contains(.skipped))
        #expect(actions.contains(.paused))
        #expect(actions.contains(.resumed))
    }
}

// MARK: - Reminder priority ordering

@MainActor
struct ReminderPriorityTests {
    @Test("Priority sort order ranks urgent highest and low lowest")
    func sortOrderRanking() {
        #expect(ReminderPriority.urgent.sortOrder < ReminderPriority.high.sortOrder)
        #expect(ReminderPriority.high.sortOrder < ReminderPriority.normal.sortOrder)
        #expect(ReminderPriority.normal.sortOrder < ReminderPriority.low.sortOrder)
    }

    @Test("Sorting by sortOrder produces urgent-first ordering")
    func sortingProducesExpectedOrder() {
        let shuffled: [ReminderPriority] = [.low, .urgent, .normal, .high]
        let sorted = shuffled.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted == [.urgent, .high, .normal, .low])
    }
}
