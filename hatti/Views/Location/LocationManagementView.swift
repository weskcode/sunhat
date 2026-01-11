//
//  LocationManagementView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct LocationManagementView: View {
    @StateObject private var viewModel = LocationManagementViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAddLocationSheet = false
    @State private var showingManualEntrySheet = false
    @State private var showingMapView = false
    @State private var showingPrivacyInfo = false
    @State private var editingLocation: SavedLocation?
    @State private var newLocationName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Location Section
                        currentLocationSection
                        
                        // Location Permission Status
                        permissionStatusSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Saved Locations
                        savedLocationsSection
                        
                        // Location History
                        locationHistorySection
                        
                        // Privacy Information
                        privacySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Location Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Location", systemImage: "plus") {
                            showingAddLocationSheet = true
                        }
                        
                        Button("View on Map", systemImage: "map") {
                            showingMapView = true
                        }
                        
                        Button("Privacy Info", systemImage: "hand.raised") {
                            showingPrivacyInfo = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                AddLocationSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingManualEntrySheet) {
                ManualLocationEntrySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingMapView) {
                LocationMapView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingPrivacyInfo) {
                PrivacyInfoSheet(explanation: viewModel.privacyExplanation)
            }
            .alert("Location Permission", isPresented: $viewModel.showingPermissionAlert) {
                if viewModel.locationError == .permissionDenied {
                    Button("Settings") {
                        viewModel.openAppSettings()
                    }
                    Button("Cancel", role: .cancel) { }
                } else {
                    Button("OK", role: .cancel) { }
                }
            } message: {
                if let error = viewModel.locationError {
                    Text(error.recoverySuggestion ?? error.localizedDescription)
                } else {
                    Text("Location access is required for accurate weather data.")
                }
            }
            .alert("Delete Location", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let location = viewModel.locationToDelete {
                        viewModel.deleteSavedLocation(location)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this saved location?")
            }
            .alert("Rename Location", isPresented: .constant(editingLocation != nil)) {
                TextField("Location Name", text: $newLocationName)
                Button("Save") {
                    if let location = editingLocation {
                        viewModel.updateLocationName(location, newName: newLocationName)
                        editingLocation = nil
                        newLocationName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    editingLocation = nil
                    newLocationName = ""
                }
            } message: {
                Text("Enter a custom name for this location")
            }
        }
    }
    
    // MARK: - Current Location Section
    
    private var currentLocationSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Current Location",
                subtitle: "Your device's current position",
                icon: "location.fill",
                iconColor: .blue
            )
            
            VStack(spacing: 12) {
                // Location display
                HStack(spacing: 16) {
                    // Location icon with accuracy indicator
                    ZStack {
                        Circle()
                            .fill(locationAccuracyColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(locationAccuracyColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentLocationName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text("Accuracy: \(viewModel.currentLocationAccuracy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.isLoadingCurrentLocation {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Update") {
                            viewModel.getCurrentLocation()
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.authorizationStatus != .authorizedWhenInUse && 
                                 viewModel.authorizationStatus != .authorizedAlways)
                    }
                }
                
                // Coordinates display
                if let location = viewModel.currentLocation {
                    HStack {
                        Text("Coordinates:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
    
    // MARK: - Permission Status Section
    
    private var permissionStatusSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Location Permission",
                subtitle: "Manage location access settings",
                icon: "lock.shield",
                iconColor: permissionStatusColor
            )
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: permissionStatusIcon)
                        .font(.title2)
                        .foregroundColor(permissionStatusColor)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(permissionStatusText)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(permissionStatusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.authorizationStatus == .notDetermined || 
                       viewModel.authorizationStatus == .denied {
                        Button(viewModel.authorizationStatus == .denied ? "Settings" : "Allow") {
                            if viewModel.authorizationStatus == .denied {
                                viewModel.openAppSettings()
                            } else {
                                viewModel.requestLocationPermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Quick Actions",
                subtitle: "Common location tasks",
                icon: "bolt.fill",
                iconColor: .orange
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Add Location",
                    subtitle: "Search & save",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    showingAddLocationSheet = true
                }
                
                QuickActionCard(
                    title: "View Map",
                    subtitle: "See all locations",
                    icon: "map.fill",
                    color: .blue
                ) {
                    showingMapView = true
                }
                
                QuickActionCard(
                    title: "Manual Entry",
                    subtitle: "Enter coordinates",
                    icon: "pencil.circle.fill",
                    color: .purple
                ) {
                    showingManualEntrySheet = true
                }
                
                QuickActionCard(
                    title: "Current Location",
                    subtitle: "Save current",
                    icon: "location.circle.fill",
                    color: .red
                ) {
                    saveCurrentLocation()
                }
            }
        }
    }
    
    // MARK: - Saved Locations Section
    
    private var savedLocationsSection: some View {
        VStack(spacing: 16) {
            HStack {
                SectionHeader(
                    title: "Saved Locations",
                    subtitle: "\(viewModel.savedLocations.count) locations",
                    icon: "bookmark.fill",
                    iconColor: .green
                )
                
                Spacer()
                
                if !viewModel.savedLocations.isEmpty {
                    Button("Add") {
                        showingAddLocationSheet = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            
            if viewModel.savedLocations.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    title: "No Saved Locations",
                    subtitle: "Add locations to quickly access weather data for specific places",
                    actionTitle: "Add Location"
                ) {
                    showingAddLocationSheet = true
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.savedLocations, id: \.id) { location in
                        SavedLocationCard(location: location) {
                            // Edit action
                            editingLocation = location
                            newLocationName = location.customName ?? location.name
                        } onDelete: {
                            // Delete action
                            viewModel.locationToDelete = location
                            viewModel.showingDeleteConfirmation = true
                        } onToggleFavorite: {
                            // Toggle favorite
                            viewModel.toggleFavorite(location)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Location History Section
    
    private var locationHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                SectionHeader(
                    title: "Recent Locations",
                    subtitle: "Last 10 accessed locations",
                    icon: "clock.fill",
                    iconColor: .orange
                )
                
                Spacer()
                
                if !viewModel.locationHistory.isEmpty {
                    Button("Clear") {
                        viewModel.clearLocationHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            if viewModel.locationHistory.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No Location History",
                    subtitle: "Your recently accessed locations will appear here",
                    actionTitle: nil
                ) { }
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.locationHistory, id: \.id) { historyItem in
                        LocationHistoryRow(historyItem: historyItem)
                    }
                }
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Privacy & Data",
                subtitle: "How we handle your location data",
                icon: "hand.raised.fill",
                iconColor: .purple
            )
            
            VStack(spacing: 12) {
                PrivacyInfoRow(
                    icon: "shield.fill",
                    title: "Data Protection",
                    description: "Location data stays on your device and in your iCloud"
                )
                
                PrivacyInfoRow(
                    icon: "eye.slash.fill",
                    title: "No Tracking",
                    description: "We never share your location with third parties"
                )
                
                PrivacyInfoRow(
                    icon: "trash.fill",
                    title: "Full Control",
                    description: "Delete saved locations and history anytime"
                )
                
                Button("View Full Privacy Policy") {
                    showingPrivacyInfo = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 8)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveCurrentLocation() {
        guard let currentLocation = viewModel.currentLocation else {
            viewModel.getCurrentLocation()
            return
        }
        
        let savedLocation = SavedLocation(
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude,
            name: viewModel.currentLocationName,
            source: .gps
        )
        
        viewModel.addSavedLocation(savedLocation)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.05),
                Color.black
            ] : [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.93, green: 0.96, blue: 1.0),
                Color(red: 0.97, green: 0.98, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var locationAccuracyColor: Color {
        guard let location = viewModel.currentLocation else { return .gray }
        
        let accuracy = location.horizontalAccuracy
        if accuracy < 0 { return .red }
        if accuracy < 5 { return .green }
        if accuracy < 20 { return .blue }
        if accuracy < 100 { return .orange }
        return .red
    }
    
    private var permissionStatusColor: Color {
        switch viewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var permissionStatusIcon: String {
        switch viewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "checkmark.shield.fill"
        case .denied, .restricted:
            return "xmark.shield.fill"
        case .notDetermined:
            return "questionmark.shield.fill"
        @unknown default:
            return "shield.fill"
        }
    }
    
    private var permissionStatusText: String {
        switch viewModel.authorizationStatus {
        case .authorizedWhenInUse:
            return "Authorized (When In Use)"
        case .authorizedAlways:
            return "Authorized (Always)"
        case .denied:
            return "Access Denied"
        case .restricted:
            return "Access Restricted"
        case .notDetermined:
            return "Permission Needed"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    private var permissionStatusDescription: String {
        switch viewModel.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Location access is enabled for weather data"
        case .denied:
            return "Enable in Settings to get location-based weather"
        case .restricted:
            return "Location access is restricted by device settings"
        case .notDetermined:
            return "Grant permission to access your location"
        @unknown default:
            return "Unable to determine location permission status"
        }
    }
}

// MARK: - Preview

#Preview {
    LocationManagementView()
        .modelContainer(for: [
            SavedLocation.self,
            LocationHistory.self
        ], inMemory: true)
}