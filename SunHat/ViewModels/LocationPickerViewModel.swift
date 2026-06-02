//
//  LocationPickerViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Combine
import CoreLocation
import Foundation
import MapKit

@MainActor
final class LocationPickerViewModel: NSObject, ObservableObject {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var currentLocation: CLLocation?
    @Published var isShowingSearchError = false
    @Published var searchErrorMessage = ""

    private let locationManager = CLLocationManager()
    private let searchCompleter = MKLocalSearchCompleter()

    override init() {
        super.init()
        setupLocationManager()
        setupSearchCompleter()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    private func setupSearchCompleter() {
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    func searchLocations(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        isSearching = true
        searchCompleter.queryFragment = query
    }

    func clearResults() {
        searchResults = []
        isSearching = false
    }

    func resolveLocation(_ completion: MKLocalSearchCompletion) async -> ReminderLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else {
                showError("No matching location was found.")
                return nil
            }

            return ReminderLocation(
                coordinate: mapItem.location.coordinate,
                displayName: completion.title,
                fullAddress: completion.subtitle,
                isCurrentLocation: false
            )
        } catch {
            showError("Could not resolve this location. Please try another search.")
            return nil
        }
    }

    func clearError() {
        searchErrorMessage = ""
        isShowingSearchError = false
    }

    private func showError(_ message: String) {
        searchErrorMessage = message
        isShowingSearchError = true
    }
}

extension LocationPickerViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            showError("Could not get your current location. Check Location Services and try again.")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}

extension LocationPickerViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            searchResults = results
            isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            isSearching = false
            showError("Location search is unavailable right now. Please try again.")
        }
    }
}
