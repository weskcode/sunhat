//
//  SavedLocation.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class SavedLocation {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Location data
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var name: String = ""
    var address: String = ""
    var city: String = ""
    var state: String = ""
    var country: String = ""
    
    // Metadata
    var dateAdded: Date = Date()
    var lastUsed: Date = Date()
    var useCount: Int = 0
    var isFavorite: Bool = false
    var customName: String?
    
    // Accuracy and source
    var accuracy: Double = 0.0
    var source: LocationSource
    
    init(
        latitude: Double,
        longitude: Double,
        name: String,
        address: String = "",
        city: String = "",
        state: String = "",
        country: String = "",
        source: LocationSource = .manual
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.source = source
    }
    
    convenience init(from clLocation: CLLocation, placemark: CLPlacemark?, source: LocationSource = .gps) {
        let name = placemark?.name ?? placemark?.locality ?? String(localized: "Unknown Location", comment: "Fallback name when reverse geocoding returns no place name")
        let address = [placemark?.thoroughfare, placemark?.locality, placemark?.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
        
        self.init(
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude,
            name: name,
            address: address,
            city: placemark?.locality ?? "",
            state: placemark?.administrativeArea ?? "",
            country: placemark?.country ?? "",
            source: source
        )
        
        self.accuracy = clLocation.horizontalAccuracy
    }
}

extension SavedLocation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var displayName: String {
        customName ?? name
    }
    
    var fullDisplayName: String {
        if let customName = customName {
            return "\(customName) (\(name))"
        }
        return name
    }
    
    var shortAddress: String {
        let components = [city, state].filter { !$0.isEmpty }
        return components.joined(separator: ", ")
    }
    
    func distance(from location: CLLocation) -> CLLocationDistance {
        return clLocation.distance(from: location)
    }
    
    func markAsUsed() {
        lastUsed = Date()
        useCount += 1
    }
}

enum LocationSource: String, Codable, CaseIterable {
    case gps = "gps"
    case manual = "manual"
    case search = "search"
    case imported = "imported"
    
    var displayName: String {
        switch self {
        case .gps:
            return String(localized: "GPS", comment: "Location source name")
        case .manual:
            return String(localized: "Manual Entry", comment: "Location source name")
        case .search:
            return String(localized: "Search", comment: "Location source name")
        case .imported:
            return String(localized: "Imported", comment: "Location source name")
        }
    }
    
    var icon: String {
        switch self {
        case .gps:
            return "location.fill"
        case .manual:
            return "pencil"
        case .search:
            return "magnifyingglass"
        case .imported:
            return "square.and.arrow.down"
        }
    }
}

@Model
final class LocationHistory {
    @Attribute(.unique) var id: UUID = UUID()
    
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var name: String = ""
    var timestamp: Date = Date()
    var accuracy: Double = 0.0
    var source: LocationSource
    
    init(
        latitude: Double,
        longitude: Double,
        name: String,
        source: LocationSource = .gps,
        accuracy: Double = 0.0
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.source = source
        self.accuracy = accuracy
    }
    
    convenience init(from savedLocation: SavedLocation) {
        self.init(
            latitude: savedLocation.latitude,
            longitude: savedLocation.longitude,
            name: savedLocation.displayName,
            source: savedLocation.source,
            accuracy: savedLocation.accuracy
        )
    }
}

extension LocationHistory {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
