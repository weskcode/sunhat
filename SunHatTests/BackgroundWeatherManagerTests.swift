//
//  BackgroundWeatherManagerTests.swift
//  SunHatTests
//

import Foundation
import Testing
import UserNotifications
@testable import SunHat

/// Serialized because they exercise the shared singleton's registration and
/// scheduling state.
@MainActor
@Suite(.serialized)
struct BackgroundWeatherManagerTests {
    @Test("Duplicate background task registration is ignored instead of crashing")
    func duplicateRegistrationIsIgnored() {
        let manager = BackgroundWeatherManager.shared

        // The singleton registers in init, so it is already registered by the
        // time any test touches it.
        #expect(manager.isBackgroundTaskRegistered == true)

        // A second registration must be a no-op, without the guard this
        // raises NSInternalInconsistencyException inside BGTaskScheduler.
        #expect(manager.registerBackgroundTask() == false)
        #expect(manager.registerBackgroundTask() == false)
        #expect(manager.isBackgroundTaskRegistered == true)
    }

    @Test("Scheduling falls back gracefully when background refresh is unavailable")
    func unavailableBackgroundRefreshFallsBack() {
        let manager = BackgroundWeatherManager.shared
        let originalAvailability = manager.isBackgroundRefreshEnabled
        defer { manager.isBackgroundRefreshEnabled = originalAvailability }

        manager.isBackgroundRefreshEnabled = false

        // No request is submitted and no error is thrown, the app simply
        // relies on foreground refresh.
        #expect(manager.scheduleBackgroundRefresh() == false)
    }

    @Test("Requesting background refresh permission only reads current authorization, never prompts")
    func requestBackgroundRefreshPermissionMirrorsCurrentAuthorization() async {
        // This checks the real UNUserNotificationCenter rather than a mock: the
        // behavior under test is specifically that the method no longer calls
        // requestAuthorization() (which would surface a system dialog and hang
        // a test run). notificationSettings() is a passive read, so re-deriving
        // the expected outcome here is safe and still catches a regression to
        // the old prompting behavior.
        let manager = BackgroundWeatherManager.shared
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        let expectedGranted: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            expectedGranted = true
        case .notDetermined, .denied:
            expectedGranted = false
        @unknown default:
            expectedGranted = false
        }

        let granted = await manager.requestBackgroundRefreshPermission()

        #expect(granted == expectedGranted)
    }
}
