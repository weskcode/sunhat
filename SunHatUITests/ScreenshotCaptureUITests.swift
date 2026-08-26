//
//  ScreenshotCaptureUITests.swift
//  SunHatUITests
//
//  Drives the real app UI to capture raw App Store screenshot material into
//  AppStore/Screenshots_v2/Raw. Not a correctness test — run explicitly via
//  -only-testing when regenerating marketing screenshots. Each shot is an
//  independent test method (own launch) so one flaky interaction can't take
//  down the rest of the set.
//

import XCTest

// The whole class is main-actor isolated: XCUIApplication/XCUIScreen and the
// helper methods below all touch UI state, and nonisolated sync helpers were
// producing Swift 6 actor-isolation warnings.
@MainActor
final class ScreenshotCaptureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private let outputDir = "/Users/wesleykeetch/Documents/Developer/SunHat/AppStore/Screenshots_v2/Raw"

    private func save(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        guard let data = screenshot.image.pngData() else { return }
        let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
        try? data.write(to: url)
    }

    /// Best-effort tap: tries the exact label first, then a BEGINSWITH match, across
    /// buttons/staticTexts/otherElements. Does nothing (no throw) if not found, since
    /// a marketing screenshot with one control left at its default state is still usable.
    private func tapIfPresent(_ app: XCUIApplication, label: String, timeout: TimeInterval = 3) {
        for query in [app.buttons, app.staticTexts, app.otherElements] {
            let exact = query[label]
            if exact.waitForExistence(timeout: timeout) {
                exact.tap()
                return
            }
        }
        let predicate = NSPredicate(format: "label BEGINSWITH %@", label)
        let fuzzy = app.buttons.matching(predicate).firstMatch
        if fuzzy.waitForExistence(timeout: timeout) {
            fuzzy.tap()
        }
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-SunHatScreenshotSeed"]
        app.launch()
        _ = app.tabBars.buttons["Home"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 4.0)
        dismissEngagementPromptIfPresent(app)
        return app
    }

    /// Dismisses the "Turn On Weather Reminders?" lifecycle nudge (AppLifecyclePromptCoordinator)
    /// that can appear on the first foreground session, so it doesn't cover marketing shots.
    private func dismissEngagementPromptIfPresent(_ app: XCUIApplication) {
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 2) {
            notNow.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func openCreateSheet(_ app: XCUIApplication) {
        let newTaskTab = app.tabBars.buttons["New Task"]
        if newTaskTab.waitForExistence(timeout: 3) {
            newTaskTab.tap()
        } else {
            app.buttons["New Task"].tap()
        }
        Thread.sleep(forTimeInterval: 1.0)
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.waitForExistence(timeout: 1) {
            returnKey.tap()
        } else if app.keyboards.buttons["return"].waitForExistence(timeout: 1) {
            app.keyboards.buttons["return"].tap()
        }
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func openReminder(_ app: XCUIApplication, titled title: String) {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", title)
        let card = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Could not find reminder card starting with \(title)")
        card.tap()
        // Trigger History loads asynchronously and slides in with a bottom-edge transition;
        // scrolling before it settles leaves the scroll view's content height stale, which can
        // land a later scroll position behind the custom nav bar. Give it time to finish first.
        Thread.sleep(forTimeInterval: 2.2)
    }

    // MARK: - Shots

    @MainActor
    func testShot01_HeroWelcome() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        save(name: "01_hero_welcome.png")
    }

    @MainActor
    func testShot02_DashboardReadyNow() throws {
        launchSeeded()
        Thread.sleep(forTimeInterval: 1.5)
        save(name: "02_dashboard_ready_now.png")
    }

    @MainActor
    func testShot03_WeatherPredictions() throws {
        let app = launchSeeded()
        app.tabBars.buttons["Weather"].tap()
        // Trigger predictions and historical comparison load via an async model-actor fetch;
        // on a cold app launch this can take longer than the UI settle time below, which was
        // caught rendering its pre-load empty/zeroed state ("No active reminders", 0.0° deltas).
        Thread.sleep(forTimeInterval: 7.0)
        app.swipeUp()
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.5)
        save(name: "03_weather_predictions.png")
    }

    @MainActor
    func testShot04_CreationRange() throws {
        let app = launchSeeded()
        openCreateSheet(app)
        let titleField = app.textFields["Reminder title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Morning Run")
        dismissKeyboard(app)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        tapIfPresent(app, label: "Range")
        Thread.sleep(forTimeInterval: 1.0)
        save(name: "04_creation_range.png")
    }

    @MainActor
    func testShot05_CreationExactSky() throws {
        let app = launchSeeded()
        openCreateSheet(app)
        let titleField = app.textFields["Reminder title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Beach Day")
        dismissKeyboard(app)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        tapIfPresent(app, label: "Exact")
        Thread.sleep(forTimeInterval: 1.2)
        // Partly Cloudy is preselected by default, which alone demonstrates the
        // sky-condition filter; further chip taps proved flaky in the simulator's
        // synthesized-event pipeline and aren't worth fighting for one marketing shot.
        Thread.sleep(forTimeInterval: 1.0)
        save(name: "05_creation_exact_sky.png")
    }

    @MainActor
    func testShot06_CreationTimeQuietHours() throws {
        let app = launchSeeded()
        openCreateSheet(app)
        let titleField = app.textFields["Reminder title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Trail Photo Walk")
        dismissKeyboard(app)
        app.swipeUp()
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        tapIfPresent(app, label: "Morning")
        Thread.sleep(forTimeInterval: 1.0)
        save(name: "06_creation_time_quiet_hours.png")
    }

    @MainActor
    func testShot07_EditSevenTriggerTypes() throws {
        let app = launchSeeded()
        app.tabBars.buttons["Reminders"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        openReminder(app, titled: "Golden Hour Photo Walk")
        Thread.sleep(forTimeInterval: 1.5)

        let editButton = app.buttons["Edit reminder"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        Thread.sleep(forTimeInterval: 1.2)
        tapIfPresent(app, label: "Complex")
        Thread.sleep(forTimeInterval: 1.0)
        save(name: "07_edit_seven_trigger_types.png")
    }

    @MainActor
    func testShot08_RemindersList() throws {
        let app = launchSeeded()
        app.tabBars.buttons["Reminders"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        save(name: "08_reminders_list.png")
    }

    @MainActor
    func testShot09_HistoryTimeline() throws {
        let app = launchSeeded()
        app.tabBars.buttons["Reminders"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        openReminder(app, titled: "Garden Watering")
        // Scrolling to the bottom of this reminder's content lands the Notification Settings
        // section at the top of the viewport, which the app's floating nav bar and the status
        // bar both overlap (a real DetailedReminderView layout issue, not a capture artifact —
        // reproduces regardless of scroll timing). The crop below cuts past it.
        app.swipeUp()
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.0)
        save(name: "09_history_timeline.png")
    }

    @MainActor
    func testShot10_Settings() throws {
        let app = launchSeeded()
        app.tabBars.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.0)
        save(name: "10_settings.png")
    }
}
