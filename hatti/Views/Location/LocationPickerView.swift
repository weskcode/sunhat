//
//  LocationPickerView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import SwiftData

struct LocationPickerView: View {
    @Binding var selectedLocation: ReminderLocation
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search locations", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            viewModel.searchLocations(searchText)
                        }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                if viewModel.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                // Current location option
                Button(action: {
                    selectCurrentLocation()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Use device location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedLocation.isCurrentLocation {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Search results
                List {
                    ForEach(viewModel.searchResults, id: \.self) { result in
                        LocationResultRow(result: result) {
                            selectLocation(result)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let location = viewModel.currentLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                viewModel.searchLocations(newValue)
            } else {
                viewModel.clearResults()
            }
        }
    }
    
    private func selectCurrentLocation() {
        selectedLocation = ReminderLocation.currentLocation
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        viewModel.resolveLocation(result) { location in
            selectedLocation = location
        }
    }
}

struct LocationResultRow: View {
    let result: MKLocalSearchCompletion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle")
                    .font(.title3)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@MainActor
final class LocationPickerViewModel: NSObject, ObservableObject {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var currentLocation: CLLocation?
    
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
    
    func resolveLocation(_ completion: MKLocalSearchCompletion, result: @escaping (ReminderLocation) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            DispatchQueue.main.async {
                if let mapItem = response?.mapItems.first {
                    let location = ReminderLocation(
                        coordinate: mapItem.placemark.coordinate,
                        displayName: completion.title,
                        fullAddress: completion.subtitle,
                        isCurrentLocation: false
                    )
                    result(location)
                }
            }
        }
    }
}

extension LocationPickerViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
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
        print("Search error: \(error.localizedDescription)")
        Task { @MainActor in
            isSearching = false
        }
    }
}

#Preview {
    LocationPickerView(selectedLocation: .constant(.currentLocation))
}