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
    @StateObject private var viewModel = WeatherViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    
    // MARK: - Current Conditions Section
    
    private var currentConditionsSection: some View {
        VStack(spacing: 16) {
            // Main current conditions card
            currentConditionsCard
            
            // Detailed metrics grid
            detailedCurrentMetricsGrid
        }
    }
    
    private var currentConditionsCard: some View {
        VStack(spacing: 16) {
            // Location and time header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(Color.accentColor)
                        
                        Text(viewModel.locationName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    
                    if let lastUpdate = viewModel.lastUpdateTime {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Main temperature and condition display
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    // Current temperature with large display
                    HStack(alignment: .top, spacing: 4) {
                        Text(viewModel.displayTemperature(viewModel.currentTemperature, fractionDigits: 1))
                            .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 68 : 80, weight: .ultraLight, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("°")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.primary)
                            .offset(y: 12)
                    }
                    
                    // Feels like temperature with visual distinction
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.orange)
                        
                        Text("Feels like \(viewModel.displayTemperature(viewModel.feelsLikeTemperature, fractionDigits: 1))°")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    
                    // Temperature difference indicator
                    let tempDifference = viewModel.feelsLikeTemperature - viewModel.currentTemperature
                    if abs(tempDifference) > 2 {
                        HStack(spacing: 6) {
                            Image(systemName: tempDifference > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                                .foregroundStyle(tempDifference > 0 ? .red : .blue)
                            
                            Text(tempDifference > 0 ?
                                String(localized: "\(viewModel.displayTemperatureDelta(abs(tempDifference)))° warmer", comment: "Feels-like temperature is warmer than the actual temperature") :
                                String(localized: "\(viewModel.displayTemperatureDelta(abs(tempDifference)))° cooler", comment: "Feels-like temperature is cooler than the actual temperature")
                            )
                                .font(AppFontStyle.caption.font)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 16) {
                    // Weather icon and condition
                    VStack(alignment: .trailing, spacing: 8) {
                        Image(systemName: viewModel.weatherIconName)
                            .font(.system(size: 56))
                            .foregroundStyle(viewModel.weatherIconColor)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text(viewModel.weatherDescription)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // High/Low temperatures
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text("\(viewModel.displayTemperature(viewModel.highTemperature))°")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text("\(viewModel.displayTemperature(viewModel.lowTemperature))°")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current weather: \(viewModel.displayTemperature(viewModel.currentTemperature, fractionDigits: 1)) degrees, feels like \(viewModel.displayTemperature(viewModel.feelsLikeTemperature, fractionDigits: 1)) degrees, \(viewModel.weatherDescription). High \(viewModel.displayTemperature(viewModel.highTemperature)), low \(viewModel.displayTemperature(viewModel.lowTemperature)) degrees"
        )
    }
    
    private var detailedCurrentMetricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            DetailedMetricCard(
                icon: "humidity.fill",
                title: "Humidity",
                value: "\(viewModel.humidity)%",
                description: humidityDescription,
                color: .cyan
            )
            
            DetailedMetricCard(
                icon: "wind",
                title: "Wind",
                value: viewModel.windSpeedDisplay,
                description: viewModel.windDetailDisplay,
                color: .green
            )

            DetailedMetricCard(
                icon: "eye.fill",
                title: "Visibility",
                value: viewModel.visibilityDisplay,
                description: visibilityDescription,
                color: .purple
            )

            DetailedMetricCard(
                icon: "barometer",
                title: "Pressure",
                value: viewModel.pressureDisplay,
                description: pressureDescription,
                color: .indigo
            )
            
            DetailedMetricCard(
                icon: "sun.max.fill",
                title: "UV Index",
                value: String(format: "%.0f", viewModel.uvIndex),
                description: uvIndexDescription,
                color: uvIndexColor
            )
            
            DetailedMetricCard(
                icon: "thermometer.snowflake",
                title: "Dew Point",
                value: "\(viewModel.displayTemperature(viewModel.dewPoint))°",
                description: dewPointDescription,
                color: .mint
            )
        }
    }
    
    // MARK: - Hourly Forecast Section
    
    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "24-Hour Forecast", icon: "clock.fill")

            if viewModel.hourlyForecast.isEmpty {
                Text("Hourly forecast is unavailable right now. Pull to refresh to try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.hourlyForecast, id: \.hour) { hourData in
                            HourlyForecastCard(hourData: hourData)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Weekly Forecast Section
    
    private var weeklyForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "7-Day Forecast", icon: "calendar")
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.weeklyForecast, id: \.date) { dayData in
                    WeeklyForecastRow(dayData: dayData)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Weather Alerts Section
    
    private var weatherAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "SunHat Advisories", icon: "exclamationmark.triangle.fill", color: .orange)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.weatherAlerts, id: \.id) { alert in
                    WeatherAlertDetailCard(alert: ModelDataConverter.createWeatherAlertDisplay(from: alert))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Additional Metrics Section
    
    private var additionalMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Air Quality & Sun", icon: "leaf.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AirQualityCard(
                    aqi: viewModel.airQualityIndex,
                    pm25: viewModel.pm25,
                    description: airQualityDescription
                )
                
                SunTimesCard(
                    sunrise: viewModel.sunrise,
                    sunset: viewModel.sunset,
                    dayLength: viewModel.dayLength
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Historical Comparison Section
    
    private var historicalComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Historical Comparison", icon: "chart.line.uptrend.xyaxis")
            
            VStack(spacing: 12) {
                if viewModel.yesterdayTemp == nil && viewModel.lastWeekTemp == nil && viewModel.historicalAvgTemp == nil {
                    Text("Not enough history yet. Comparisons appear once SunHat has stored weather for this location.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if let yesterdayTemp = viewModel.yesterdayTemp {
                        HistoricalComparisonRow(
                            title: "vs. Yesterday",
                            currentTemp: viewModel.convertedTemperature(viewModel.currentTemperature),
                            historicalTemp: viewModel.convertedTemperature(yesterdayTemp),
                            timeframe: "24h ago"
                        )
                    }

                    if let lastWeekTemp = viewModel.lastWeekTemp {
                        HistoricalComparisonRow(
                            title: "vs. Last Week",
                            currentTemp: viewModel.convertedTemperature(viewModel.currentTemperature),
                            historicalTemp: viewModel.convertedTemperature(lastWeekTemp),
                            timeframe: "7 days ago"
                        )
                    }

                    if let historicalAvgTemp = viewModel.historicalAvgTemp {
                        HistoricalComparisonRow(
                            title: "vs. Monthly Average",
                            currentTemp: viewModel.convertedTemperature(viewModel.currentTemperature),
                            historicalTemp: viewModel.convertedTemperature(historicalAvgTemp),
                            timeframe: "Stored average for this month"
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Trigger Predictions Section
    
    private var triggerPredictionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Reminder Triggers", icon: "bell.fill")
            
            if viewModel.triggerPredictions.isEmpty {
                EmptyTriggerPredictionsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.triggerPredictions, id: \.reminderId) { prediction in
                        TriggerPredictionCard(prediction: prediction)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color = .primary) -> some View {
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

    private var hasHistoricalComparison: Bool {
        viewModel.yesterdayTemp != nil ||
            viewModel.lastWeekTemp != nil ||
            viewModel.historicalAvgTemp != nil
    }
    
    private var humidityDescription: String {
        switch viewModel.humidity {
        case 0..<30: return String(localized: "Very dry", comment: "Humidity level description")
        case 30..<50: return String(localized: "Comfortable", comment: "Humidity level description")
        case 50..<70: return String(localized: "Ideal", comment: "Humidity level description")
        case 70..<85: return String(localized: "Humid", comment: "Humidity level description")
        default: return String(localized: "Very humid", comment: "Humidity level description")
        }
    }

    private var visibilityDescription: String {
        switch viewModel.visibility {
        case 0..<1: return String(localized: "Poor", comment: "Visibility level description")
        case 1..<3: return String(localized: "Limited", comment: "Visibility level description")
        case 3..<6: return String(localized: "Good", comment: "Visibility level description")
        default: return String(localized: "Excellent", comment: "Visibility level description")
        }
    }

    private var pressureDescription: String {
        switch viewModel.pressure {
        case 0..<29.80: return String(localized: "Low pressure", comment: "Barometric pressure level description")
        case 29.80..<30.20: return String(localized: "Normal", comment: "Barometric pressure level description")
        default: return String(localized: "High pressure", comment: "Barometric pressure level description")
        }
    }

    private var uvIndexDescription: String {
        switch Int(viewModel.uvIndex) {
        case 0...2: return String(localized: "Low", comment: "UV index level description")
        case 3...5: return String(localized: "Moderate", comment: "UV index level description")
        case 6...7: return String(localized: "High", comment: "UV index level description")
        case 8...10: return String(localized: "Very high", comment: "UV index level description")
        default: return String(localized: "Extreme", comment: "UV index level description")
        }
    }

    private var uvIndexColor: Color {
        switch Int(viewModel.uvIndex) {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }

    private var dewPointDescription: String {
        let difference = viewModel.currentTemperature - viewModel.dewPoint
        switch difference {
        case 0..<10: return String(localized: "Very humid", comment: "Dew point comfort description")
        case 10..<20: return String(localized: "Humid", comment: "Dew point comfort description")
        case 20..<30: return String(localized: "Comfortable", comment: "Dew point comfort description")
        default: return String(localized: "Dry", comment: "Dew point comfort description")
        }
    }

    private var airQualityDescription: String {
        switch viewModel.airQualityIndex {
        case 0...50: return String(localized: "Good", comment: "Air quality index level description")
        case 51...100: return String(localized: "Moderate", comment: "Air quality index level description")
        case 101...150: return String(localized: "Unhealthy for sensitive", comment: "Air quality index level description, short for 'unhealthy for sensitive groups'")
        case 151...200: return String(localized: "Unhealthy", comment: "Air quality index level description")
        case 201...300: return String(localized: "Very unhealthy", comment: "Air quality index level description")
        default: return String(localized: "Hazardous", comment: "Air quality index level description")
        }
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
