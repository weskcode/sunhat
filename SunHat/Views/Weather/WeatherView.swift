//
//  WeatherView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct WeatherView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var viewModel = WeatherViewModel()
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var selectedTimeframe: WeatherTimeframe = .current
    @State private var activeSheet: ActiveSheet?
    @State private var selectedLocation: ReminderLocation = .currentLocation

    private enum ActiveSheet: Identifiable {
        case locationPicker

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                RefreshableScrollView {
                    await viewModel.refresh()
                } content: {
                    LazyVStack(spacing: 20) {
                        if viewModel.hasWeatherData {
                            // Weather timeframe picker
                            weatherTimeframePicker
                                .padding(.top, 8)

                            // Current conditions section
                            if selectedTimeframe == .current {
                                currentConditionsSection
                            }

                            // Hourly forecast section (24 hours)
                            if selectedTimeframe == .hourly {
                                hourlyForecastSection
                            }

                            // 7-day forecast section
                            if selectedTimeframe == .weekly {
                                weeklyForecastSection
                            }

                            // Weather alerts section
                            if !viewModel.weatherAlerts.isEmpty {
                                weatherAlertsSection
                            }

                            if selectedTimeframe == .current {
                                additionalMetricsSection

                                if hasHistoricalComparison {
                                    historicalComparisonSection
                                }

                                if !viewModel.triggerPredictions.isEmpty {
                                    triggerPredictionsSection
                                }
                            }
                        } else if viewModel.isLoading {
                            ProgressView(String(localized: "Loading weather...", comment: "Progress label while the weather tab loads"))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 120)
                        } else {
                            weatherUnavailableSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Location", systemImage: "location") {
                        activeSheet = .locationPicker
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .locationPicker:
                    LocationPickerView(selectedLocation: $selectedLocation)
                }
            }
            .task {
                viewModel.configure(modelContainer: modelContext.container)
            }
            .onChange(of: selectedLocation.id) {
                Task {
                    await viewModel.updateSelectedLocation(selectedLocation)
                }
            }
        }
    }

    // MARK: - Unavailable State

    /// Shown instead of weather content when a load failed or no location is
    /// available. Placeholder zeros are never rendered as real measurements.
    private var weatherUnavailableSection: some View {
        ContentUnavailableView {
            Label(String(localized: "Weather Unavailable", comment: "Title of the weather tab's unavailable state"), systemImage: "cloud.slash")
        } description: {
            Text("SunHat couldn't load weather for this location. Check your connection and location settings, then try again.", comment: "Description of the weather tab's unavailable state")
        } actions: {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Try Again", comment: "Retry button in the weather tab's unavailable state")
            }
            .buttonStyle(.glass)
        }
        .padding(.top, 60)
    }

    // MARK: - Weather Timeframe Picker

    private var weatherTimeframePicker: some View {
        Picker("Weather Timeframe", selection: $selectedTimeframe) {
            Text("Now").tag(WeatherTimeframe.current)
            Text("24 Hours").tag(WeatherTimeframe.hourly)
            Text("7 Days").tag(WeatherTimeframe.weekly)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // MARK: - Helper Views

    /// Shared section header used by both CurrentConditionsSection.swift and
    /// ForecastAndAlertsSections.swift, so it stays internal rather than
    /// private to this file.
    func sectionHeader(title: String, icon: String, color: Color = .primary) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Computed Properties

    private var backgroundGradient: some View {
        Color(.systemBackground)
    }
}

// MARK: - Weather Timeframe Enum

enum WeatherTimeframe: CaseIterable {
    case current
    case hourly
    case weekly
}

// MARK: - Preview

#Preview {
    WeatherView()
        .modelContainer(for: [
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            UserPreferences.self,
            LocationData.self
        ], inMemory: true)
}
