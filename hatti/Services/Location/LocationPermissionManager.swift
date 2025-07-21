//
//  LocationPermissionManager.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine
import os.log

@MainActor
final class LocationPermissionManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var manualLocation: ManualLocationData?
    @Published var showPermissionDeniedAlert = false
    @Published var isLocationServicesEnabled = true
    @Published var locationError: LocationError?
    
    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "LocationPermissionManager")
    private var permissionCompletionHandler: ((Bool) -> Void)?
    
    // Location accuracy and timeout settings
    private let desiredAccuracy = kCLLocationAccuracyHundredMeters
    private let locationTimeout: TimeInterval = 15.0
    private var locationTimer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
        checkLocationServicesStatus()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        authorizationStatus = locationManager.authorizationStatus
        isLocationServicesEnabled = CLLocationManager.locationServicesEnabled()
        
        logger.info("Location manager initialized with status: \(self.authorizationStatus.description)")
    }
    
    private func checkLocationServicesStatus() {
        isLocationServicesEnabled = CLLocationManager.locationServicesEnabled()
        
        if !isLocationServicesEnabled {
            locationError = .locationServicesDisabled
            logger.warning("Location services are disabled system-wide")
        }
    }
    
    // MARK: - Permission Request
    
    func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        guard isLocationServicesEnabled else {
            locationError = .locationServicesDisabled
            showPermissionDeniedAlert = true
            completion(false)
            return
        }
        
        permissionCompletionHandler = completion
        
        switch authorizationStatus {
        case .notDetermined:
            logger.info("Requesting location permission for the first time")
            locationManager.requestWhenInUseAuthorization()
            
        case .denied, .restricted:
            logger.warning("Location permission denied or restricted")
            locationError = .permissionDenied
            showPermissionDeniedAlert = true
            completion(false)
            
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("Location permission already granted")
            getCurrentLocation()
            completion(true)
            
        @unknown default:
            logger.error("Unknown location authorization status")
            locationError = .unknown
            completion(false)
        }
    }
    
    // MARK: - Location Fetching
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.warning("Attempted to get location without proper authorization")
            return
        }
        
        guard isLocationServicesEnabled else {
            locationError = .locationServicesDisabled
            return
        }
        
        logger.info("Starting location update")
        locationManager.startUpdatingLocation()
        
        // Set timeout for location request
        locationTimer = Timer.scheduledTimer(withTimeInterval: locationTimeout, repeats: false) { [weak self] _ in
            self?.handleLocationTimeout()
        }
    }
    
    private func handleLocationTimeout() {
        logger.warning("Location request timed out")
        locationManager.stopUpdatingLocation()
        locationError = .timeout
        
        // If we have a stale location, use it
        if let lastLocation = locationManager.location {
            logger.info("Using last known location due to timeout")
            currentLocation = lastLocation
        }
    }
    
    // MARK: - Manual Location
    
    func setManualLocation(_ location: ManualLocationData) {
        manualLocation = location
        currentLocation = CLLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        logger.info("Manual location set: \(location.name)")
    }
    
    // MARK: - Utility Methods
    
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            logger.error("Could not create settings URL")
            return
        }
        
        logger.info("Opening app settings")
        UIApplication.shared.open(settingsURL)
    }
    
    func hasValidLocation() -> Bool {
        return currentLocation != nil || manualLocation != nil
    }
    
    func getDisplayLocation() -> String {
        if let manual = manualLocation {
            return manual.name
        } else if let current = currentLocation {
            return "Current Location (\(String(format: "%.2f", current.coordinate.latitude)), \(String(format: "%.2f", current.coordinate.longitude)))"
        } else {
            return "No Location Set"
        }
    }
    
    // MARK: - Privacy Information
    
    func getPrivacyExplanation() -> String {
        return """
        TempTrigger uses your location to:
        • Provide accurate weather data for your area
        • Send timely reminders based on local conditions
        • Ensure weather triggers work for your specific location
        
        Your location data:
        • Stays on your device
        • Is only used for weather updates
        • Is never shared with third parties
        • Can be changed to manual entry at any time
        """
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationPermissionManager: CLLocationManagerDelegate {
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = manager.authorizationStatus
            logger.info("Location authorization changed to: \(newStatus.description)")
            
            authorizationStatus = newStatus
            
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationError = nil
                getCurrentLocation()
                permissionCompletionHandler?(true)
                
            case .denied, .restricted:
                locationError = .permissionDenied
                showPermissionDeniedAlert = true
                permissionCompletionHandler?(false)
                
            case .notDetermined:
                // Still waiting for user decision
                break
                
            @unknown default:
                locationError = .unknown
                permissionCompletionHandler?(false)
            }
            
            permissionCompletionHandler = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            logger.info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Stop location updates and timer
            locationManager.stopUpdatingLocation()
            locationTimer?.invalidate()
            locationTimer = nil
            
            // Validate location accuracy
            if location.horizontalAccuracy < 0 {
                logger.warning("Invalid location accuracy: \(location.horizontalAccuracy)")
                locationError = .inaccurateLocation
                return
            }
            
            // Check if location is too old (more than 5 minutes)
            if abs(location.timestamp.timeIntervalSinceNow) > 300 {
                logger.warning("Location timestamp is too old: \(location.timestamp)")
                locationError = .staleLocation
                return
            }
            
            currentLocation = location
            locationError = nil
            
            logger.info("Successfully obtained current location with accuracy: \(location.horizontalAccuracy)m")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Location manager failed with error: \(error.localizedDescription)")
            
            locationManager.stopUpdatingLocation()
            locationTimer?.invalidate()
            locationTimer = nil
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = .permissionDenied
                    showPermissionDeniedAlert = true
                case .network:
                    locationError = .networkError
                case .locationUnknown:
                    locationError = .locationUnavailable
                case .network:
                    locationError = .timeout
                default:
                    locationError = .unknown
                }
            } else {
                locationError = .unknown
            }
        }
    }
}

// MARK: - Location Error Types

enum LocationError: LocalizedError, Sendable {
    case permissionDenied
    case locationServicesDisabled
    case networkError
    case timeout
    case inaccurateLocation
    case staleLocation
    case locationUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .locationServicesDisabled:
            return "Location services are disabled"
        case .networkError:
            return "Network error while getting location"
        case .timeout:
            return "Location request timed out"
        case .inaccurateLocation:
            return "Location accuracy is too low"
        case .staleLocation:
            return "Location data is too old"
        case .locationUnavailable:
            return "Current location is unavailable"
        case .unknown:
            return "Unknown location error"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "The app does not have permission to access your location"
        case .locationServicesDisabled:
            return "Location services are turned off in device settings"
        case .networkError:
            return "Unable to connect to location services"
        case .timeout:
            return "Location request took too long to complete"
        case .inaccurateLocation:
            return "The GPS signal is too weak for accurate positioning"
        case .staleLocation:
            return "The last known location is too old to be useful"
        case .locationUnavailable:
            return "Your current location cannot be determined"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Location Services to enable location access"
        case .locationServicesDisabled:
            return "Enable Location Services in Settings > Privacy & Security > Location Services"
        case .networkError:
            return "Check your internet connection and try again"
        case .timeout:
            return "Try moving to an area with better GPS reception"
        case .inaccurateLocation:
            return "Move to an open area away from buildings and try again"
        case .staleLocation:
            return "Try getting your location again"
        case .locationUnavailable:
            return "Try entering your city manually instead"
        case .unknown:
            return "Try again or enter your city manually"
        }
    }
}

// MARK: - Manual Location Data

struct ManualLocationData: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let country: String?
    let administrativeArea: String? // State/Province
    
    init(name: String, coordinate: CLLocationCoordinate2D, country: String? = nil, administrativeArea: String? = nil) {
        self.name = name
        self.coordinate = coordinate
        self.country = country
        self.administrativeArea = administrativeArea
    }
    
    var displayName: String {
        var components = [name]
        if let admin = administrativeArea {
            components.append(admin)
        }
        if let country = country {
            components.append(country)
        }
        return components.joined(separator: ", ")
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension

// Note: CLLocationCoordinate2D already conforms to Codable in iOS 17+
// This extension is only needed for iOS 16 and earlier
@available(iOS, deprecated: 17.0, message: "CLLocationCoordinate2D now conforms to Codable natively")
extension CLLocationCoordinate2D: @retroactive Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}

// MARK: - CLAuthorizationStatus Description Extension

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }
}