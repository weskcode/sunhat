//
//  ManualLocationActivationTests.swift
//  SunHatTests
//
//  Regression coverage: entering coordinates in Settings must change the
//  location Dashboard uses. Dashboard resolves `UserPreferences` before
//  `LocationPermissionManager`, so a user who picked a manual location during
//  onboarding kept seeing that old location on Dashboard while Weather showed
//  the new one.
//

import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct ManualLocationActivationTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([UserPreferences.self, SavedLocation.self, LocationHistory.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    private func makeManager() -> LocationPermissionManager {
        let defaults = UserDefaults(suiteName: "ManualLocationActivationTests.\(UUID().uuidString)")!
        return LocationPermissionManager(userDefaults: defaults)
    }

    @Test("A new manual location replaces an older one saved in UserPreferences")
    func newManualLocationUpdatesPreferences() throws {
        let context = try makeContext()
        let preferences = UserPreferences()
        preferences.locationMode = "manual"
        preferences.manualLocationLatitude = 40.7128
        preferences.manualLocationLongitude = -74.0060
        preferences.manualLocationName = "New York"
        context.insert(preferences)
        try context.save()

        let viewModel = LocationManagementViewModel()
        viewModel.configure(modelContext: context)
        let manager = makeManager()
        let denver = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        )

        viewModel.activateManualLocation(denver, permissionManager: manager)

        let saved = try #require(try context.fetch(FetchDescriptor<UserPreferences>()).first)
        #expect(saved.locationMode == "manual")
        #expect(saved.manualLocationLatitude == 39.7392)
        #expect(saved.manualLocationLongitude == -104.9903)
        #expect(saved.manualLocationName == "Denver")
        #expect(manager.manualLocation?.name == "Denver")
    }

    @Test("A user on GPS mode is switched to manual so Dashboard follows the new location")
    func gpsModeSwitchesToManual() throws {
        let context = try makeContext()
        let preferences = UserPreferences()
        preferences.locationMode = "gps"
        context.insert(preferences)
        try context.save()

        let viewModel = LocationManagementViewModel()
        viewModel.configure(modelContext: context)
        let manager = makeManager()
        let oslo = ManualLocationData(
            name: "Oslo",
            coordinate: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
        )

        viewModel.activateManualLocation(oslo, permissionManager: manager)

        let saved = try #require(try context.fetch(FetchDescriptor<UserPreferences>()).first)
        #expect(saved.locationMode == "manual")
        #expect(saved.manualLocationLatitude == 59.9139)
        #expect(saved.manualLocationLongitude == 10.7522)
        #expect(saved.manualLocationName == "Oslo")
        #expect(manager.manualLocation?.name == "Oslo")
    }

    @Test("Without a preferences record only the manager changes; no record is created")
    func missingPreferencesCreatesNoRecord() throws {
        let context = try makeContext()
        let viewModel = LocationManagementViewModel()
        viewModel.configure(modelContext: context)
        let manager = makeManager()
        let lima = ManualLocationData(
            name: "Lima",
            coordinate: CLLocationCoordinate2D(latitude: -12.0464, longitude: -77.0428)
        )

        viewModel.activateManualLocation(lima, permissionManager: manager)

        #expect(try context.fetch(FetchDescriptor<UserPreferences>()).isEmpty)
        #expect(manager.manualLocation?.name == "Lima")
    }
}
