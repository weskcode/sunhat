//
//  LocationPickerViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import CoreLocation
import Foundation
import MapKit

@MainActor @Observable
final class LocationPickerViewModel {
    var searchResults: [MKLocalSearchCompletion] = []
    var isSearching = false
    var currentLocation: CLLocation?
    var isShowingSearchError = false
    var searchErrorMessage = ""

    private let delegate: LocationPickerDelegate

    init() {
        let delegate = LocationPickerDelegate()
        self.delegate = delegate

        delegate.onLocationUpdate = { [weak self] location in
            self?.currentLocation = location
        }
        delegate.onLocationError = { [weak self] message in
            self?.showError(message)
        }
        delegate.onSearchResults = { [weak self] results in
            self?.searchResults = results
            self?.isSearching = false
        }
        delegate.onSearchError = { [weak self] message in
            self?.isSearching = false
            self?.showError(message)
        }
    }

    func searchLocations(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        isSearching = true
        delegate.search(query)
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

private final class LocationPickerDelegate: NSObject, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {
    let locationManager = CLLocationManager()
    let searchCompleter = MKLocalSearchCompleter()

    var onLocationUpdate: (@MainActor (CLLocation) -> Void)?
    var onLocationError: (@MainActor (String) -> Void)?
    var onSearchResults: (@MainActor ([MKLocalSearchCompletion]) -> Void)?
    var onSearchError: (@MainActor (String) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    func search(_ query: String) {
        searchCompleter.queryFragment = query
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.onLocationUpdate?(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.onLocationError?("Could not get your current location. Check Location Services and try again.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor [weak self] in
            self?.onSearchResults?(results)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.onSearchError?("Location search is unavailable right now. Please try again.")
        }
    }
}
