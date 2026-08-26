import Foundation

@MainActor
final class NotificationNavigationHandoff {
    static let shared = NotificationNavigationHandoff()
    static let didStoreDestination = Notification.Name(
        "NotificationNavigationHandoff.didStoreDestination"
    )

    private let defaults: UserDefaults
    private let pendingReminderKey = "NotificationNavigationHandoff.pendingReminderID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func store(reminderID: UUID) {
        defaults.set(reminderID.uuidString, forKey: pendingReminderKey)
        NotificationCenter.default.post(name: Self.didStoreDestination, object: nil)
    }

    func consumePendingReminderID() -> UUID? {
        guard
            let rawValue = defaults.string(forKey: pendingReminderKey),
            let reminderID = UUID(uuidString: rawValue)
        else {
            defaults.removeObject(forKey: pendingReminderKey)
            return nil
        }

        defaults.removeObject(forKey: pendingReminderKey)
        return reminderID
    }

    func clearPendingDestination() {
        defaults.removeObject(forKey: pendingReminderKey)
    }
}
