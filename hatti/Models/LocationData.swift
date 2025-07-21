//
//  LocationData.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationData {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Core location data
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    
    // Location metadata
    var city: String = ""
    var state: String = ""
    var country: String = ""
    var postalCode: String = ""
    
    // Timezone information
    var timeZoneIdentifier: String = ""
    var timeZoneAbbreviation: String = ""
    var utcOffset: TimeInterval = 0
    
    // Location accuracy and metadata
    var horizontalAccuracy: Double = 0.0
    var lastUpdated: Date = Date()
    var isUserLocation: Bool = false
    var isManuallyEntered: Bool = false
    
    // Display and naming
    var displayName: String = ""
    var customName: String?
    
    // Weather service metadata
    var weatherServiceLocationID: String?
    var elevationMeters: Double?
    
    // CloudKit optimization
    @Attribute(.externalStorage) var locationMetadata: Data?
    
    // Relationships
    var weatherReminders: [WeatherReminder] = []
    var weatherData: [WeatherData] = []
    
    init(
        latitude: Double,
        longitude: Double,
        city: String = "",
        timeZoneIdentifier: String = ""
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayName = city.isEmpty ? "Location (\(latitude), \(longitude))" : city
    }
    
    convenience init(from clLocation: CLLocation, placemark: CLPlacemark? = nil) {
        self.init(
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude
        )
        
        self.altitude = clLocation.altitude
        self.horizontalAccuracy = clLocation.horizontalAccuracy
        self.lastUpdated = clLocation.timestamp
        
        if let placemark = placemark {
            self.city = placemark.locality ?? ""
            self.state = placemark.administrativeArea ?? ""
            self.country = placemark.country ?? ""
            self.postalCode = placemark.postalCode ?? ""
            let nameComponents: [String] = [placemark.locality, placemark.administrativeArea].compactMap { $0 }
            self.displayName = nameComponents.joined(separator: ", ")
        }
        
        // Set timezone information - CLPlacemark doesn't have timeZone property
        let timeZone = TimeZone.current
        self.timeZoneIdentifier = timeZone.identifier
        self.timeZoneAbbreviation = timeZone.abbreviation() ?? ""
        self.utcOffset = TimeInterval(timeZone.secondsFromGMT())
    }
}

extension LocationData {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 0,
            timestamp: lastUpdated
        )
    }
    
    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }
    
    func distance(from other: LocationData) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
    
    var shortDisplayName: String {
        customName ?? city
    }
    
    var fullDisplayName: String {
        if let customName = customName {
            return customName
        }
        
        let components = [city, state].compactMap { $0.isEmpty ? nil : $0 }
        return components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
    }
}