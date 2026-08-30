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

        #expect(coordinator.activePrompt == .notification)
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

        #expect(coordinator.activePrompt == nil)
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

        #expect(coordinator.activePrompt == .enjoyment)
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

        #expect(coordinator.activePrompt == .review)
    }

    @Test("Negative enjoyment response opens feedback form")
    func negativeEnjoymentRoutesToFeedback() {
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: RecordingPromptSettingsOpener()
        )
        coordinator.activePrompt = .enjoyment

        coordinator.handleEnjoymentResponse(isEnjoying: false)

        #expect(coordinator.activePrompt == nil)
        #expect(coordinator.showsFeedbackForm)
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

    @Test("Notification prompt is not repeated for an open count already prompted")
    func notificationPromptDoesNotRepeatForSameOpenCount() async {
        let defaults = makeDefaults()
        defaults.set(4, forKey: "appLifecyclePrompt.appOpenCount")
        defaults.set(5, forKey: "appLifecyclePrompt.lastNotificationPromptOpenCount")
        let permissions = StubPromptNotificationPermissionProvider(status: .denied)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: false)

        #expect(coordinator.activePrompt == nil)
    }

    @Test("Review flow is suppressed once it has already completed")
    func reviewFlowSuppressedAfterCompletion() async {
        let defaults = makeDefaults()
        defaults.set(6, forKey: "appLifecyclePrompt.appOpenCount")
        defaults.set(true, forKey: "appLifecyclePrompt.didCompleteReviewFlow")
        let permissions = StubPromptNotificationPermissionProvider(status: .authorized)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        await coordinator.recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: true)

        #expect(coordinator.activePrompt == nil)
    }

    @Test("Requesting a review marks the review flow complete")
    func handleReviewRequestMarksFlowComplete() {
        let defaults = makeDefaults()
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: RecordingPromptSettingsOpener()
        )
        coordinator.activePrompt = .review

        coordinator.handleReviewRequest()

        #expect(coordinator.activePrompt == nil)
        #expect(defaults.bool(forKey: "appLifecyclePrompt.didCompleteReviewFlow") == true)
    }

    @Test("Deferring a review marks the review flow complete without requesting a review")
    func deferReviewRequestMarksFlowComplete() {
        let defaults = makeDefaults()
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: RecordingPromptSettingsOpener()
        )
        coordinator.activePrompt = .review

        coordinator.deferReviewRequest()

        #expect(coordinator.activePrompt == nil)
        #expect(defaults.bool(forKey: "appLifecyclePrompt.didCompleteReviewFlow") == true)
    }

    @Test("Dismissing the feedback form marks the review flow complete and clears the draft")
    func dismissFeedbackClearsDraftAndCompletesFlow() {
        let defaults = makeDefaults()
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: defaults,
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: RecordingPromptSettingsOpener()
        )
        coordinator.showsFeedbackForm = true
        coordinator.feedbackText = "Draft feedback"

        coordinator.dismissFeedback()

        #expect(coordinator.showsFeedbackForm == false)
        #expect(coordinator.feedbackText.isEmpty)
        #expect(defaults.bool(forKey: "appLifecyclePrompt.didCompleteReviewFlow") == true)
    }

    @Test("Submitting empty feedback falls back to a default message")
    func submittingEmptyFeedbackUsesDefaultMessage() async throws {
        let opener = RecordingPromptSettingsOpener()
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: StubPromptNotificationPermissionProvider(status: .authorized),
            settingsOpener: opener
        )
        coordinator.feedbackText = "   "

        coordinator.submitFeedback()

        try await waitUntil { opener.openedURLs.count == 1 }
        #expect(opener.openedURLs.first?.absoluteString.contains("I%20have%20feedback%20about%20SunHat") == true)
    }

    @Test("Enabling notifications with an undetermined system status requests authorization")
    func enablingNotificationsRequestsAuthorizationWhenNotDetermined() async throws {
        let permissions = StubPromptNotificationPermissionProvider(status: .notDetermined)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: permissions,
            settingsOpener: RecordingPromptSettingsOpener()
        )

        coordinator.handleNotificationPromptChoice(shouldEnable: true)

        try await waitUntil { permissions.requestedOptions.isEmpty == false }
        #expect(coordinator.activePrompt == nil)
    }

    @Test("Enabling notifications when the system has denied them opens Settings instead of re-prompting")
    func enablingNotificationsOpensSettingsWhenDenied() async throws {
        let opener = RecordingPromptSettingsOpener()
        let permissions = StubPromptNotificationPermissionProvider(status: .denied)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: permissions,
            settingsOpener: opener
        )

        coordinator.handleNotificationPromptChoice(shouldEnable: true)

        try await waitUntil { opener.openedURLs.isEmpty == false }
        #expect(permissions.requestedOptions.isEmpty)
    }

    @Test("Declining the notification prompt neither requests authorization nor opens Settings")
    func decliningNotificationPromptTakesNoAction() async throws {
        let opener = RecordingPromptSettingsOpener()
        let permissions = StubPromptNotificationPermissionProvider(status: .denied)
        let coordinator = AppLifecyclePromptCoordinator(
            defaults: makeDefaults(),
            notificationPermissions: permissions,
            settingsOpener: opener
        )

        coordinator.handleNotificationPromptChoice(shouldEnable: false)

        // Give any stray async work a chance to run before asserting nothing happened.
        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.activePrompt == nil)
        #expect(permissions.requestedOptions.isEmpty)
        #expect(opener.openedURLs.isEmpty)
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
