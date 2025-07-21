//
//  LocationManagementComponents.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Saved Location Card

struct SavedLocationCard: View {
    let location: SavedLocation
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Location icon with source indicator
            ZStack {
                Circle()
                    .fill(sourceColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: location.source.icon)
                    .font(.body)
                    .foregroundColor(sourceColor)
            }
            
            // Location details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(location.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if location.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text(location.shortAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label("Used \(location.useCount) times", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Label(location.lastUsed.formatted(.relative(presentation: .named)), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions button
            Button(action: {
                showingActions = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
        .confirmationDialog("Location Actions", isPresented: $showingActions) {
            Button(location.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite()
            }
            
            Button("Rename") {
                onEdit()
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var sourceColor: Color {
        switch location.source {
        case .gps:
            return .blue
        case .manual:
            return .purple
        case .search:
            return .green
        case .imported:
            return .orange
        }
    }
}

// MARK: - Location History Row

struct LocationHistoryRow: View {
    let historyItem: LocationHistory
    
    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            Image(systemName: historyItem.source.icon)
                .font(.caption)
                .foregroundColor(sourceColor)
                .frame(width: 20, height: 20)
            
            // Location name
            Text(historyItem.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Time ago
            Text(historyItem.timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private var sourceColor: Color {
        switch historyItem.source {
        case .gps:
            return .blue
        case .manual:
            return .purple
        case .search:
            return .green
        case .imported:
            return .orange
        }
    }
}

// MARK: - Privacy Info Row

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.purple)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            if let actionTitle = actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Add Location Sheet

struct AddLocationSheet: View {
    @ObservedObject var viewModel: LocationManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a location", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                        .onSubmit {
                            // Handle search submission
                        }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                
                // Search results
                if viewModel.isSearching {
                    VStack(spacing: 16) {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if !viewModel.searchResults.isEmpty {
                    List {
                        ForEach(viewModel.searchResults, id: \.self) { result in
                            SearchResultRow(result: result) {
                                viewModel.resolveSearchResult(result)
                                dismiss()
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("Search for locations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Enter a city name, address, or point of interest to add it to your saved locations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
                viewModel.searchText = searchText
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: MKLocalSearchCompletion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Privacy Info Sheet

struct PrivacyInfoSheet: View {
    let explanation: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(explanation)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(20)
            }
            .navigationTitle("Privacy Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Location Map View

struct LocationMapView: View {
    @ObservedObject var viewModel: LocationManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    VStack {
                        Image(systemName: annotation.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(annotation.color)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        
                        Text(annotation.title)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .navigationTitle("Locations Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupMapRegion()
            }
        }
    }
    
    private var mapAnnotations: [CustomMapAnnotation] {
        var annotations: [CustomMapAnnotation] = []
        
        // Add current location
        if let currentLocation = viewModel.currentLocation {
            annotations.append(CustomMapAnnotation(
                coordinate: currentLocation.coordinate,
                title: "Current",
                icon: "location.fill",
                color: .blue
            ))
        }
        
        // Add saved locations
        for location in viewModel.savedLocations {
            annotations.append(CustomMapAnnotation(
                coordinate: location.coordinate,
                title: location.displayName,
                icon: location.isFavorite ? "heart.fill" : "bookmark.fill",
                color: location.isFavorite ? .red : .green
            ))
        }
        
        return annotations
    }
    
    private func setupMapRegion() {
        // Calculate region to show all locations
        var coordinates: [CLLocationCoordinate2D] = []
        
        if let currentLocation = viewModel.currentLocation {
            coordinates.append(currentLocation.coordinate)
        }
        
        coordinates.append(contentsOf: viewModel.savedLocations.map { $0.coordinate })
        
        if !coordinates.isEmpty {
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
                longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
            )
            
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

struct CustomMapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let icon: String
    let color: Color
}