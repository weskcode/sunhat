//
//  ReminderLocation.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import CoreLocation

struct CodableCoordinate: @unchecked Sendable {
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

// MARK: - Codable Implementation
extension CodableCoordinate: Codable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }
    
    nonisolated private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}

struct ReminderLocation: @unchecked Sendable, Identifiable {
    let id: UUID
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
        self.id = UUID()
        self.coordinate = CodableCoordinate(coordinate)
        self.displayName = displayName
        self.fullAddress = fullAddress
        self.isCurrentLocation = isCurrentLocation
    }
    
    var isValid: Bool {
        return isCurrentLocation || (!displayName.isEmpty && coordinate.latitude != 0 && coordinate.longitude != 0)
    }
}

// MARK: - Codable Implementation
extension ReminderLocation: Codable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(fullAddress, forKey: .fullAddress)
        try container.encode(isCurrentLocation, forKey: .isCurrentLocation)
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        coordinate = try container.decode(CodableCoordinate.self, forKey: .coordinate)
        displayName = try container.decode(String.self, forKey: .displayName)
        fullAddress = try container.decodeIfPresent(String.self, forKey: .fullAddress)
        isCurrentLocation = try container.decode(Bool.self, forKey: .isCurrentLocation)
    }
    
    nonisolated private enum CodingKeys: String, CodingKey {
        case id
        case coordinate
        case displayName
        case fullAddress
        case isCurrentLocation
    }
}

// Static factory to avoid circular reference
extension ReminderLocation {
    static var currentLocation: ReminderLocation {
        ReminderLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            displayName: "Current Location",
            isCurrentLocation: true
        )
    }
}
