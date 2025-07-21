//
//  LocationManagementViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Combine
import os.log

@MainActor
final class LocationManagementViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentLocation: CLLocation?
    @Published var currentLocationName: String = "Getting location..."
    @Published var currentLocationAccuracy: String = "Unknown"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    @Published var savedLocations: [SavedLocation] = []
    @Published var locationHistory: [LocationHistory] = []
    @Published var isLoadingCurrentLocation = false
    @Published var locationError: LocationError?
    
    @Published var showingAddLocation = false
    @Published var showingLocationPicker = false
    @Published var showingPermissionAlert = false
    @Published var showingDeleteConfirmation = false
    @Published var locationToDelete: SavedLocation?
    
    @Published var searchText = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private let locationManager = CLLocationManager()
    private let searchCompleter = MKLocalSearchCompleter()
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "LocationManagementViewModel")
    
    private var cancellables = Set<AnyCancellable>()
    private var locationUpdateTimer: Timer?
    private var timer: Timer?
    
    private let locationTimeout: TimeInterval = 15.0
    
    // MARK: - Initialization
    
    init() {
        setupLocationManager()
        setupSearchCompleter()
        setupBindings()
    }
    
    // MARK: - Setup Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSavedLocations()
        loadLocationHistory()
        updateCurrentLocationIfNeeded()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = locationManager.authorizationStatus
        
        self.logger.info("Location manager initialized with status: \(self.authorizationStatus.description)")
    }
    
    private func setupSearchCompleter() {
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }
    
    private func setupBindings() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] (searchText: String) in
                self?.performSearch(searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Permission Methods
    
    func requestLocationPermission() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = .locationServicesDisabled
            showingPermissionAlert = true
            return
        }
        
        switch authorizationStatus {
        case .notDetermined:
            logger.info("Requesting location permission")
            locationManager.requestWhenInUseAuthorization()
            
        case .denied, .restricted:
            logger.warning("Location permission denied or restricted")
            locationError = .permissionDenied
            showingPermissionAlert = true
            
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("Location permission already granted")
            getCurrentLocation()
            
        @unknown default:
            logger.error("Unknown location authorization status")
            locationError = .unknown
        }
    }
    
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            logger.error("Could not create settings URL")
            return
        }
        
        logger.info("Opening app settings")
        UIApplication.shared.open(settingsURL)
    }
    
    // MARK: - Current Location Methods
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.warning("Attempted to get location without proper authorization")
            requestLocationPermission()
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = .locationServicesDisabled
            return
        }
        
        isLoadingCurrentLocation = true
        locationError = nil
        currentLocationName = "Getting location..."
        
        logger.info("Starting location update")
        locationManager.startUpdatingLocation()
        
        // Set timeout for location request
        startLocationTimeout()
    }
    
    private func startLocationTimeout() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: locationTimeout, repeats: false, block: { [weak self] (_: Timer) in
            guard let self = self else { return }
            Task { @MainActor in
                self.timer?.invalidate()
                self.handleLocationTimeout()
            }
        })
    }
    
    private func handleLocationTimeout() {
        logger.warning("Location request timed out")
        locationManager.stopUpdatingLocation()
        isLoadingCurrentLocation = false
        locationError = .timeout
        
        // Use last known location if available
        if let lastLocation = locationManager.location {
            logger.info("Using last known location due to timeout")
            processLocationUpdate(lastLocation)
        } else {
            currentLocationName = "Location unavailable"
            currentLocationAccuracy = "Unknown"
        }
    }
    
    private func processLocationUpdate(_ location: CLLocation) {
        currentLocation = location
        updateLocationAccuracy(location)
        
        // Reverse geocode to get readable name using CLGeocoder
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.error("Reverse geocoding failed: \(error.localizedDescription)")
                    self?.currentLocationName = "Unknown Location"
                } else if let placemark = placemarks?.first {
                    self?.currentLocationName = self?.formatPlacemarkName(placemark) ?? "Unknown Location"
                } else {
                    self?.currentLocationName = "Unknown Location"
                }
            }
        }
        
        // Add to history
        addToLocationHistory(location, name: "Current Location", source: .gps)
    }
    
    private func updateLocationAccuracy(_ location: CLLocation) {
        let accuracy = location.horizontalAccuracy
        
        if accuracy < 0 {
            currentLocationAccuracy = "Invalid"
        } else if accuracy < 5 {
            currentLocationAccuracy = "Excellent (±\(Int(accuracy))m)"
        } else if accuracy < 20 {
            currentLocationAccuracy = "Good (±\(Int(accuracy))m)"
        } else if accuracy < 100 {
            currentLocationAccuracy = "Fair (±\(Int(accuracy))m)"
        } else {
            currentLocationAccuracy = "Poor (±\(Int(accuracy))m)"
        }
    }
    
    private func formatPlacemarkName(_ placemark: CLPlacemark) -> String {
        let components = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }
        
        return components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
    }
    
    private func updateCurrentLocationIfNeeded() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        // Check if we have a recent location
        if let lastLocation = currentLocation,
           abs(lastLocation.timestamp.timeIntervalSinceNow) < 300 { // 5 minutes
            return
        }
        
        getCurrentLocation()
    }
    
    // MARK: - Saved Locations Methods
    
    private func loadSavedLocations() {
        guard let modelContext = modelContext else { return }
        do {
            let fetchedLocations = try modelContext.fetch(FetchDescriptor<SavedLocation>())
            self.savedLocations = fetchedLocations.sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }
                if let lhsLastUsed = lhs.lastUsed, let rhsLastUsed = rhs.lastUsed {
                    return lhsLastUsed > rhsLastUsed
                }
                return false
            }
            self.logger.info("Loaded \(self.savedLocations.count) saved locations")
        } catch {
            self.logger.error("Failed to load saved locations: \(error.localizedDescription)")
        }
    }
    
    func addSavedLocation(_ location: SavedLocation) {
        guard let modelContext = modelContext else { return }
        
        let existingLocation = savedLocations.first { [self] (savedLocation: SavedLocation) -> Bool in
            savedLocation.distance(from: location.clLocation) < 100 // Within 100 meters
        }
        
        if let existing = existingLocation {
            existing.markAsUsed()
            logger.info("Updated existing location: \(existing.name)")
        } else {
            modelContext.insert(location)
            savedLocations.append(location)
            logger.info("Added new saved location: \(location.name)")
        }
        
        // Add to history
        addToLocationHistory(location.clLocation, name: location.name, source: location.source)
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save location: \(error.localizedDescription)")
        }
    }
    
    func deleteSavedLocation(_ location: SavedLocation) {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(location)
        savedLocations.removeAll { $0.id == location.id }
        
        do {
            try modelContext.save()
            logger.info("Deleted saved location: \(location.name)")
        } catch {
            logger.error("Failed to delete location: \(error.localizedDescription)")
        }
    }
    
    func toggleFavorite(_ location: SavedLocation) {
        location.isFavorite.toggle()
        
        do {
            try modelContext?.save()
            self.loadSavedLocations() // Reload to update sorting
            self.logger.info("Toggled favorite for location: \(location.name)")
        } catch {
            self.logger.error("Failed to toggle favorite: \(error.localizedDescription)")
        }
    }
    
    func updateLocationName(_ location: SavedLocation, newName: String) {
        location.customName = newName.isEmpty ? nil : newName
        
        do {
            try modelContext?.save()
            logger.info("Updated location name: \(location.name) -> \(newName)")
        } catch {
            logger.error("Failed to update location name: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Location History Methods
    
    private func loadLocationHistory() {
        guard let modelContext = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<LocationHistory>()
            descriptor.sortBy = [SortDescriptor(\LocationHistory.timestamp, order: .reverse)]
            descriptor.fetchLimit = 10 // Last 10 locations
            let fetchedHistory = try modelContext.fetch(descriptor)
            self.locationHistory = fetchedHistory
            self.logger.info("Loaded \(self.locationHistory.count) location history entries")
        } catch {
            self.logger.error("Failed to load location history: \(error.localizedDescription)")
        }
    }
    
    private func addToLocationHistory(_ location: CLLocation, name: String, source: LocationSource) {
        guard let modelContext = modelContext else { return }
        let historyEntry = LocationHistory(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: name,
            source: source,
            accuracy: location.horizontalAccuracy
        )
        modelContext.insert(historyEntry)
        self.locationHistory.insert(historyEntry, at: 0)
        // Keep only last 10 entries
        if self.locationHistory.count > 10 {
            let toRemove = Array(self.locationHistory.dropFirst(10))
            toRemove.forEach { modelContext.delete($0) }
            self.locationHistory = Array(self.locationHistory.prefix(10))
        }
        do {
            try modelContext.save()
        } catch {
            self.logger.error("Failed to save location history: \(error.localizedDescription)")
        }
    }
    
    func clearLocationHistory() {
        guard let modelContext = modelContext else { return }
        self.locationHistory.forEach { modelContext.delete($0) }
        self.locationHistory.removeAll()
        do {
            try modelContext.save()
            self.logger.info("Cleared location history")
        } catch {
            self.logger.error("Failed to clear location history: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Search Methods
    
    private func performSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchCompleter.queryFragment = query
    }
    
    func resolveSearchResult(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        search.start { [weak self] (response: MKLocalSearch.Response?, error: Error?) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.error("Search resolution failed: \(error.localizedDescription)")
                    return
                }
                
                guard let mapItem = response?.mapItems.first else {
                    self.logger.warning("No map items found for search result")
                    return
                }
                
                let savedLocation = SavedLocation(
                    latitude: mapItem.placemark.coordinate.latitude,
                    longitude: mapItem.placemark.coordinate.longitude,
                    name: completion.title,
                    address: completion.subtitle,
                    city: mapItem.placemark.locality ?? "",
                    state: mapItem.placemark.administrativeArea ?? "",
                    country: mapItem.placemark.country ?? "",
                    source: .search
                )
                
                self.addSavedLocation(savedLocation)
                self.searchText = ""
                self.searchResults = []
            }
        }
    }
    
    // MARK: - Privacy Information
    
    var privacyExplanation: String {
        """
        TempTrigger uses your location to:
        • Provide accurate weather data for your area
        • Send timely reminders based on local conditions
        • Ensure weather triggers work for your specific location
        
        Your location data:
        • Stays on your device and in your iCloud (if enabled)
        • Is only used for weather updates
        • Is never shared with third parties
        • Can be managed or deleted at any time
        
        You can:
        • Use manual location entry instead of GPS
        • Delete saved locations anytime
        • Clear location history
        • Revoke location permission in Settings
        """
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManagementViewModel: CLLocationManagerDelegate {
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = manager.authorizationStatus
            self.logger.info("Location authorization changed to: \(newStatus.description)")
            
            self.authorizationStatus = newStatus
            
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                self.getCurrentLocation()
                
            case .denied, .restricted:
                self.locationError = .permissionDenied
                self.currentLocationName = "Location access denied"
                self.currentLocationAccuracy = "Unknown"
                
            case .notDetermined:
                self.currentLocationName = "Location permission needed"
                self.currentLocationAccuracy = "Unknown"
                
            @unknown default:
                self.locationError = .unknown
                self.currentLocationName = "Location unavailable"
                self.currentLocationAccuracy = "Unknown"
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            self.logger.info("Location updated: \(location.coordinate)")
            
            // Stop location updates and timer
            self.locationManager.stopUpdatingLocation()
            self.locationUpdateTimer?.invalidate()
            self.locationUpdateTimer = nil
            self.isLoadingCurrentLocation = false
            
            // Validate location accuracy
            if location.horizontalAccuracy < 0 {
                self.logger.warning("Invalid location accuracy: \(location.horizontalAccuracy)")
                self.locationError = .inaccurateLocation
                return
            }
            
            // Check if location is too old (more than 5 minutes)
            if abs(location.timestamp.timeIntervalSinceNow) > 300 {
                self.logger.warning("Location timestamp is too old: \(location.timestamp)")
                self.locationError = .staleLocation
                return
            }
            
            self.processLocationUpdate(location)
            self.locationError = nil
            
            self.logger.info("Successfully obtained current location with accuracy: \(location.horizontalAccuracy)m")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.logger.error("Location manager failed with error: \(error.localizedDescription)")
            
            self.locationManager.stopUpdatingLocation()
            self.locationUpdateTimer?.invalidate()
            self.locationUpdateTimer = nil
            self.isLoadingCurrentLocation = false
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = .permissionDenied
                    self.currentLocationName = "Location access denied"
                case .network:
                    self.locationError = .networkError
                    self.currentLocationName = "Network error"
                case .locationUnknown:
                    self.locationError = .locationUnavailable
                    self.currentLocationName = "Location unavailable"
                default:
                    self.locationError = .unknown
                    self.currentLocationName = "Location error"
                }
            } else {
                self.locationError = .unknown
                self.currentLocationName = "Location error"
            }
            
            self.currentLocationAccuracy = "Unknown"
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension LocationManagementViewModel: MKLocalSearchCompleterDelegate {
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.searchResults = completer.results
            self.isSearching = false
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.logger.error("Search completer failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.searchResults = []
            self.isSearching = false
        }
    }
}
