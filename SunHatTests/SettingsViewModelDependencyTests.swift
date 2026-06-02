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
    func contactSupportUsesInjectedOpener() {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.contactSupport()

        let url = opener.openedURLs.first
        #expect(opener.openedURLs.count == 1)
        #expect(url?.scheme == "mailto")
        #expect(url?.absoluteString.contains(AppSupportLinks.supportEmail) == true)
        #expect(url?.absoluteString.contains("SunHat%20Support%20Request") == true)
    }

    @Test("Feedback opens a feedback mail URL through SettingsOpening")
    func sendFeedbackUsesInjectedOpener() {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.sendFeedback()

        let url = opener.openedURLs.first
        #expect(opener.openedURLs.count == 1)
        #expect(url?.scheme == "mailto")
        #expect(url?.absoluteString.contains(AppSupportLinks.feedbackEmail) == true)
        #expect(url?.absoluteString.contains("SunHat%20Feedback") == true)
    }

    @Test("Terms opens the centralized terms URL through SettingsOpening")
    func termsUsesInjectedOpener() {
        let opener = RecordingSettingsOpener()
        let viewModel = SettingsViewModel(settingsOpener: opener)

        viewModel.openTermsOfService()

        #expect(opener.openedURLs == [AppSupportLinks.termsOfServiceURL])
    }
}

@MainActor
private final class RecordingSettingsOpener: SettingsOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) {
        openedURLs.append(url)
    }
}
