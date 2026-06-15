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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var showLocationVisual = false
    @State private var showExplanation = false
    @State private var showButtons = false
    @State private var showManualEntry = false
    @State private var isProcessingPermission = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header section
                        headerSection
                            .padding(.top, geometry.safeAreaInsets.top + 20)
                        
                        // Location visual
                        locationVisualSection
                            .padding(.top, 40)
                        
                        // Explanation section
                        explanationSection
                            .padding(.top, 40)
                        
                        // Action buttons
                        actionButtonsSection
                            .padding(.top, 50)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 40))
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                
                // Manual city entry overlay
                if showManualEntry {
                    ManualLocationEntryView(
                        isPresented: $showManualEntry,
                        onLocationSelected: { location in
                            locationManager.manualLocation = location
                            saveManualLocationToPreferences(location)
                            coordinator.nextStep()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .onChange(of: locationManager.authorizationStatus) { oldStatus, newStatus in
            handleLocationStatusChange(newStatus)
        }
        .alert("Location Access", isPresented: $locationManager.showPermissionDeniedAlert) {
            Button("Settings") {
                locationManager.openAppSettings()
            }
            Button("Enter Manually") {
                showManualEntry = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To provide accurate weather reminders, SunHat needs access to your location. You can enable this in Settings or enter your city manually.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Location permission request")
        .accessibilityHint("Explains why location access is needed for accurate weather data")
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Location icon with animated rings
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.clear],
                                startPoint: .center,
                                endPoint: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100 + CGFloat(index * 30), height: 100 + CGFloat(index * 30))
                        .scaleEffect(showLocationVisual ? 1.0 : 0.3)
                        .opacity(showLocationVisual ? 0.6 : 0.0)
                        .animation(
                            .easeOut(duration: 0.5 + Double(index) * 0.1).delay(0.1 + Double(index) * 0.1),
                            value: showLocationVisual
                        )
                }
                
                // Main location icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 5)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 35, weight: .medium))
                        .foregroundStyle(.white)
                }
                .scaleEffect(showLocationVisual ? 1.0 : 0.5)
                .opacity(showLocationVisual ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.05), value: showLocationVisual)
            }
            .accessibilityHidden(true)
            
            // Title
            VStack(spacing: 12) {
                Text("Get Accurate Weather")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("For Your Exact Location")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
            }
            .opacity(showExplanation ? 1.0 : 0.0)
            .offset(y: showExplanation ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.15), value: showExplanation)
        }
    }
    
    // MARK: - Location Visual Section
    
    private var locationVisualSection: some View {
        VStack(spacing: 24) {
            Text("Weather varies by location")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .opacity(showLocationVisual ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.35).delay(0.25), value: showLocationVisual)
            
            HStack(spacing: 16) {
                // Location 1: Sunny
                LocationWeatherCard(
                    cityName: "San Francisco",
                    temperature: 72,
                    condition: .clear,
                    iconName: "sun.max.fill",
                    iconColor: .orange,
                    animationDelay: 0.3
                )
                
                // Location 2: Rainy
                LocationWeatherCard(
                    cityName: "Seattle",
                    temperature: 58,
                    condition: .rain,
                    iconName: "cloud.rain.fill",
                    iconColor: .blue,
                    animationDelay: 0.4
                )
                
                // Location 3: Snowy
                LocationWeatherCard(
                    cityName: "Denver",
                    temperature: 35,
                    condition: .snow,
                    iconName: "cloud.snow.fill",
                    iconColor: .gray,
                    animationDelay: 0.5
                )
            }
            .opacity(showLocationVisual ? 1.0 : 0.0)
            .offset(y: showLocationVisual ? 0 : 30)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: showLocationVisual)
        }
    }
    
    // MARK: - Explanation Section
    
    private var explanationSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ExplanationCard(
                    icon: "target",
                    title: "Precise Weather Data",
                    description: "Get hyper-local weather conditions specific to your neighborhood, not just your city.",
                    color: .blue,
                    animationDelay: 0.4
                )
                
                ExplanationCard(
                    icon: "bell.fill",
                    title: "Smart Notifications",
                    description: "Receive reminders exactly when conditions are right for your outdoor activities.",
                    color: .green,
                    animationDelay: 0.5
                )
            }
            .opacity(showExplanation ? 1.0 : 0.0)
            .offset(y: showExplanation ? 0 : 30)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: showExplanation)
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary button - Allow Location Access
            Button(action: {
                requestLocationPermission()
            }) {
                HStack(spacing: 12) {
                    if isProcessingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "location.fill")
                            .font(.title3)
                    }
                    
                    Text(isProcessingPermission ? "Requesting..." : "Allow Location Access")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: isProcessingPermission ? 
                            [Color.gray, Color.gray.opacity(0.8)] :
                            [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isProcessingPermission)
            .accessibilityLabel("Allow location access")
            .accessibilityHint("Grants permission to access your location for accurate weather data")
            
            // Secondary button - Enter City Manually
            Button(action: {
                showManualEntry = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                    Text("Enter City Manually")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Enter city manually")
            .accessibilityHint("Search for and select your city instead of using automatic location")
            
            // Privacy notice
            privacyNotice
        }
        .opacity(showButtons ? 1.0 : 0.0)
        .offset(y: showButtons ? 0 : 30)
        .animation(.easeOut(duration: 0.4).delay(0.5), value: showButtons)
    }
    
    private var privacyNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.subheadline)
                .foregroundStyle(.green)

            Text("Only **you** have your location data — it's used solely for accurate weather, nothing else.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy notice: Only you have your location data. It's used solely for accurate weather, nothing else.")
    }
    
    // MARK: - Helper Methods
    
    private func startAnimationSequence() {
        showLocationVisual = true
        showExplanation = true
        showButtons = true
    }
    
    private func requestLocationPermission() {
        guard !isProcessingPermission else { return }
        
        isProcessingPermission = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        locationManager.requestLocationPermission { granted in
            DispatchQueue.main.async {
                isProcessingPermission = false
                
                if granted {
                    // Save GPS mode to UserPreferences
                    saveGPSLocationToPreferences()

                    // Success haptic
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // Proceed to next step
                    coordinator.nextStep()
                }
                // Error handling is done through the location manager's alert
            }
        }
    }

    private func saveGPSLocationToPreferences() {
        let prefs = fetchOrCreatePreferences()
        prefs.locationMode = "gps"
        prefs.manualLocationLatitude = 0
        prefs.manualLocationLongitude = 0
        prefs.manualLocationName = ""
        prefs.updateTimestamp()
        try? modelContext.save()
    }

    private func saveManualLocationToPreferences(_ location: ManualLocationData) {
        let prefs = fetchOrCreatePreferences()
        prefs.locationMode = "manual"
        prefs.manualLocationLatitude = location.coordinate.latitude
        prefs.manualLocationLongitude = location.coordinate.longitude
        prefs.manualLocationName = location.displayName
        prefs.updateTimestamp()
        try? modelContext.save()
    }

    private func fetchOrCreatePreferences() -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let newPrefs = UserPreferences()
        modelContext.insert(newPrefs)
        return newPrefs
    }
    
    private func handleLocationStatusChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            coordinator.nextStep()
        case .denied, .restricted:
            // Location manager will show appropriate alert
            break
        case .notDetermined:
            // Initial state, no action needed
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: some View {
        Color(.systemBackground)
    }
}

// MARK: - Supporting Views

struct LocationWeatherCard: View {
    let cityName: String
    let temperature: Int
    let condition: WeatherCondition
    let iconName: String
    let iconColor: Color
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 12) {
            // Weather icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // City name
            Text(cityName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            // Temperature
            Text("\(temperature)°")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.4).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cityName), \(temperature) degrees, \(condition.rawValue)")
    }
}

struct ExplanationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(x: isVisible ? 0 : -30)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.4).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Preview

#Preview {
    LocationPermissionView()
        .environmentObject(OnboardingCoordinator())
}

#Preview("Dark Mode") {
    LocationPermissionView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}
