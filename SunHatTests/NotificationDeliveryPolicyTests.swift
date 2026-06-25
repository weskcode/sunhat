//
//  NotificationDeliveryPolicyTests.swift
//  SunHatTests
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct NotificationDeliveryPolicyTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// June 10, 2026 is a Wednesday.
    private func weekday(at hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: hour, minute: minute))!
    }

    /// June 13, 2026 is a Saturday.
    private func weekend(at hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: hour))!
    }

    private func makePreferences(
        notificationsEnabled: Bool = true,
        quietHoursEnabled: Bool = false,
        quietStart: (Int, Int) = (22, 0),
        quietEnd: (Int, Int) = (7, 0),
        allowWeekends: Bool = true
    ) -> UserPreferences {
        let preferences = UserPreferences()
        preferences.notificationsEnabled = notificationsEnabled
        preferences.quietHoursEnabled = quietHoursEnabled
        preferences.quietHoursStart = calendar.date(from: DateComponents(hour: quietStart.0, minute: quietStart.1))!
        preferences.quietHoursEnd = calendar.date(from: DateComponents(hour: quietEnd.0, minute: quietEnd.1))!
        preferences.allowWeekendNotifications = allowWeekends
        return preferences
    }

    @Test("Master switch off blocks delivery at any time")
    func masterSwitchBlocksDelivery() {
        let preferences = makePreferences(notificationsEnabled: false)
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 12), calendar: calendar) == false)
    }

    @Test("Defaults allow delivery during the day")
    func defaultsAllowDaytimeDelivery() {
        let preferences = makePreferences()
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 12), calendar: calendar))
    }

    @Test("Quiet hours crossing midnight block evening, night, and early morning")
    func quietHoursWrapMidnight() {
        let preferences = makePreferences(quietHoursEnabled: true)

        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 23), calendar: calendar) == false)
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 2), calendar: calendar) == false)
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 6, minute: 59), calendar: calendar) == false)
        // Boundaries: starts at exactly 22:00, ends at exactly 07:00.
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 22), calendar: calendar) == false)
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 7), calendar: calendar))
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 12), calendar: calendar))
    }

    @Test("Quiet hours within a single day block only that window")
    func quietHoursSameDayWindow() {
        let preferences = makePreferences(quietHoursEnabled: true, quietStart: (13, 0), quietEnd: (15, 0))

        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 14), calendar: calendar) == false)
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 12), calendar: calendar))
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 16), calendar: calendar))
    }

    @Test("An empty quiet-hours window never blocks")
    func equalStartAndEndNeverBlocks() {
        let preferences = makePreferences(quietHoursEnabled: true, quietStart: (9, 0), quietEnd: (9, 0))
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 9), calendar: calendar))
    }

    @Test("Disallowed weekends block Saturday but not Wednesday")
    func weekendRule() {
        let preferences = makePreferences(allowWeekends: false)

        #expect(preferences.allowsNotificationDelivery(at: weekend(at: 12), calendar: calendar) == false)
        #expect(preferences.allowsNotificationDelivery(at: weekday(at: 12), calendar: calendar))
    }

    @Test("Daily limit blocks after the maximum count is reached")
    func dailyLimitEnforced() {
        let preferences = makePreferences()
        preferences.maximumDailyNotifications = 2
        let now = weekday(at: 12)

        #expect(preferences.allowsNotificationDelivery(at: now, calendar: calendar))
        preferences.recordNotificationDelivered(at: now, calendar: calendar)
        #expect(preferences.allowsNotificationDelivery(at: now, calendar: calendar))
        preferences.recordNotificationDelivered(at: now, calendar: calendar)
        // At the limit — should now be blocked
        #expect(preferences.allowsNotificationDelivery(at: now, calendar: calendar) == false)
    }

    @Test("Daily count resets on a new calendar day")
    func dailyCountResetsNextDay() {
        let preferences = makePreferences()
        preferences.maximumDailyNotifications = 1
        let today = weekday(at: 12)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        preferences.recordNotificationDelivered(at: today, calendar: calendar)
        #expect(preferences.allowsNotificationDelivery(at: today, calendar: calendar) == false)
        // New day — count should be treated as 0
        #expect(preferences.allowsNotificationDelivery(at: tomorrow, calendar: calendar))
    }

    @Test("recordNotificationDelivered increments within a day and resets on new day")
    func recordDeliveryCountBehavior() {
        let preferences = makePreferences()
        let today = weekday(at: 10)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        preferences.recordNotificationDelivered(at: today, calendar: calendar)
        #expect(preferences.dailyNotificationCount == 1)
        preferences.recordNotificationDelivered(at: today, calendar: calendar)
        #expect(preferences.dailyNotificationCount == 2)
        // Cross day boundary
        preferences.recordNotificationDelivered(at: tomorrow, calendar: calendar)
        #expect(preferences.dailyNotificationCount == 1)
    }
}
