//
//  ReminderEligibilityTests.swift
//  SunHatTests
//
//  Verifies that evaluation fetching honors the full reminder lifecycle:
//  snoozed, not-yet-started, expired, and max-trigger reminders must never
//  reach the trigger engine.
//

import Foundation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct ReminderEligibilityTests {
    let modelContainer: ModelContainer
    let actor: WeatherModelActor

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
        actor = WeatherModelActor(modelContainer: modelContainer)
    }

    private func insertReminder(
        title: String,
        snoozedUntil: Date? = nil,
        scheduledStartDate: Date? = nil,
        scheduledEndDate: Date? = nil,
        maxTriggers: Int? = nil,
        triggerCount: Int = 0
    ) throws {
        let reminder = WeatherReminder(title: title)
        reminder.isActive = true
        reminder.snoozedUntil = snoozedUntil
        reminder.scheduledStartDate = scheduledStartDate
        reminder.scheduledEndDate = scheduledEndDate
        reminder.maxTriggers = maxTriggers
        reminder.triggerCount = triggerCount
        reminder.triggerCondition = TriggerCondition()
        reminder.location = LocationData(latitude: 40.7128, longitude: -74.0060)
        modelContainer.mainContext.insert(reminder)
        try modelContainer.mainContext.save()
    }

    @Test("An unconstrained active reminder is evaluated")
    func activeReminderIsEvaluated() async throws {
        try insertReminder(title: "Active")
        let data = try await actor.fetchActiveRemindersData()
        #expect(data.count == 1)
    }

    @Test("A snoozed reminder is excluded until its snooze lapses")
    func snoozedReminderIsExcluded() async throws {
        try insertReminder(title: "Snoozed", snoozedUntil: Date().addingTimeInterval(3600))
        let data = try await actor.fetchActiveRemindersData()
        #expect(data.isEmpty)
    }

    @Test("A reminder whose snooze has lapsed is evaluated again")
    func lapsedSnoozeIsEvaluated() async throws {
        try insertReminder(title: "Lapsed", snoozedUntil: Date().addingTimeInterval(-60))
        let data = try await actor.fetchActiveRemindersData()
        #expect(data.count == 1)
    }

    @Test("A reminder scheduled to start in the future is excluded")
    func notYetStartedReminderIsExcluded() async throws {
        try insertReminder(title: "Future", scheduledStartDate: Date().addingTimeInterval(86400))
        let data = try await actor.fetchActiveRemindersData()
        #expect(data.isEmpty)
    }

    @Test("A reminder past its scheduled end date is excluded")
    func expiredReminderIsExcluded() async throws {
        try insertReminder(title: "Expired", scheduledEndDate: Date().addingTimeInterval(-86400))
        let data = try await actor.fetchActiveRemindersData()
        #expect(data.isEmpty)
    }

    @Test("A reminder at its max trigger count is excluded")
    func maxTriggersReminderIsExcluded() async throws {
        try insertReminder(title: "Maxed", maxTriggers: 3, triggerCount: 3)
        let data = try await actor.fetchActiveRemindersData()
        #expect(data.isEmpty)
    }
}
