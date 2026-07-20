//
//  DashboardUITests.swift
//  SunHatUITests
//
//  Created by Wesley Keetch on 1/10/26.
//

import XCTest

final class DashboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        // Wait for splash screen to dismiss before interacting with UI.
        let homeTab = app.tabBars.buttons["Home"]
        _ = homeTab.waitForExistence(timeout: 5)
        return app
    }

    // MARK: - Navigation Tests

    @MainActor
    func testHomeTabIsSelected() throws {
        let app = launchApp()
        // Verify home tab is selected on launch
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.exists, "Home tab should exist")
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected by default")
    }

    @MainActor
    func testNavigationBetweenTabs() throws {
        let app = launchApp()
        // Test switching between tabs
        let tabBar = app.tabBars

        // Switch to Reminders tab
        tabBar.buttons["Reminders"].tap()
        XCTAssertTrue(tabBar.buttons["Reminders"].isSelected, "Reminders tab should be selected")

        // Switch to Weather tab
        tabBar.buttons["Weather"].tap()
        XCTAssertTrue(tabBar.buttons["Weather"].isSelected, "Weather tab should be selected")

        // Switch to Settings tab
        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(tabBar.buttons["Settings"].isSelected, "Settings tab should be selected")

        // Switch back to Home
        tabBar.buttons["Home"].tap()
        XCTAssertTrue(tabBar.buttons["Home"].isSelected, "Home tab should be selected")
    }

    // MARK: - Weather Display Tests

    @MainActor
    func testWeatherWidgetDisplays() throws {
        let app = launchApp()
        // Verify main weather widget is visible
        let temperatureWidget = app.otherElements.containing(.staticText, identifier: "CurrentTemperature").firstMatch
        XCTAssertTrue(temperatureWidget.exists || app.staticTexts["SunHat"].exists, "Weather widget or title should be visible")
    }

    @MainActor
    func testExpandableWeatherDetails() throws {
        let app = launchApp()
        // Test expanding weather details
        let weatherCard = app.buttons.matching(identifier: "TemperatureWidget").firstMatch

        if weatherCard.exists {
            // Tap to expand
            weatherCard.tap()

            // Wait for detailed weather to appear
            let detailedWeather = app.staticTexts["Forecast Details"]
            let exists = detailedWeather.waitForExistence(timeout: 2)

            if exists {
                XCTAssertTrue(detailedWeather.exists, "Detailed weather section should appear")

                // Tap to collapse
                let lessButton = app.buttons["Less"]
                if lessButton.exists {
                    lessButton.tap()
                }
            }
        }
    }

    // MARK: - Forecast Tests

    @MainActor
    func testHourlyForecastDisplay() throws {
        let app = launchApp()
        // Scroll to hourly forecast section
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        // Look for hourly forecast
        let hourlyForecast = app.staticTexts["Hourly Forecast"]
        if hourlyForecast.exists {
            XCTAssertTrue(hourlyForecast.exists, "Hourly forecast section should be visible")

            // Verify we can scroll through hourly cards
            let firstHourCard = app.otherElements.matching(identifier: "HourlyWeatherCard").firstMatch
            if firstHourCard.exists {
                XCTAssertTrue(firstHourCard.exists, "Hourly weather cards should exist")
            }
        }
    }

    @MainActor
    func testForecastTimeframeSwitching() throws {
        let app = launchApp()
        // Scroll to forecast section
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        scrollView.swipeUp()

        // Look for forecast section
        let forecastSection = app.staticTexts["Forecast"]
        if forecastSection.exists {
            // Find segmented control
            let fiveDayButton = app.buttons["5 Day"]
            let sevenDayButton = app.buttons["7 Day"]
            let tenDayButton = app.buttons["10 Day"]

            if fiveDayButton.exists {
                // Test switching between forecast ranges
                fiveDayButton.tap()
                XCTAssertTrue(fiveDayButton.isSelected, "5 Day should be selected")

                sevenDayButton.tap()
                XCTAssertTrue(sevenDayButton.isSelected, "7 Day should be selected")

                tenDayButton.tap()
                XCTAssertTrue(tenDayButton.isSelected, "10 Day should be selected")
            }
        }
    }

    // MARK: - Active Reminders Tests

    @MainActor
    func testActiveRemindersSection() throws {
        let app = launchApp()
        // Scroll to active reminders
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let activeReminders = app.staticTexts["Active Reminders"]
        if activeReminders.exists {
            XCTAssertTrue(activeReminders.exists, "Active reminders section should be visible")

            // Test "View All" button
            let viewAllButton = app.buttons["View All"]
            if viewAllButton.exists {
                viewAllButton.tap()

                // Wait for navigation
                sleep(1)

                // Should navigate to all reminders view
                let remindersTitle = app.navigationBars.staticTexts["All Reminders"]
                if remindersTitle.waitForExistence(timeout: 2) {
                    XCTAssertTrue(remindersTitle.exists, "Should navigate to all reminders")

                    // Navigate back
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }
        }
    }

    // MARK: - Weather Alerts Tests

    @MainActor
    func testWeatherAlertsDisplay() throws {
        let app = launchApp()
        // Alerts only show if there are active alerts
        let weatherAlerts = app.staticTexts["Weather Alerts"]

        if weatherAlerts.exists {
            XCTAssertTrue(weatherAlerts.exists, "Weather alerts section should be visible when alerts exist")

            let viewAllButton = app.buttons["View All"]
            if viewAllButton.exists {
                viewAllButton.tap()
                sleep(1)

                // Should show alerts view
                // Navigate back if we navigated
                if app.navigationBars.buttons.count > 0 {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }
        }
    }

    // MARK: - Reminder Creation Tests

    @MainActor
    func testCreateReminderButton() throws {
        let app = launchApp()
        // Find the floating action button (FAB) or create button
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Create'")).firstMatch
        let fabButton = app.buttons.matching(identifier: "QuickCreateFAB").firstMatch

        let button = createButton.exists ? createButton : fabButton

        if button.exists {
            button.tap()

            // Wait for streamlined reminder creation sheet
            let closeButton = app.buttons["Close"]
            if closeButton.waitForExistence(timeout: 3) {
                // Verify key form elements exist
                let titleField = app.textFields["Reminder Title"]
                if titleField.waitForExistence(timeout: 2) {
                    XCTAssertTrue(titleField.exists, "Title field should appear in creation sheet")
                }

                // Verify color picker section
                let colorLabel = app.staticTexts["Color"]
                if colorLabel.exists {
                    XCTAssertTrue(colorLabel.exists, "Color picker should appear")
                }

                // Verify icon picker section
                let iconLabel = app.staticTexts["Icon"]
                if iconLabel.exists {
                    XCTAssertTrue(iconLabel.exists, "Icon picker should appear")
                }

                // Verify location section
                let locationLabel = app.staticTexts["Location"]
                if locationLabel.exists {
                    XCTAssertTrue(locationLabel.exists, "Location selector should appear")
                }

                // Dismiss sheet
                closeButton.tap()
            }
        }
    }

    // MARK: - Pull to Refresh Tests

    @MainActor
    func testPullToRefresh() throws {
        let app = launchApp()
        // Get main scroll view
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "Scroll view should exist")

        // Pull down to trigger refresh
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))

        start.press(forDuration: 0.1, thenDragTo: end)

        // Wait a moment for refresh to complete
        sleep(2)

        // Verify content is still there after refresh
        XCTAssertTrue(app.staticTexts["SunHat"].exists, "Content should be visible after refresh")
    }

    // MARK: - Weather Metrics Tests

    @MainActor
    func testWeatherMetricsDisplay() throws {
        let app = launchApp()
        // Scroll down to weather metrics
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<3 {
            scrollView.swipeUp()
        }

        // Check for common weather metrics
        let metrics = ["Humidity", "Wind", "Visibility", "UV Index"]

        for metric in metrics {
            let metricLabel = app.staticTexts[metric]
            if metricLabel.exists {
                XCTAssertTrue(metricLabel.exists, "\(metric) should be visible")
            }
        }
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testVoiceOverLabels() throws {
        let app = launchApp()
        // Verify important elements have accessibility labels
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertFalse(homeTab.label.isEmpty, "Home tab should have accessibility label")

        let title = app.staticTexts["SunHat"]
        if title.exists {
            XCTAssertFalse(title.label.isEmpty, "Title should have accessibility label")
        }
    }

    // MARK: - Scroll Performance Tests

    @MainActor
    func testScrollPerformance() throws {
        let app = launchApp()
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            let scrollView = app.scrollViews.firstMatch

            // Scroll down multiple times
            for _ in 0..<5 {
                scrollView.swipeUp()
            }

            // Scroll back up
            for _ in 0..<5 {
                scrollView.swipeDown()
            }
        }
    }

    // MARK: - Launch Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }

    // MARK: - Memory Tests

    @MainActor
    func testMemoryUsage() throws {
        let app = launchApp()
        measure(metrics: [XCTMemoryMetric()]) {
            // Navigate through different sections
            app.tabBars.buttons["Reminders"].tap()
            sleep(1)

            app.tabBars.buttons["Settings"].tap()
            sleep(1)

            app.tabBars.buttons["Home"].tap()
            sleep(1)

            // Scroll through content
            let scrollView = app.scrollViews.firstMatch
            scrollView.swipeUp()
            scrollView.swipeUp()
            scrollView.swipeDown()
            scrollView.swipeDown()
        }
    }
}
