//
//  UserPreferencesTests.swift
//  SunHatTests
//
//  Covers the UserPreferences settings model: activity interest management,
//  quiet hours presentation, and timestamp bookkeeping.
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct UserPreferencesTests {

    // MARK: - Defaults

    @Test("A new preferences object starts with no activity interests")
    func defaultsHaveNoInterests() {
        let preferences = UserPreferences()
        #expect(preferences.selectedActivityInterests.isEmpty)
    }

    @Test("Quiet hours are enabled by default with a five-notification daily cap")
    func defaultNotificationLimits() {
        let preferences = UserPreferences()
        #expect(preferences.quietHoursEnabled == true)
        #expect(preferences.maximumDailyNotifications == 5)
    }

    // MARK: - Activity interest management

    @Test("Adding an activity interest records it")
    func addInterest() {
        let preferences = UserPreferences()

        preferences.addActivityInterest(.gardening)

        #expect(preferences.hasActivityInterest(.gardening))
        #expect(preferences.selectedActivityInterests.count == 1)
    }

    @Test("Adding the same interest twice does not create duplicates")
    func addInterestIsIdempotent() {
        let preferences = UserPreferences()

        preferences.addActivityInterest(.gardening)
        preferences.addActivityInterest(.gardening)

        #expect(preferences.selectedActivityInterests.count == 1)
    }

    @Test("Removing an interest clears it")
    func removeInterest() {
        let preferences = UserPreferences()
        preferences.addActivityInterest(.cycling)

        preferences.removeActivityInterest(.cycling)

        #expect(preferences.hasActivityInterest(.cycling) == false)
        #expect(preferences.selectedActivityInterests.isEmpty)
    }

    @Test("Toggling flips an interest on and back off")
    func toggleInterest() {
        let preferences = UserPreferences()

        preferences.toggleActivityInterest(.hiking)
        #expect(preferences.hasActivityInterest(.hiking) == true)

        preferences.toggleActivityInterest(.hiking)
        #expect(preferences.hasActivityInterest(.hiking) == false)
    }

    @Test("Interests are stored by their raw string value")
    func interestsStoredAsRawValues() {
        let preferences = UserPreferences()

        preferences.addActivityInterest(.outdoorDining)

        #expect(preferences.selectedActivityInterests.contains(ActivityInterest.outdoorDining.rawValue))
    }

    // MARK: - Quiet hours description

    @Test("Quiet hours description shows a time range when enabled")
    func quietHoursDescriptionWhenEnabled() {
        let preferences = UserPreferences()
        preferences.quietHoursEnabled = true

        #expect(preferences.quietHoursDescription.contains("-"))
        #expect(preferences.quietHoursDescription != "Disabled")
    }

    @Test("Quiet hours description reads Disabled when turned off")
    func quietHoursDescriptionWhenDisabled() {
        let preferences = UserPreferences()
        preferences.quietHoursEnabled = false

        #expect(preferences.quietHoursDescription == String(localized: "Disabled", comment: "Quiet hours state when the user has turned them off"))
    }

    // MARK: - Timestamp bookkeeping

    @Test("Updating the timestamp advances updatedAt")
    func updateTimestampAdvances() async throws {
        let preferences = UserPreferences()
        let original = preferences.updatedAt

        try await Task.sleep(for: .milliseconds(10))
        preferences.updateTimestamp()

        #expect(preferences.updatedAt > original)
    }

    @Test("Mutating activity interests refreshes the timestamp")
    func interestMutationRefreshesTimestamp() async throws {
        let preferences = UserPreferences()
        let original = preferences.updatedAt

        try await Task.sleep(for: .milliseconds(10))
        preferences.addActivityInterest(.sports)

        #expect(preferences.updatedAt > original)
    }
}
