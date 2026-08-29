//
//  ReminderNotificationScheduleEditingTests.swift
//  SunHatTests
//
//  Covers the round-trip between NotificationConfig's stored delivery window
//  (avoidNighttime/preferredStartHour/preferredEndHour) and the TimeRange the
//  detail screen's editor presents, plus saveChanges persisting edits to the
//  per-reminder quiet-hours opt-out and delivery window.
//

import Foundation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct NotificationConfigTimeRangeTests {

    @Test(
        "Each TimeRange round-trips through NotificationConfig unchanged",
        arguments: [TimeRange.morning, .afternoon, .evening, .allDay]
    )
    func timeRangeRoundTrips(range: TimeRange) {
        let config = NotificationConfig(title: "", message: "")
        config.avoidNighttime = range != .allDay
        config.preferredStartHour = range.hours.lowerBound
        config.preferredEndHour = range.hours.upperBound

        #expect(config.preferredTimeRange == range)
    }

    @Test("A window that doesn't match any preset falls back to allDay")
    func nonMatchingWindowFallsBackToAllDay() {
        let config = NotificationConfig(title: "", message: "")
        config.avoidNighttime = true
        config.preferredStartHour = 3
        config.preferredEndHour = 4

        #expect(config.preferredTimeRange == .allDay)
    }

    @Test("avoidNighttime false always reads as allDay regardless of stored hours")
    func allDayIgnoresStoredHours() {
        let config = NotificationConfig(title: "", message: "")
        config.avoidNighttime = false
        config.preferredStartHour = TimeRange.evening.hours.lowerBound
        config.preferredEndHour = TimeRange.evening.hours.upperBound

        #expect(config.preferredTimeRange == .allDay)
    }

    @Test("EditableNotificationConfig with no backing config defaults to allDay and respects quiet hours")
    func editableDefaultsWithNoConfig() {
        let editable = EditableNotificationConfig(from: nil)
        #expect(editable.preferredTimeRange == .allDay)
        #expect(editable.respectsQuietHours == true)
    }

    @Test("EditableNotificationConfig reads an existing config's schedule")
    func editableReadsExistingSchedule() {
        let config = NotificationConfig(title: "", message: "")
        config.respectsQuietHours = false
        config.avoidNighttime = true
        config.preferredStartHour = TimeRange.morning.hours.lowerBound
        config.preferredEndHour = TimeRange.morning.hours.upperBound

        let editable = EditableNotificationConfig(from: config)
        #expect(editable.respectsQuietHours == false)
        #expect(editable.preferredTimeRange == .morning)
    }
}

@MainActor
struct DetailedReminderScheduleEditingTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self,
            UserPreferences.self,
            SavedLocation.self,
            LocationHistory.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    private func makeReminder(withConfig: Bool) -> WeatherReminder {
        let reminder = WeatherReminder(title: "Evening Walk")
        reminder.triggerCondition = TriggerCondition()
        reminder.location = LocationData(latitude: 47.6062, longitude: -122.3321)
        if withConfig {
            reminder.notificationConfig = NotificationConfig(title: "", message: "")
        }
        modelContext.insert(reminder)
        return reminder
    }

    @Test("Saving changes persists a new preferred time range and quiet-hours opt-out")
    func saveChangesPersistsSchedule() async throws {
        let reminder = makeReminder(withConfig: true)
        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: modelContext)

        var edited = EditableReminder(from: reminder)
        edited.notificationConfig.preferredTimeRange = .morning
        edited.notificationConfig.respectsQuietHours = false

        let success = await viewModel.saveChanges(edited)
        #expect(success == true)

        let config = try #require(reminder.notificationConfig)
        #expect(config.respectsQuietHours == false)
        #expect(config.avoidNighttime == true)
        #expect(config.preferredStartHour == TimeRange.morning.hours.lowerBound)
        #expect(config.preferredEndHour == TimeRange.morning.hours.upperBound)
    }

    @Test("Saving changes on a reminder with no prior config creates one with the edited schedule")
    func saveChangesCreatesConfigWhenMissing() async throws {
        let reminder = makeReminder(withConfig: false)
        #expect(reminder.notificationConfig == nil)

        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: modelContext)

        var edited = EditableReminder(from: reminder)
        edited.notificationConfig.preferredTimeRange = .evening
        edited.notificationConfig.respectsQuietHours = true

        let success = await viewModel.saveChanges(edited)
        #expect(success == true)

        let config = try #require(reminder.notificationConfig)
        #expect(config.preferredTimeRange == .evening)
    }

    @Test("Selecting allDay clears the quiet-hours delivery window restriction")
    func saveChangesAllDayClearsWindow() async throws {
        let reminder = makeReminder(withConfig: true)
        reminder.notificationConfig?.avoidNighttime = true
        reminder.notificationConfig?.preferredStartHour = TimeRange.evening.hours.lowerBound
        reminder.notificationConfig?.preferredEndHour = TimeRange.evening.hours.upperBound

        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: modelContext)

        var edited = EditableReminder(from: reminder)
        edited.notificationConfig.preferredTimeRange = .allDay

        let success = await viewModel.saveChanges(edited)
        #expect(success == true)

        let config = try #require(reminder.notificationConfig)
        #expect(config.avoidNighttime == false)
    }
}
