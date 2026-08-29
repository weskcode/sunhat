//
//  LocationPermissionView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation
import SwiftData

struct LocationPermissionView: View {
    @ObservedObject private var locationManager = LocationPermissionManager.shared
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showManualEntry = false
    @State private var isProcessingPermission = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                progressIndicator
                locationIntro
                privacySummary
                actions
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showManualEntry) {
            ManualLocationEntryView(
                isPresented: $showManualEntry,
                onLocationSelected: { location in
                    locationManager.manualLocation = location
                    saveManualLocationToPreferences(location)
                    coordinator.nextStep()
                }
            )
        }
        .sensoryFeedback(.success, trigger: locationManager.authorizationStatus) { _, newValue in
            newValue == .authorizedWhenInUse || newValue == .authorizedAlways
        }
        .alert("Location Access", isPresented: $locationManager.showPermissionDeniedAlert) {
            Button("Open Settings") {
                locationManager.openAppSettings()
            }
            Button("Enter City Manually") {
                showManualEntry = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow location access in Settings for local forecasts, or enter a city manually.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Location setup")
        .accessibilityHint("Step 2 of 4")
    }

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            ProgressView(value: 2, total: 4)
                .frame(maxWidth: 160)

            Text("Step 2 of 4")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress, step 2 of 4")
    }

    private var locationIntro: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Choose where SunHat checks the weather")
                .font(dynamicTypeSize.isAccessibilitySize ? .title2 : .title)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Use your current location for local forecasts, or enter a city manually.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
    }

    private var privacySummary: some View {
        Label {
            Text("Your saved location stays on this device. Coordinates are sent only to enabled weather providers when fetching a forecast.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 16) {
            Button(action: requestLocationPermission) {
                HStack(spacing: 10) {
                    if isProcessingPermission {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isProcessingPermission ? "Requesting Location" : "Use Current Location")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.accentColor)
            .disabled(isProcessingPermission)

            Button("Enter City Manually", systemImage: "magnifyingglass") {
                showManualEntry = true
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    private func requestLocationPermission() {
        guard !isProcessingPermission else { return }
        isProcessingPermission = true

        locationManager.requestLocationPermission { granted in
            Task { @MainActor in
                isProcessingPermission = false
                if granted {
                    saveGPSLocationToPreferences()
                    coordinator.nextStep()
                }
            }
        }
    }

    private func saveGPSLocationToPreferences() {
        let preferences = fetchOrCreatePreferences()
        preferences.locationMode = "gps"
        preferences.manualLocationLatitude = 0
        preferences.manualLocationLongitude = 0
        preferences.manualLocationName = ""
        preferences.updateTimestamp()
        try? modelContext.save()
    }

    private func saveManualLocationToPreferences(_ location: ManualLocationData) {
        let preferences = fetchOrCreatePreferences()
        preferences.locationMode = "manual"
        preferences.manualLocationLatitude = location.coordinate.latitude
        preferences.manualLocationLongitude = location.coordinate.longitude
        preferences.manualLocationName = location.displayName
        preferences.updateTimestamp()
        try? modelContext.save()
    }

    private func fetchOrCreatePreferences() -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let preferences = UserPreferences()
        modelContext.insert(preferences)
        return preferences
    }
}

#Preview {
    LocationPermissionView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: UserPreferences.self, inMemory: true)
}
