//
//  SettingsViewModelDependencyTests.swift
//  SunHatTests
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct SettingsViewModelDependencyTests {
    @Test("Contact support opens a support mail URL through SettingsOpening")
    func contactSupportUsesInjectedOpener() async throws {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.contactSupport()

        try await waitUntil { opener.openedURLs.count == 1 }
        let url = opener.openedURLs.first
        #expect(url?.scheme == "mailto")
        #expect(url?.absoluteString.contains(AppSupportLinks.supportEmail) == true)
        #expect(url?.absoluteString.contains("SunHat%20Support%20Request") == true)
    }

    @Test("Feedback opens a feedback mail URL through SettingsOpening")
    func sendFeedbackUsesInjectedOpener() async throws {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.sendFeedback()

        try await waitUntil { opener.openedURLs.count == 1 }
        let url = opener.openedURLs.first
        #expect(url?.scheme == "mailto")
        #expect(url?.absoluteString.contains(AppSupportLinks.feedbackEmail) == true)
        #expect(url?.absoluteString.contains("SunHat%20Feedback") == true)
    }

    @Test("Terms opens the centralized terms URL through SettingsOpening")
    func termsUsesInjectedOpener() async throws {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.openTermsOfService()

        try await waitUntil { opener.openedURLs.isEmpty == false }
        #expect(opener.openedURLs == [AppSupportLinks.termsOfServiceURL])
    }

    @Test("A failed open surfaces a user-visible error instead of failing silently")
    func failedOpenSurfacesError() async throws {
        let opener = RecordingSettingsOpener()
        opener.shouldSucceed = false
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.contactSupport()

        try await waitUntil { viewModel.actionError != nil }
        #expect(viewModel.isShowingActionError == true)
        #expect(viewModel.actionError?.isEmpty == false)
    }

    @Test("A successful open does not surface an error")
    func successfulOpenHasNoError() async throws {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.contactSupport()

        try await waitUntil { opener.openedURLs.count == 1 }
        // Give any error-setting continuation a chance to run.
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.actionError == nil)
        #expect(viewModel.isShowingActionError == false)
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
private final class RecordingSettingsOpener: SettingsOpening {
    private(set) var openedURLs: [URL] = []
    var shouldSucceed = true

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return shouldSucceed
    }
}
