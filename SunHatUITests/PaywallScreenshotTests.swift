//
//  PaywallScreenshotTests.swift
//  SunHatUITests
//
//  Drives the app to the Ad-Free section in Settings and into the paywall
//  sheet, capturing screenshots for design review (and reused by the Phase 7
//  integration pass). Screenshots are written to /tmp/sunhat-shots and also
//  attached to the xcresult.
//

import XCTest

final class PaywallScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAdFreeSettingsAndPaywall() throws {
        let app = XCUIApplication()
        // Argument-domain defaults: skip onboarding deterministically.
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCreatedFirstReminder", "YES"
        ]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should appear")
        settingsTab.tap()

        // AdFreeIntegrationUITests purchases in the persistent local StoreKit
        // store; this test needs a non-subscribed state. Skip with guidance
        // rather than failing confusingly.
        if app.staticTexts["Current Plan"].waitForExistence(timeout: 3) {
            throw XCTSkip("App is already subscribed in the local StoreKit store — run `xcrun simctl uninstall <udid> org.wesley.sunhat` first to reset.")
        }

        // The row only exists once (a) StoreManager resolves .notEntitled —
        // which can take a while when the local StoreKit test store rebuilds —
        // and (b) the lazily-realized Form row is scrolled near the viewport.
        // Poll with swipes until both are true.
        let getAdFree = app.buttons["Get Ad-Free"]
        let deadline = Date().addingTimeInterval(60)
        while !getAdFree.exists && Date() < deadline {
            app.swipeUp()
            if getAdFree.waitForExistence(timeout: 3) { break }
            app.swipeDown()
            _ = getAdFree.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(getAdFree.exists, "Get Ad-Free row should exist for a non-subscriber")
        var hittableSwipes = 0
        while !getAdFree.isHittable && hittableSwipes < 8 {
            app.swipeUp()
            hittableSwipes += 1
        }
        save(app.screenshot(), name: "settings-adfree-section")

        getAdFree.tap()
        let paywallTitle = app.staticTexts["SunHat Ad-Free"]
        XCTAssertTrue(paywallTitle.waitForExistence(timeout: 10), "Paywall marketing header should appear")
        // Wait for the tiers themselves so the screenshot shows the loaded
        // store, not the "Loading Subscription" spinner.
        let annualTier = app.staticTexts["Ad-Free Annual"]
        XCTAssertTrue(annualTier.waitForExistence(timeout: 20), "Subscription tiers should load from the local StoreKit configuration")
        save(app.screenshot(), name: "paywall-sheet")
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
