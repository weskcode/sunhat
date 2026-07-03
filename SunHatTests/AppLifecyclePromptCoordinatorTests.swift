//
//  AppLifecyclePromptCoordinatorTests.swift
//  SunHatTests
//
//  Created by Codex on 7/3/26.
//

import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import SunHat

@MainActor
struct AppLifecyclePromptCoordinatorTests {
    @Test("Disabled notifications prompt on every fifth foreground open")
    func notificationPromptAppearsOnFifthOpen() async {
        let defaults = makeDefaults()
        defaults.set(4, forKey: "appLifecyclePrompt.appOpenCount")
        let permissions = StubPromptNotificationPermissionProvider(status: .denied)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: false)

        #expect(coordinator.showsNotificationPrompt)
    }

    @Test("Notification prompt is suppressed when system notifications are enabled")
    func notificationPromptRequiresDisabledSystemStatus() async {
        let defaults = makeDefaults()
        defaults.set(4, forKey: "appLifecyclePrompt.appOpenCount")
        let permissions = StubPromptNotificationPermissionProvider(status: .authorized)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: false)

        #expect(coordinator.showsNotificationPrompt == false)
    }

    @Test("A foreground session is counted once")
    func foregroundSessionCountsOnce() async {
        let defaults = makeDefaults()
        let permissions = StubPromptNotificationPermissionProvider(status: .denied)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: false)
        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: false)

        #expect(defaults.integer(forKey: "appLifecyclePrompt.appOpenCount") == 1)
    }

    @Test("Seventh open asks for enjoyment when no positive engagement signal exists")
    func seventhOpenAsksEnjoymentQuestion() async {
        let defaults = makeDefaults()
        defaults.set(6, forKey: "appLifecyclePrompt.appOpenCount")
        let permissions = StubPromptNotificationPermissionProvider(status: .authorized)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: false)

        #expect(coordinator.showsEnjoymentPrompt)
        #expect(coordinator.showsReviewPrompt == false)
    }

    @Test("Positive engagement on seventh open routes directly to review prompt")
    func positiveEngagementRoutesToReviewPrompt() async {
        let defaults = makeDefaults()
        defaults.set(6, forKey: "appLifecyclePrompt.appOpenCount")
        let permissions = StubPromptNotificationPermissionProvider(status: .authorized)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: true)

        #expect(coordinator.showsReviewPrompt)
        #expect(coordinator.showsEnjoymentPrompt == false)
    }

    @Test("Negative enjoyment response opens feedback form")
    func negativeEnjoymentRoutesToFeedback() {
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: RecordingPromptSettingsOpener()
        )
        coordinator.showsEnjoymentPrompt = true

        coordinator.handleEnjoymentResponse(isEnjoying: false)

        #expect(coordinator.showsEnjoymentPrompt == false)
        #expect(coordinator.showsFeedbackForm)
        #expect(coordinator.showsReviewPrompt == false)
    }

    @Test("Submitting feedback opens a mail URL")
    func submittingFeedbackOpensMailURL() async throws {
        let opener = RecordingPromptSettingsOpener()
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: opener
        )
        coordinator.feedbackText = "I need better forecast controls."

        coordinator.submitFeedback()

        try await waitUntil { opener.openedURLs.count == 1 }
        #expect(opener.openedURLs.first?.scheme == "mailto")
        #expect(opener.openedURLs.first?.absoluteString.contains(AppSupportLinks.feedbackEmail) == true)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppLifecyclePromptCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Condition was not met before timeout")
    }
}

@MainActor
private final class StubPromptNotificationPermissionProvider: NotificationPermissionProviding {
    var status: UNAuthorizationStatus
    private(set) var requestedOptions: [UNAuthorizationOptions] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions.append(options)
        status = .authorized
        return true
    }
}

@MainActor
private final class RecordingPromptSettingsOpener: SettingsOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return true
    }
}
