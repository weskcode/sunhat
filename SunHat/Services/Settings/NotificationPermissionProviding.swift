//
//  NotificationPermissionProviding.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import Foundation
@preconcurrency import UserNotifications

/// Dependency seam for notification permission checks and requests, so
/// ViewModels can be tested without touching `UNUserNotificationCenter`.
@MainActor
protocol NotificationPermissionProviding: AnyObject {
    /// The current notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus

    /// Requests notification authorization and reports whether the user
    /// granted it. Throws when the system request itself fails.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

@MainActor
final class UserNotificationPermissionProvider: NotificationPermissionProviding {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
}
