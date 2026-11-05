//
//  LocationManaging.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/2/26.
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
        if let manualLocation = locationPermissionManager.manualLocation {
            let location = CLLocation(
                latitude: manualLocation.coordinate.latitude,
                longitude: manualLocation.coordinate.longitude
            )
            return (location, LocationDisplayFormatter.privacyPreservingName(from: manualLocation.displayName))
        }

        if let location = await locationPermissionManager.resolveCurrentLocation() {
            let name = await LocationDisplayFormatter.reverseGeocodedName(for: location)
            return (location, name)
        }

        logger.warning("Could not obtain user location - no fallback used")
        return nil
    }
}

final class DefaultLocationManager: LocationManaging {
    static let shared = DefaultLocationManager()
    private let manager: LocationPermissionManager

    init(manager: LocationPermissionManager = .shared) {
        self.manager = manager
    }

    func currentLocation() async -> (location: CLLocation, name: String)? {
        guard let location = await manager.resolveCurrentLocation() else { return nil }
        return (location, String(localized: "Current Location", comment: "The device's GPS location"))
    }
}
