//
//  AppLifecyclePromptCoordinator.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppLifecyclePromptCoordinator: ObservableObject {
    @Published var showsNotificationPrompt = false
    @Published var showsEnjoymentPrompt = false
    @Published var showsReviewPrompt = false
    @Published var showsFeedbackForm = false
    @Published var feedbackText = ""

    private let defaults: UserDefaults
    private let notificationPermissions: NotificationPermissionProviding
    private let settingsOpener: SettingsOpening

    private var didCountCurrentForegroundSession = false
    private var didPresentPromptThisSession = false

    private enum DefaultsKey {
        static let appOpenCount = "appLifecyclePrompt.appOpenCount"
        static let lastNotificationPromptOpenCount = "appLifecyclePrompt.lastNotificationPromptOpenCount"
        static let didCompleteReviewFlow = "appLifecyclePrompt.didCompleteReviewFlow"
    }

    init(
        defaults: UserDefaults = .standard,
        notificationPermissions: NotificationPermissionProviding = UserNotificationPermissionProvider(),
        settingsOpener: SettingsOpening = ApplicationSettingsOpener()
    ) {
        self.defaults = defaults
        self.notificationPermissions = notificationPermissions
        self.settingsOpener = settingsOpener
    }

    func recordForegroundOpenIfNeeded(hasPositiveEngagementSignal: Bool) async {
        guard didCountCurrentForegroundSession == false else { return }

        didCountCurrentForegroundSession = true
        let openCount = defaults.integer(forKey: DefaultsKey.appOpenCount) + 1
        defaults.set(openCount, forKey: DefaultsKey.appOpenCount)

        if await shouldPromptForNotifications(openCount: openCount) {
            showsNotificationPrompt = true
            didPresentPromptThisSession = true
            defaults.set(openCount, forKey: DefaultsKey.lastNotificationPromptOpenCount)
            return
        }

        if shouldPromptForReviewFlow(openCount: openCount) {
            if hasPositiveEngagementSignal {
                showsReviewPrompt = true
            } else {
                showsEnjoymentPrompt = true
            }
            didPresentPromptThisSession = true
        }
    }

    func endForegroundSession() {
        didCountCurrentForegroundSession = false
        didPresentPromptThisSession = false
    }

    func handleNotificationPromptChoice(shouldEnable: Bool) {
        showsNotificationPrompt = false
        guard shouldEnable else { return }

        Task {
            let status = await notificationPermissions.authorizationStatus()
            switch status {
            case .notDetermined:
                _ = try? await notificationPermissions.requestAuthorization(options: [.alert, .badge, .sound])
            case .denied:
                await openSystemSettings()
            default:
                break
            }
        }
    }

    func handleEnjoymentResponse(isEnjoying: Bool) {
        showsEnjoymentPrompt = false
        defaults.set(true, forKey: DefaultsKey.didCompleteReviewFlow)

        if isEnjoying {
            showsReviewPrompt = true
        } else {
            showsFeedbackForm = true
        }
    }

    func handleReviewRequest() {
        showsReviewPrompt = false
        defaults.set(true, forKey: DefaultsKey.didCompleteReviewFlow)
        requestSystemReview()
    }

    func deferReviewRequest() {
        showsReviewPrompt = false
        defaults.set(true, forKey: DefaultsKey.didCompleteReviewFlow)
    }

    func submitFeedback() {
        let message = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        showsFeedbackForm = false
        feedbackText = ""

        let body = message.isEmpty ? String(localized: "I have feedback about SunHat.", comment: "Default body of the feedback email when the user submits without typing anything") : message
        let subject = String(localized: "SunHat Feedback", comment: "Pre-filled subject line of the feedback email the app composes; 'SunHat' is the app name")

        guard let url = AppSupportLinks.mailURL(
            to: AppSupportLinks.feedbackEmail,
            subject: subject,
            body: body
        ) else {
            return
        }

        Task {
            _ = await settingsOpener.open(url)
        }
    }

    func dismissFeedback() {
        showsFeedbackForm = false
        feedbackText = ""
        defaults.set(true, forKey: DefaultsKey.didCompleteReviewFlow)
    }

    private func shouldPromptForNotifications(openCount: Int) async -> Bool {
        guard didPresentPromptThisSession == false else { return false }
        guard openCount > 0, openCount.isMultiple(of: 5) else { return false }
        guard defaults.integer(forKey: DefaultsKey.lastNotificationPromptOpenCount) != openCount else { return false }

        let status = await notificationPermissions.authorizationStatus()
        return status.isNotificationDeliveryDisabled
    }

    private func shouldPromptForReviewFlow(openCount: Int) -> Bool {
        guard didPresentPromptThisSession == false else { return false }
        guard defaults.bool(forKey: DefaultsKey.didCompleteReviewFlow) == false else { return false }
        return openCount == 7
    }

    private func openSystemSettings() async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        _ = await settingsOpener.open(url)
    }

    private func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview()
        }
    }
}

private extension UNAuthorizationStatus {
    var isNotificationDeliveryDisabled: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return false
        case .notDetermined, .denied:
            return true
        @unknown default:
            return true
        }
    }
}
