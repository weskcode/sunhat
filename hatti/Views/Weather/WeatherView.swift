//
//  WeatherView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct WeatherView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: WeatherViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var selectedTimeframe: WeatherTimeframe = .current
    @State private var showingLocationPicker = false
    @State private var selectedLocation: ReminderLocation = .currentLocation
    
    init() {
        // Initialize with a dummy modelContext - will be configured in onAppear
        let container = try! ModelContainer(for: WeatherData.self, WeatherReminder.self, LocationData.self, TriggerCondition.self)
        self._viewModel = StateObject(wrappedValue: WeatherViewModel(modelContext: container.mainContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                RefreshableScrollView {
                    await viewModel.refresh()
                } content: {
                    LazyVStack(spacing: 20) {
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
                        
                        // Additional weather metrics
                        additionalMetricsSection
                        
                        // Historical comparison section
                        historicalComparisonSection
                        
                        // Reminder trigger predictions
                        triggerPredictionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Weather Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        Image(systemName: "location")
                    }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
            .onAppear {
                // The viewModel is already configured with modelContext from init
            }
        }
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
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.locationName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    if let lastUpdate = viewModel.lastUpdateTime {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        Text("\(viewModel.currentTemperature, specifier: "%.1f")")
                            .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 68 : 80, weight: .ultraLight, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("°")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.primary)
                            .offset(y: 12)
                    }
                    
                    // Feels like temperature with visual distinction
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("Feels like \(viewModel.feelsLikeTemperature, specifier: "%.1f")°")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    // Temperature difference indicator
                    let tempDifference = viewModel.feelsLikeTemperature - viewModel.currentTemperature
                    if abs(tempDifference) > 2 {
                        HStack(spacing: 6) {
                            Image(systemName: tempDifference > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                                .foregroundColor(tempDifference > 0 ? .red : .blue)
                            
                            Text("\(abs(tempDifference), specifier: "%.1f")° \(tempDifference > 0 ? "warmer" : "cooler")")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // High/Low temperatures
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text("\(viewModel.highTemperature, specifier: "%.0f")°")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(viewModel.lowTemperature, specifier: "%.0f")°")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current weather: \(viewModel.currentTemperature, specifier: "%.1f") degrees, feels like \(viewModel.feelsLikeTemperature, specifier: "%.1f") degrees, \(viewModel.weatherDescription). High \(viewModel.highTemperature, specifier: "%.0f"), low \(viewModel.lowTemperature, specifier: "%.0f") degrees")
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
                value: "\(String(format: "%.1f", viewModel.windSpeed)) mph",
                description: "\(viewModel.windDirection) • \(viewModel.windGust > 0 ? "Gusts \(String(format: "%.0f", viewModel.windGust)) mph" : "Steady")",
                color: .green
            )
            
            DetailedMetricCard(
                icon: "eye.fill",
                title: "Visibility",
                value: "\(String(format: "%.1f", viewModel.visibility)) mi",
                description: visibilityDescription,
                color: .purple
            )
            
            DetailedMetricCard(
                icon: "barometer",
                title: "Pressure",
                value: "\(String(format: "%.2f", viewModel.pressure)) inHg",
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
                value: "\(viewModel.dewPoint, specifier: "%.0f")°",
                description: dewPointDescription,
                color: .mint
            )
        }
    }
    
    // MARK: - Hourly Forecast Section
    
    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "24-Hour Forecast", icon: "clock.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.hourlyForecast, id: \.hour) { hourData in
                        HourlyForecastCard(hourData: hourData)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Weather Alerts Section
    
    private var weatherAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Weather Alerts", icon: "exclamationmark.triangle.fill", color: .orange)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.weatherAlerts, id: \.id) { alert in
                    WeatherAlertDetailCard(alert: alert)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Historical Comparison Section
    
    private var historicalComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Historical Comparison", icon: "chart.line.uptrend.xyaxis")
            
            VStack(spacing: 12) {
                HistoricalComparisonRow(
                    title: "vs. Yesterday",
                    currentTemp: viewModel.currentTemperature,
                    historicalTemp: viewModel.yesterdayTemp,
                    timeframe: "24h ago"
                )
                
                HistoricalComparisonRow(
                    title: "vs. Last Week",
                    currentTemp: viewModel.currentTemperature,
                    historicalTemp: viewModel.lastWeekTemp,
                    timeframe: "7 days ago"
                )
                
                HistoricalComparisonRow(
                    title: "vs. Historical Average",
                    currentTemp: viewModel.currentTemperature,
                    historicalTemp: viewModel.historicalAvgTemp,
                    timeframe: "Historical avg for today"
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color = .primary) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.05),
                Color.black
            ] : [
                Color(red: 0.98, green: 0.99, blue: 1.0),
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var humidityDescription: String {
        switch viewModel.humidity {
        case 0..<30: return "Very dry"
        case 30..<50: return "Comfortable"
        case 50..<70: return "Ideal"
        case 70..<85: return "Humid"
        default: return "Very humid"
        }
    }
    
    private var visibilityDescription: String {
        switch viewModel.visibility {
        case 0..<1: return "Poor"
        case 1..<3: return "Limited"
        case 3..<6: return "Good"
        default: return "Excellent"
        }
    }
    
    private var pressureDescription: String {
        switch viewModel.pressure {
        case 0..<29.80: return "Low pressure"
        case 29.80..<30.20: return "Normal"
        default: return "High pressure"
        }
    }
    
    private var uvIndexDescription: String {
        switch Int(viewModel.uvIndex) {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very high"
        default: return "Extreme"
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
        case 0..<10: return "Very humid"
        case 10..<20: return "Humid"
        case 20..<30: return "Comfortable"
        default: return "Dry"
        }
    }
    
    private var airQualityDescription: String {
        switch viewModel.airQualityIndex {
        case 0...50: return "Good"
        case 51...100: return "Moderate"
        case 101...150: return "Unhealthy for sensitive"
        case 151...200: return "Unhealthy"
        case 201...300: return "Very unhealthy"
        default: return "Hazardous"
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