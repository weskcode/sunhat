//
//  VisualQAScreenshotTests.swift
//  SunHatUITests
//
//  Captures the four primary screens across the appearance, Dynamic Type and
//  localization combinations that break Liquid Glass layouts in practice:
//  dark mode (glass contrast), the largest accessibility text size (clipping
//  and truncation), and Spanish (string expansion, typically 20-30% longer
//  than English).
//
//  These tests assert only that each screen renders and stays navigable; the
//  screenshots are the deliverable, written to /tmp/sunhat-shots and attached
//  to the xcresult for review.
//

import XCTest

final class VisualQAScreenshotTests: XCTestCase {
    private static let screens = ["Home", "Reminders", "Weather", "Settings"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(
        extraArguments: [String] = [],
        appearance: XCUIDevice.Appearance = .light
    ) -> XCUIApplication {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCreatedFirstReminder", "YES",
            "-sunhatDisableAdSDK",
        ] + extraArguments
        app.launch()
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 20),
            "App should reach the main tab bar"
        )
        return app
    }

    @MainActor
    private func captureAllScreens(_ app: XCUIApplication, variant: String) {
        for screen in Self.screens {
            let tab = app.tabBars.buttons[screen]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(screen) tab should exist in \(variant)")
            tab.tap()
            // Let the tab's content settle before the shot; the glass tab bar
            // animates its selection and the dashboard loads asynchronously.
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)
            save(app.screenshot(), name: "\(variant)-\(screen.lowercased())")
        }
    }

    @MainActor
    func testLightModeDefaultType() throws {
        captureAllScreens(launch(appearance: .light), variant: "light-default")
    }

    @MainActor
    func testDarkModeDefaultType() throws {
        captureAllScreens(launch(appearance: .dark), variant: "dark-default")
    }

    @MainActor
    func testLightModeLargestAccessibilityType() throws {
        let app = launch(
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"],
            appearance: .light
        )
        captureAllScreens(app, variant: "light-ax-xxxl")
    }

    @MainActor
    func testSpanishLocalization() throws {
        let app = launch(
            extraArguments: ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"],
            appearance: .light
        )
        captureAllScreens(app, variant: "spanish-default")
    }

    @MainActor
    private func save(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: "/tmp/sunhat-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
