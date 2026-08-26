import Foundation
import Testing
@testable import SunHat

@MainActor
struct NotificationNavigationHandoffTests {
    @Test("A notification reminder destination is consumed exactly once")
    func destinationIsOneShot() throws {
        let suiteName = "NotificationNavigationHandoffTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let handoff = NotificationNavigationHandoff(defaults: defaults)
        let reminderID = UUID()

        handoff.store(reminderID: reminderID)

        #expect(handoff.consumePendingReminderID() == reminderID)
        #expect(handoff.consumePendingReminderID() == nil)
    }

    @Test("Privacy clearing removes a pending notification destination")
    func clearRemovesPendingDestination() throws {
        let suiteName = "NotificationNavigationHandoffTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let handoff = NotificationNavigationHandoff(defaults: defaults)

        handoff.store(reminderID: UUID())
        handoff.clearPendingDestination()

        #expect(handoff.consumePendingReminderID() == nil)
    }
}
