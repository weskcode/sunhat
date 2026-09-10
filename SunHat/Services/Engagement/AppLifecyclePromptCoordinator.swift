//
//  AppLifecyclePromptCoordinator.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
@preconcurrency import UserNotifications

/// What the notification lifecycle alert should offer. An undetermined system
/// status must get neutral wording ("Continue"), since the button leads into
/// the system permission dialog and a command-style label would pre-answer it
/// (App Store Guideline 5.1.1(iv)). A denied status hands off to Settings.
enum NotificationPromptStage: Hashable {
    case requestPermission
    case openSettings
}

enum LifecyclePrompt: Identifiable, Equatable, Hashable {
    case notification(NotificationPromptStage)
    case enjoyment
    case review

    var id: Self { self }

    var title: String {
        switch self {
        case .notification:
            return String(localized: "Turn On Weather Reminders?", comment: "Lifecycle prompt alert title")
        case .enjoyment:
            return String(localized: "Enjoying SunHat?", comment: "Lifecycle prompt alert title")
        case .review:
            return String(localized: "Review SunHat?", comment: "Lifecycle prompt alert title")
        }
    }
}

@MainActor
final class AppLifecyclePromptCoordinator: ObservableObject {
    /// The at-most-one currently visible lifecycle alert. A single optional
    /// instead of separate booleans makes "only one prompt at a time" a
    /// structural guarantee rather than something every method has to
    /// remember to hand-enforce.
    @Published var activePrompt: LifecyclePrompt?
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

        if let stage = await notificationPromptStage(openCount: openCount) {
            activePrompt = .notification(stage)
            didPresentPromptThisSession = true
            defaults.set(openCount, forKey: DefaultsKey.lastNotificationPromptOpenCount)
            return
        }

        if shouldPromptForReviewFlow(openCount: openCount) {
            activePrompt = hasPositiveEngagementSignal ? .review : .enjoyment
            didPresentPromptThisSession = true
        }
    }

    func endForegroundSession() {
        didCountCurrentForegroundSession = false
        didPresentPromptThisSession = false
    }

    func handleNotificationPromptChoice(shouldEnable: Bool) {
        activePrompt = nil
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
        defaults.set(true, forKey: DefaultsKey.didCompleteReviewFlow)

        if isEnjoying {
            activePrompt = .review
        } else {
            activePrompt = nil
            showsFeedbackForm = true
        }
    }

    func handleReviewRequest() {
        activePrompt = nil
        defaults.set(true, forKey: DefaultsKey.didCompleteReviewFlow)
        requestSystemReview()
    }

    func deferReviewRequest() {
        activePrompt = nil
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

    private func notificationPromptStage(openCount: Int) async -> NotificationPromptStage? {
        guard didPresentPromptThisSession == false else { return nil }
        guard openCount > 0, openCount.isMultiple(of: 5) else { return nil }
        guard defaults.integer(forKey: DefaultsKey.lastNotificationPromptOpenCount) != openCount else { return nil }

        let status = await notificationPermissions.authorizationStatus()
        switch status {
        case .notDetermined:
            return .requestPermission
        case .denied:
            return .openSettings
        default:
            return nil
        }
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
