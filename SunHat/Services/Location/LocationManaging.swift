//
//  LocationManaging.swift
//  SunHat
//
//  Created by Codex on 6/2/26.
//

import CoreLocation
import Foundation
import os

protocol LocationManaging {
    func currentLocation() async -> (location: CLLocation, name: String)?
}

final class LocationPermissionManagerAdapter: LocationManaging {
    private let locationPermissionManager: LocationPermissionManager
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "LocationAdapter")

    init(locationPermissionManager: LocationPermissionManager) {
        self.locationPermissionManager = locationPermissionManager
    }

    func currentLocation() async -> (location: CLLocation, name: String)? {
        if locationPermissionManager.authorizationStatus == .notDetermined {
            locationPermissionManager.requestLocationPermission { _ in }
        }

        if let manualLocation = locationPermissionManager.manualLocation {
            let location = CLLocation(
                latitude: manualLocation.coordinate.latitude,
                longitude: manualLocation.coordinate.longitude
            )
            return (location, LocationDisplayFormatter.privacyPreservingName(from: manualLocation.displayName))
        }

        if let currentLocation = locationPermissionManager.currentLocation {
            let locationName = await LocationDisplayFormatter.reverseGeocodedName(for: currentLocation)
            return (currentLocation, locationName)
        }

        if locationPermissionManager.authorizationStatus == .authorizedWhenInUse ||
            locationPermissionManager.authorizationStatus == .authorizedAlways {
            locationPermissionManager.getCurrentLocation()

            if let location = await waitForCurrentLocation() {
                let locationName = await LocationDisplayFormatter.reverseGeocodedName(for: location)
                return (location, locationName)
            }
        }

        logger.warning("Could not obtain user location - no fallback used")
        return nil
    }

    private func waitForCurrentLocation(maxAttempts: Int = 20) async -> CLLocation? {
        for _ in 0..<maxAttempts {
            try? await Task.sleep(for: .milliseconds(500))

            if let location = locationPermissionManager.currentLocation {
                return location
            }

            if locationPermissionManager.authorizationStatus == .denied ||
                locationPermissionManager.authorizationStatus == .restricted {
                return nil
            }
        }

        return nil
    }
}

final class DefaultLocationManager: LocationManaging {
    static let shared = DefaultLocationManager()

    private var cached: (CLLocation, String)?

    func currentLocation() async -> (location: CLLocation, name: String)? {
        if let cached {
            return cached
        }

        let manager = LocationPermissionManager.shared
        guard let currentLocation = manager.currentLocation else {
            return nil
        }

        let name = await LocationDisplayFormatter.reverseGeocodedName(for: currentLocation)
        cached = (currentLocation, name)
        return cached
    }
}
