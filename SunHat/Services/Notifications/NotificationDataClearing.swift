import UserNotifications

protocol NotificationDataClearing {
    func clearAllNotificationData() async throws
}

protocol PrivacyRuntimeDataClearing {
    func clearPrivacyRuntimeData() async
}

struct SystemNotificationDataCleaner: NotificationDataClearing {
    func clearAllNotificationData() async throws {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        try await center.setBadgeCount(0)
    }
}

struct SystemPrivacyRuntimeDataCleaner: PrivacyRuntimeDataClearing {
    func clearPrivacyRuntimeData() async {
        await WeatherService.shared.clearCache()
        NotificationNavigationHandoff.shared.clearPendingDestination()
        TriggerEngineManager.shared.clearTriggeredReminders()
    }
}
