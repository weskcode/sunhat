//
//  AdFreeIntegrationUITests.swift
//  SunHatUITests
//
//  End-to-end monetization coverage, split in two: the ad-slot test runs with
//  the Google Mobile Ads SDK live, while the purchase test launches with
//  -sunhatDisableAdSDK so the StoreKit-Testing storefront is not competing
//  with ad-SDK traffic on an already-loaded simulator.
//
//  Tests run alphabetically: testBannerSlot… (needs a non-subscriber) runs
//  before testPurchase… (which subscribes). Purchases persist in the local
//  StoreKit store — reset with:
//      xcrun simctl uninstall <udid> org.wesley.sunhat
//

import XCTest

final class AdFreeIntegrationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Ads visible for a non-subscriber (SDK live)

    @MainActor
    func testBannerSlotAppearsForNonSubscriber() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCreatedFirstReminder", "YES"
        ]
        app.launch()

        // First-run gauntlet: location alert, Google's GDPR consent form, the
        // ATT explainer + system alert all chain in front of the ad slot.
        let removeAds = app.buttons["Remove Ads"]
        clearFirstRunPrompts(app: app, until: removeAds, timeout: 240)
        if !removeAds.exists {
            save(app.screenshot(), name: "diagnostic-no-ad-slot")
            XCTFail("Banner slot should appear for a non-subscriber")
        }
        save(app.screenshot(), name: "dashboard-with-ad-slot")
    }

    // MARK: - Purchase unlocks Ad-Free and persists (SDK suppressed)

    @MainActor
    func testPurchaseUnlocksAdFreeAndPersists() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCreatedFirstReminder", "YES",
            "-sunhatDisableAdSDK",
        ]
        app.launch()

        // 1. Paywall via Settings' Get Ad-Free row.
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        let getAdFree = app.buttons["Get Ad-Free"]
        var settingsSwipes = 0
        while !(getAdFree.exists && getAdFree.isHittable) && settingsSwipes < 8 {
            app.swipeUp()
            settingsSwipes += 1
            _ = getAdFree.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(getAdFree.exists, "Get Ad-Free row should exist for a non-subscriber")
        getAdFree.tap()

        // 2. Wait for the store to actually finish loading. The Subscribe
        // button (not the tier text, which can match a not-yet-visible
        // element) is the reliable "store is ready" signal.
        // Match on LABEL, not identifier: SubscriptionStoreView's buy button
        // carries the renewal disclosure in its label ("Subscribe\nPlan
        // auto-renews for $1.00/month until canceled."), so an exact
        // identifier lookup for "Subscribe" never matches it.
        let subscribeButton = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Subscribe"))
            .firstMatch
        if !subscribeButton.waitForExistence(timeout: 90) {
            // The simulator's StoreKit-Testing storefront sometimes isn't
            // attached yet on the first launch of a run ("Subscription
            // Unavailable"); a relaunch reliably picks it up. Retry once for
            // that transient, then fail loudly — never skip, which would mask
            // a genuine store misconfiguration (and previously did).
            save(app.screenshot(), name: "diagnostic-paywall-first-try")
            app.terminate()
            app.launch()
            app.tabBars.buttons["Settings"].tap()
            var retrySwipes = 0
            while !(getAdFree.exists && getAdFree.isHittable) && retrySwipes < 8 {
                app.swipeUp()
                retrySwipes += 1
                _ = getAdFree.waitForExistence(timeout: 2)
            }
            if getAdFree.exists { getAdFree.tap() }
            if !subscribeButton.waitForExistence(timeout: 120) {
                save(app.screenshot(), name: "diagnostic-paywall-state")
                XCTFail("Paywall never finished loading after a retry. If it shows 'Subscription Unavailable', the StoreKit-Testing storefront never attached; verify the scheme's TestAction still carries its StoreKitConfigurationFileReference.")
            }
        }
        save(app.screenshot(), name: "paywall-open")

        // 3. Purchase the pre-selected monthly plan through the system store.
        subscribeButton.tap()
        confirmStoreKitPurchase(app: app)

        // 4. Success dismisses the paywall; the section now shows the plan
        // and the Get Ad-Free row is gone (entitlement flipped mid-session,
        // the same signal that removes every ad slot).
        let currentPlan = app.staticTexts["Current Plan"]
        if !currentPlan.waitForExistence(timeout: 60) {
            // Capture the screen: the usual cause is the StoreKit purchase
            // sheet still being up (its confirm control's label varies by OS),
            // which is invisible in a bare assertion failure.
            save(app.screenshot(), name: "diagnostic-after-purchase")
            XCTFail("Settings should show the active Ad-Free plan after purchase")
        }
        XCTAssertFalse(getAdFree.exists, "Get Ad-Free row must disappear once subscribed")
        save(app.screenshot(), name: "settings-subscribed")

        // 5. Cold relaunch: entitlement comes from the persisted transaction.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        var relaunchSwipes = 0
        while !currentPlan.exists && relaunchSwipes < 8 {
            app.swipeUp()
            relaunchSwipes += 1
            _ = currentPlan.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(currentPlan.exists, "Ad-Free must persist across a cold relaunch")
        // Deliberately NOT asserting the absence of an ad slot here: this
        // launch disables the ad SDK, so such an assertion could never fail
        // and would be a false signal. The real gate (shouldShowAdSlots) is
        // covered by AdManagerGateTests, and the visible-ad case by
        // testBannerSlotAppearsForNonSubscriber.
    }

    // MARK: - Helpers

    /// Answers every first-run prompt — the springboard location alert, the
    /// ATT tracking alert, and Google's UMP consent dialogs — until `target`
    /// exists or the timeout lapses.
    @MainActor
    private func clearFirstRunPrompts(app: XCUIApplication, until target: XCUIElement, timeout: TimeInterval) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // "Continue" = Google's ATT pre-prompt explainer; UMP renders its
        // dialogs in webviews whose controls surface as buttons, links, or
        // bare static text depending on the OS.
        let labels = [
            "Allow While Using App",   // location alert
            "Allow",                   // ATT system alert (personalized path)
            "Consent", "Accept all", "Agree", "Continue", "OK",
        ]

        let deadline = Date().addingTimeInterval(timeout)
        while !target.exists && Date() < deadline {
            var tappedSomething = false
            tapLoop: for label in labels {
                let queries: [XCUIElementQuery] = [
                    springboard.buttons,
                    app.buttons,
                    app.links,
                    app.webViews.buttons,
                    app.webViews.links,
                    app.staticTexts,
                ]
                for query in queries {
                    let element = query[label]
                    if element.exists && element.isHittable {
                        element.tap()
                        tappedSomething = true
                        break tapLoop
                    }
                }
            }
            if !tappedSomething {
                // Google's ATT pre-prompt explainer exposes nothing to the
                // accessibility tree; its "Continue" button sits centered at
                // ~61% height. A blind tap there is harmless on the dashboard
                // (non-interactive empty-state text) if no dialog is up.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.607)).tap()
            }
            _ = target.waitForExistence(timeout: 2)
        }
    }

    /// The StoreKit-Testing purchase sheet's confirm control varies by OS;
    /// try the known labels in both the app's and springboard's hierarchies.
    @MainActor
    private func confirmStoreKitPurchase(app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let candidates: [XCUIElement] = [
            springboard.buttons["Subscribe"],
            springboard.buttons["Purchase"],
            springboard.buttons["Confirm"],
            app.buttons["Purchase"],
            app.buttons["Confirm"],
        ]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            for candidate in candidates where candidate.exists && candidate.isHittable {
                candidate.tap()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        // No confirmation sheet found — StoreKit Testing with dialogs
        // disabled completes without one; the entitlement assertions that
        // follow are the real check either way.
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
