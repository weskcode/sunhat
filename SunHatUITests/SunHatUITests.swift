//
//  SunHatUITests.swift
//  SunHatUITests
//
//  Created by Wesley Keetch on 7/20/25.
//

import XCTest

final class SunHatUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunches() throws {
        let app = launchApp()
        XCTAssertEqual(app.state, .runningForeground, "App should be running in foreground")
    }

    @MainActor
    func testTabBarExists() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }

    @MainActor
    func testHomeTabExistsAndSelected() throws {
        let app = launchApp()
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Home tab should exist")
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected on launch")
    }

    @MainActor
    func testRemindersTabExists() throws {
        let app = launchApp()
        let remindersTab = app.tabBars.buttons["Reminders"]
        XCTAssertTrue(remindersTab.waitForExistence(timeout: 5), "Reminders tab should exist")
    }

    @MainActor
    func testWeatherTabExists() throws {
        let app = launchApp()
        let weatherTab = app.tabBars.buttons["Weather"]
        XCTAssertTrue(weatherTab.waitForExistence(timeout: 5), "Weather tab should exist")
    }

    @MainActor
    func testSettingsTabExists() throws {
        let app = launchApp()
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist")
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateToRemindersTab() throws {
        let app = launchApp()
        let remindersTab = app.tabBars.buttons["Reminders"]
        XCTAssertTrue(remindersTab.waitForExistence(timeout: 5))
        remindersTab.tap()
        XCTAssertTrue(remindersTab.isSelected, "Reminders tab should be selected after tap")
    }

    @MainActor
    func testNavigateToWeatherTab() throws {
        let app = launchApp()
        let weatherTab = app.tabBars.buttons["Weather"]
        XCTAssertTrue(weatherTab.waitForExistence(timeout: 5))
        weatherTab.tap()
        XCTAssertTrue(weatherTab.isSelected, "Weather tab should be selected after tap")
    }

    @MainActor
    func testNavigateToSettingsTab() throws {
        let app = launchApp()
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected, "Settings tab should be selected after tap")
    }

    @MainActor
    func testNavigateBackToHome() throws {
        let app = launchApp()
        // Go to settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Navigate back to home
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected after navigating back")
    }

    // MARK: - Reminder Creation UI Tests

    @MainActor
    func testOpenReminderCreationSheet() throws {
        let app = launchApp()
        // Look for the create/FAB button on the dashboard
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Create'")).firstMatch
        let fabButton = app.buttons.matching(identifier: "QuickCreateFAB").firstMatch

        let button = createButton.exists ? createButton : fabButton

        if button.exists {
            button.tap()

            // Verify the creation sheet appears with a close button
            let closeButton = app.buttons["Close"]
            XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button should appear in creation sheet")

            // Dismiss
            closeButton.tap()
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
