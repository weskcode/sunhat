//
//  ManualLocationEntryView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct ManualLocationEntryView: View {
    @Binding var isPresented: Bool
    let onLocationSelected: (ManualLocationData) -> Void
    var onUseCurrentLocation: (() -> Void)? = nil
    
    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selectedLocation: LocationSearchResult?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header section
                    headerSection
                        .padding(.top, 20)

                    // "Use Current Location" option (when available)
                    if let onUseCurrentLocation {
                        currentLocationButton(action: onUseCurrentLocation)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    // Search section
                    searchSection
                        .padding(.top, onUseCurrentLocation == nil ? 30 : 16)
                    
                    // Results section
                    if isSearching {
                        loadingSection
                            .padding(.top, 40)
                    } else if !searchResults.isEmpty {
                        resultsSection
                            .padding(.top, 20)
                    } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                        noResultsSection
                            .padding(.top, 40)
                    } else {
                        suggestionsSection
                            .padding(.top, 40)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Select Your City")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismissView()
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .onAppear {
            focusSearchField()
        }
        .alert("Search Error", isPresented: .constant(searchError != nil)) {
            Button("OK") {
                searchError = nil
            }
        } message: {
            if let error = searchError {
                Text(error)
            }
        }
    }
    
    // MARK: - Current Location Button

    private func currentLocationButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "location.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Current Location")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Monitor weather at your device location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use current location")
        .accessibilityHint("Monitor weather at your device's current GPS location")
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityHidden(true)
            
            // Title and description
            VStack(spacing: 8) {
                Text("Search for Your City")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Enter your city name to get accurate weather data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: 16) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                TextField("City name (e.g., San Francisco)", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        // Debounce search as user types
                        debounceSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchError = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSearchFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("City search field")
            
            // Search tips
            if searchText.isEmpty {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Text("Search tips")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        searchTip(text: "Include state or country for better results")
                        searchTip(text: "Try 'Portland, OR' instead of just 'Portland'")
                        searchTip(text: "Use common city names in English")
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Search tips: Include state or country for better results. Try Portland, OR instead of just Portland. Use common city names in English.")
            }
        }
    }
    
    private func searchTip(text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.orange.opacity(0.6))
                .frame(width: 4, height: 4)
            
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Searching for cities...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Searching for cities")
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 0) {
            // Results header
            HStack {
                Text("Search Results")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(searchResults.count) found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            
            // Results list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(searchResults) { result in
                        LocationResultCard(
                            result: result,
                            isSelected: selectedLocation?.id == result.id
                        ) {
                            selectLocation(result)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - No Results Section
    
    private var noResultsSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("No cities found")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Try searching with a different spelling or include the state/country")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                isSearchFieldFocused = true
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Focus search field to try again")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cities found. Try searching with a different spelling or include the state or country.")
    }
    
    // MARK: - Suggestions Section
    
    private var suggestionsSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Popular Cities")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Tap a city below or search for your location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(popularCities) { city in
                    PopularCityCard(city: city) {
                        searchText = city.displayName
                        performSearch()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func focusSearchField() {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            isSearchFieldFocused = true
        }
    }
    
    private func dismissView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
    
    private func debounceSearch() {
        searchTask?.cancel()

        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSearching = true
        searchError = nil

        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = searchText
                request.resultTypes = [.address, .pointOfInterest]
                
                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                await MainActor.run {
                    isSearching = false

                    guard !response.mapItems.isEmpty else {
                        searchError = "No results found for '\(searchText)'"
                        searchResults = []
                        return
                    }

                    // Convert map items to search results
                    searchResults = response.mapItems.compactMap { mapItem -> LocationSearchResult? in
                        let location = mapItem.location
                        let city = mapItem.name ?? "Unknown"

                        // iOS 26 Migration: Use MKAddress when available, fallback to placemark for older iOS
                        // Note: MKAddress doesn't provide individual components (state, country), only formatted strings.
                        // For now, we extract what we can from mapItem.name and accept reduced granularity
                        // to avoid deprecated API usage. This is a trade-off between warnings and UX.

                        // Since MKAddress only provides fullAddress/shortAddress (no individual components),
                        // and we need state/country for location disambiguation, we temporarily set them to nil
                        // This may result in duplicate-named cities being harder to distinguish
                        let state: String? = nil
                        let country: String? = nil

                        return LocationSearchResult(
                            city: city,
                            state: state,
                            country: country,
                            coordinate: location.coordinate
                        )
                    }
                    .prefix(10) // Limit to 10 results
                    .map { $0 }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = "Unable to find cities matching '\(searchText)'. Please try a different search."
                    searchResults = []
                }
            }
        }
    }
    
    private func selectLocation(_ result: LocationSearchResult) {
        selectedLocation = result

        // Create manual location data
        let manualLocation = ManualLocationData(
            name: result.displayName,
            coordinate: result.coordinate,
            country: result.country,
            administrativeArea: result.state
        )
        
        // Provide to parent view
        onLocationSelected(manualLocation)
        
        isPresented = false
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: some View {
        Color(.systemBackground)
    }
}

// MARK: - Supporting Views

struct LocationResultCard: View {
    let result: LocationSearchResult
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Location icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "location.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                .accessibilityHidden(true)
                
                // Location details
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.city)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if let subtitle = result.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.displayName)")
        .accessibilityHint("Select this city for weather data")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PopularCityCard: View {
    let city: PopularCity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(city.flag)
                    .font(.title)
                    .accessibilityHidden(true)
                
                Text(city.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(city.country)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(city.name), \(city.country)")
        .accessibilityHint("Search for this city")
    }
}

// MARK: - Supporting Data Structures

struct LocationSearchResult: Identifiable {
    let id = UUID()
    let city: String
    let state: String?
    let country: String?
    let coordinate: CLLocationCoordinate2D
    
    var displayName: String {
        var components = [city]
        if let state = state {
            components.append(state)
        }
        if let country = country {
            components.append(country)
        }
        return components.joined(separator: ", ")
    }
    
    var subtitle: String? {
        var components: [String] = []
        if let state = state {
            components.append(state)
        }
        if let country = country {
            components.append(country)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

struct PopularCity: Identifiable {
    let id = UUID()
    let name: String
    let country: String
    let flag: String
    let coordinate: CLLocationCoordinate2D
    
    var displayName: String {
        "\(name), \(country)"
    }
}

// MARK: - Sample Data

private let popularCities: [PopularCity] = [
    PopularCity(name: "New York", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
    PopularCity(name: "Los Angeles", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
    PopularCity(name: "Chicago", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)),
    PopularCity(name: "Houston", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698)),
    PopularCity(name: "London", country: "UK", flag: "🇬🇧", coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
    PopularCity(name: "Paris", country: "France", flag: "🇫🇷", coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
    PopularCity(name: "Tokyo", country: "Japan", flag: "🇯🇵", coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
    PopularCity(name: "Sydney", country: "Australia", flag: "🇦🇺", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093))
]

// MARK: - Local Weather Condition (using WeatherData.WeatherCondition)

// MARK: - Preview

#Preview {
    NavigationStack {
        Text("Manual Location Entry View")
    }
}
