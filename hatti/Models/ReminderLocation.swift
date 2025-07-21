//
//  ReminderLocation.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import CoreLocation

struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ReminderLocation: Codable, Identifiable {
    let id = UUID()
    let coordinate: CodableCoordinate
    let displayName: String
    let fullAddress: String?
    let isCurrentLocation: Bool
    
    init(
        coordinate: CLLocationCoordinate2D,
        displayName: String,
        fullAddress: String? = nil,
        isCurrentLocation: Bool = false
    ) {
        self.coordinate = CodableCoordinate(coordinate)
        self.displayName = displayName
        self.fullAddress = fullAddress
        self.isCurrentLocation = isCurrentLocation
    }
    
    static let currentLocation = ReminderLocation(
        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        displayName: "Current Location",
        isCurrentLocation: true
    )
    
    var isValid: Bool {
        return isCurrentLocation || (!displayName.isEmpty && coordinate.latitude != 0 && coordinate.longitude != 0)
    }
}