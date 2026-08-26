//
//  LocationPermissionManagerTests.swift
//  SunHatTests
//
//  Regression coverage: a manually-entered location must survive an app relaunch.
//  Before this fix, `manualLocation` was in-memory only, so any consumer reading it
//  directly (WeatherViewModel, via LocationPermissionManagerAdapter) silently lost
//  the user's manual-location choice on every fresh launch, even though
//  UserPreferences.manualLocationLatitude/Longitude (read separately by
//  DashboardViewModel) survived correctly, producing a Weather tab that fell back
//  to real GPS (or an empty state) while the Dashboard kept working.
//

import CoreLocation
import Testing
@testable import SunHat

@MainActor
struct LocationPermissionManagerTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "LocationPermissionManagerTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test("A manual location survives re-initialization (simulating an app relaunch)")
    func manualLocationSurvivesRelaunch() async throws {
        let defaults = makeDefaults()
        let manager = LocationPermissionManager(userDefaults: defaults)

        let location = ManualLocationData(
            name: "San Francisco",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            country: "USA",
            administrativeArea: "CA"
        )
        manager.manualLocation = location

        // A fresh instance over the same UserDefaults simulates a cold app relaunch.
        let relaunched = LocationPermissionManager(userDefaults: defaults)

        #expect(relaunched.manualLocation?.name == "San Francisco")
        #expect(relaunched.manualLocation?.coordinate.latitude == 37.7749)
        #expect(relaunched.manualLocation?.coordinate.longitude == -122.4194)
    }

    @Test("A fresh instance with no stored location has no manual location")
    func noPersistedLocationMeansNil() async throws {
        let defaults = makeDefaults()
        let manager = LocationPermissionManager(userDefaults: defaults)

        #expect(manager.manualLocation == nil)
    }

    @Test("Clearing the manual location removes it from persistence")
    func clearingManualLocationClearsPersistence() async throws {
        let defaults = makeDefaults()
        let manager = LocationPermissionManager(userDefaults: defaults)
        manager.manualLocation = ManualLocationData(
            name: "Austin",
            coordinate: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
        )

        manager.manualLocation = nil

        let relaunched = LocationPermissionManager(userDefaults: defaults)
        #expect(relaunched.manualLocation == nil)
    }

    @Test("Privacy reset clears persisted and in-memory location data")
    func privacyResetClearsAllLocationData() {
        let defaults = makeDefaults()
        let manager = LocationPermissionManager(userDefaults: defaults)
        manager.currentLocation = CLLocation(latitude: 30.2672, longitude: -97.7431)
        manager.manualLocation = ManualLocationData(
            name: "Austin",
            coordinate: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
        )

        manager.clearStoredLocationData()

        #expect(manager.currentLocation == nil)
        #expect(manager.manualLocation == nil)
        #expect(LocationPermissionManager(userDefaults: defaults).manualLocation == nil)
    }
}
