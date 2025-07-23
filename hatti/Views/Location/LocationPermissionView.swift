//
//  LocationPermissionView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    @StateObject private var locationManager = LocationPermissionManager()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.colorScheme) private var colorScheme
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
            Text("To provide accurate weather reminders, hatti needs access to your location. You can enable this in Settings or enter your city manually.")
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
                            .easeOut(duration: 1.0 + Double(index) * 0.2).delay(0.3 + Double(index) * 0.2),
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
                        .foregroundColor(.white)
                }
                .scaleEffect(showLocationVisual ? 1.0 : 0.5)
                .opacity(showLocationVisual ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.1), value: showLocationVisual)
            }
            .accessibilityHidden(true)
            
            // Title
            VStack(spacing: 12) {
                Text("Get Accurate Weather")
                    .font(.custom("SF Pro Display", size: dynamicTypeSize.isAccessibilitySize ? 28 : 34, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("For Your Exact Location")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            }
            .opacity(showExplanation ? 1.0 : 0.0)
            .offset(y: showExplanation ? 0 : 20)
            .animation(.easeOut(duration: 0.8).delay(0.8), value: showExplanation)
        }
    }
    
    // MARK: - Location Visual Section
    
    private var locationVisualSection: some View {
        VStack(spacing: 24) {
            Text("Weather varies by location")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .opacity(showLocationVisual ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(1.2), value: showLocationVisual)
            
            HStack(spacing: 16) {
                // Location 1: Sunny
                LocationWeatherCard(
                    cityName: "San Francisco",
                    temperature: 72,
                    condition: .clear,
                    iconName: "sun.max.fill",
                    iconColor: .orange,
                    animationDelay: 1.4
                )
                
                // Location 2: Rainy
                LocationWeatherCard(
                    cityName: "Seattle",
                    temperature: 58,
                    condition: .rain,
                    iconName: "cloud.rain.fill",
                    iconColor: .blue,
                    animationDelay: 1.6
                )
                
                // Location 3: Snowy
                LocationWeatherCard(
                    cityName: "Denver",
                    temperature: 35,
                    condition: .snow,
                    iconName: "cloud.snow.fill",
                    iconColor: .gray,
                    animationDelay: 1.8
                )
            }
            .opacity(showLocationVisual ? 1.0 : 0.0)
            .offset(y: showLocationVisual ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(1.4), value: showLocationVisual)
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
                    animationDelay: 2.0
                )
                
                ExplanationCard(
                    icon: "bell.fill",
                    title: "Smart Notifications",
                    description: "Receive reminders exactly when conditions are right for your outdoor activities.",
                    color: .green,
                    animationDelay: 2.2
                )
                
                ExplanationCard(
                    icon: "lock.shield.fill",
                    title: "Privacy Protected",
                    description: "Your location stays on your device. We only fetch weather data when needed.",
                    color: .purple,
                    animationDelay: 2.4
                )
            }
            .opacity(showExplanation ? 1.0 : 0.0)
            .offset(y: showExplanation ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(2.0), value: showExplanation)
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
                .foregroundColor(.white)
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
                .foregroundColor(.blue)
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
        .animation(.easeOut(duration: 0.8).delay(2.6), value: showButtons)
    }
    
    private var privacyNotice: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Your privacy matters")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text("Location data is only used for weather updates and never shared with third parties.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy notice: Your privacy matters. Location data is only used for weather updates and never shared with third parties.")
    }
    
    // MARK: - Helper Methods
    
    private func startAnimationSequence() {
        guard !reduceMotion else {
            // Show all content immediately for reduced motion
            showLocationVisual = true
            showExplanation = true
            showButtons = true
            return
        }
        
        withAnimation {
            showLocationVisual = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showExplanation = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation {
                showButtons = true
            }
        }
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
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Temperature
            Text("\(temperature)°")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
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
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
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
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
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