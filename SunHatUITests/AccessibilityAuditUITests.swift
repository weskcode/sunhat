//
//  AccessibilityAuditUITests.swift
//  SunHatUITests
//
//  Runs XCTest's built-in accessibility auditor over every primary screen.
//  The auditor catches the classes of defect that are invisible in a normal
//  UI test but block real users: unlabeled controls, images whose label
//  repeats the trait, text that clips at large Dynamic Type sizes, contrast
//  below the WCAG threshold, and hit regions under 44pt.
//
//  Each screen is audited independently so a failure names the screen it came
//  from. The ad SDK is disabled: Google's banner is a third-party view whose
//  accessibility this project cannot fix, and its network fetch makes the
//  audit nondeterministic.
//

import XCTest

final class AccessibilityAuditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCreatedFirstReminder", "YES",
            "-sunhatDisableAdSDK",
        ]
        app.launch()
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 20),
            "App should reach the main tab bar"
        )
        return app
    }

    /// Audits the current screen and reports every issue as a test failure
    /// tagged with the screen name, so one run enumerates all of them rather
    /// than stopping at the first.
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) throws {
        try app.performAccessibilityAudit { issue in
            XCTFail("[\(screen)] \(issue.auditType): \(issue.compactDescription)")
            // Already reported above; returning true stops XCTest from
            // double-reporting the same issue.
            return true
        }
    }

    @MainActor
    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(name) tab should exist")
        tab.tap()
    }

    // MARK: - Per-screen audits

    @MainActor
    func testDashboardIsAccessible() throws {
        let app = launchApp()
        try audit(app, screen: "Dashboard")
    }

    @MainActor
    func testRemindersIsAccessible() throws {
        let app = launchApp()
        openTab(app, "Reminders")
        try audit(app, screen: "Reminders")
    }

    @MainActor
    func testWeatherIsAccessible() throws {
        let app = launchApp()
        openTab(app, "Weather")
        try audit(app, screen: "Weather")
    }

    @MainActor
    func testSettingsIsAccessible() throws {
        let app = launchApp()
        openTab(app, "Settings")
        try audit(app, screen: "Settings")
    }

    // MARK: - Largest accessibility text size

    /// The audit's dynamicTypeSupport check only exercises the size the app is
    /// currently running at, so this repeats the sweep pinned to the largest
    /// accessibility size — where clipping and truncation actually appear.
    @MainActor
    func testPrimaryScreensAtLargestAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCreatedFirstReminder", "YES",
            "-sunhatDisableAdSDK",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 20),
            "App should reach the main tab bar at AX XXXL"
        )

        try audit(app, screen: "Dashboard @ AX-XXXL")
        for tab in ["Reminders", "Weather", "Settings"] {
            openTab(app, tab)
            try audit(app, screen: "\(tab) @ AX-XXXL")
        }
    }
}
