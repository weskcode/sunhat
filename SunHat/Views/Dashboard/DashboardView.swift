//
//  DashboardView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showingQuickCreate = false
    @State private var showingAllReminders = false
    @State private var showingWeatherAlerts = false
    @State private var showingDetailedWeather = false
    @State private var selectedForecastDays: ForecastRange = .sevenDay
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    backgroundGradient
                        .ignoresSafeArea()
                    
                    // Main content
                    RefreshableScrollView {
                        await viewModel.refreshWeatherData()
                    } content: {
                        LazyVStack(spacing: 20) {
                            // Current temperature widget (expandable)
                            currentTemperatureWidget
                                .padding(.top, 16)

                            // Detailed weather metrics (expandable)
                            if showingDetailedWeather {
                                detailedWeatherMetrics
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 0.95).combined(with: .opacity)
                                    ))
                            }

                            // Weather alerts (if any)
                            if !viewModel.activeAlerts.isEmpty {
                                weatherAlertsSection
                            }

                            // Hourly forecast (24 hours)
                            hourlyForecastSection

                            // Active reminders section
                            activeRemindersSection

                            // Multi-day forecast with selector (5/7/10 days)
                            enhancedForecastSection

                            // Comprehensive weather metrics grid
                            comprehensiveWeatherMetrics

                            // Additional weather stats (always visible)
                            quickStatsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for FAB
                    }
                    
                    // Floating Action Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            quickCreateButton
                                .padding(.trailing, 20)
                                .padding(.bottom, 34)
                        }
                    }
                }
            }
            .navigationTitle("SunHat")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingQuickCreate) {
                StreamlinedReminderCreationView(onReminderCreated: {
                    if !onboardingCoordinator.hasCreatedFirstReminder {
                        onboardingCoordinator.markFirstReminderCreated()
                    }
                })
            }
            .sheet(isPresented: $showingAllReminders) {
                AllRemindersView()
            }
            .sheet(isPresented: $showingWeatherAlerts) {
                WeatherAlertsView(alerts: viewModel.activeAlerts)
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
            }
        }
    }
    
    // MARK: - Current Temperature Widget

    private var currentTemperatureWidget: some View {
        Button(action: {
            withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0.2)) {
                showingDetailedWeather.toggle()
            }
        }) {
            temperatureWidgetContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var temperatureWidgetContent: some View {
        VStack(spacing: 0) {
            // Location and time
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.currentLocationName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    if let lastUpdate = viewModel.lastUpdateTime {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()

                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(showingDetailedWeather ? 180 : 0))
                        .animation(.interpolatingSpring(duration: 0.3, bounce: 0.25), value: showingDetailedWeather)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Main temperature display
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // Current temperature
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(viewModel.currentTemperature, specifier: "%.0f")")
                            .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 64 : 72, weight: .thin, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("°")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.primary)
                            .offset(y: 8)
                    }
                    
                    // Feels like temperature
                    Text("Feels like \(viewModel.feelsLikeTemperature, specifier: "%.0f")°")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    // Weather icon and condition
                    VStack(alignment: .trailing, spacing: 8) {
                        Image(systemName: viewModel.weatherIconName)
                            .font(.system(size: 44))
                            .foregroundStyle(viewModel.weatherIconColor)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text(viewModel.weatherDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // High/Low
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("H: \(viewModel.highTemperature, specifier: "%.0f")°")
                            .font(.callout)
                            .foregroundColor(.primary)
                        
                        Text("L: \(viewModel.lowTemperature, specifier: "%.0f")°")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current weather: \(viewModel.currentTemperature, specifier: "%.0f") degrees, feels like \(viewModel.feelsLikeTemperature, specifier: "%.0f") degrees, \(viewModel.weatherDescription)")
    }
    
    // MARK: - Weather Alerts Section
    
    private var weatherAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weather Alerts", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("View All") {
                    showingWeatherAlerts = true
                }
                .font(.callout)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(viewModel.activeAlerts.prefix(2)), id: \.id) { alert in
                    WeatherAlertCard(alert: alert)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Active Reminders Section
    
    private var activeRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active Reminders", systemImage: "bell.badge.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    showingAllReminders = true
                }
                .font(.callout)
                .foregroundColor(.blue)
            }
            
            if viewModel.activeReminders.isEmpty {
                EmptyActiveRemindersView()
            } else {
                LazyVStack(spacing: 12) {
                    SwiftUI.ForEach(Array(viewModel.activeReminders.prefix(3)), id: \.id) { reminder in
                        ActiveReminderCard(reminder: reminder, weatherData: viewModel.currentWeatherData)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Temperature Trend Section
    
    private var temperatureTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("7-Day Forecast", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("°\(viewModel.temperatureUnit.symbol.dropFirst())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.forecastData.isEmpty {
                Text("Forecast data unavailable")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            } else {
                TemperatureTrendChart(forecastData: viewModel.forecastData)
                    .frame(height: 120)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            QuickStatCard(
                icon: "humidity.fill",
                title: "Humidity",
                value: "\(viewModel.humidity)%",
                color: .cyan
            )
            
            QuickStatCard(
                icon: "wind",
                title: "Wind",
                value: "\(String(format: "%.0f", viewModel.windSpeed)) mph",
                color: .green
            )
            
            QuickStatCard(
                icon: "eye.fill",
                title: "Visibility",
                value: "\(String(format: "%.1f", viewModel.visibility)) mi",
                color: .purple
            )
            
            QuickStatCard(
                icon: "sun.max.fill",
                title: "UV Index",
                value: "\(String(format: "%.0f", viewModel.uvIndex))",
                color: .orange
            )
        }
    }
    
    // MARK: - Quick Create Button
    
    private var quickCreateButton: some View {
        Button(action: {
            showingQuickCreate = true
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(FloatingActionButtonStyle())
        .accessibilityLabel("Create new reminder")
    }
    
    // MARK: - Hourly Forecast Section

    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Hourly Forecast", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<24, id: \.self) { hour in
                        HourlyWeatherCard(
                            hour: hour,
                            temperature: viewModel.currentTemperature + Double.random(in: -5...5),
                            condition: viewModel.weatherIconName,
                            precipChance: Int.random(in: 0...30)
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Enhanced Forecast Section

    private var enhancedForecastSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Forecast", systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Forecast range picker
                Picker("Range", selection: $selectedForecastDays) {
                    Text("5 Day").tag(ForecastRange.fiveDay)
                    Text("7 Day").tag(ForecastRange.sevenDay)
                    Text("10 Day").tag(ForecastRange.tenDay)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .animation(.interpolatingSpring(duration: 0.25, bounce: 0.15), value: selectedForecastDays)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if viewModel.forecastData.isEmpty {
                EmptyForecastView()
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.forecastData.prefix(selectedForecastDays.rawValue)), id: \.id) { day in
                        EnhancedDayForecastRow(
                            forecast: day,
                            minTemp: calculateMinTemp(),
                            maxTemp: calculateMaxTemp()
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    private func calculateMinTemp() -> Double {
        guard !viewModel.forecastData.isEmpty else { return 50 }
        let allLows = viewModel.forecastData.map { $0.lowTemperature }
        return allLows.min() ?? 50
    }

    private func calculateMaxTemp() -> Double {
        guard !viewModel.forecastData.isEmpty else { return 90 }
        let allHighs = viewModel.forecastData.map { $0.highTemperature }
        return allHighs.max() ?? 90
    }

    // MARK: - Comprehensive Weather Metrics

    private var comprehensiveWeatherMetrics: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            // Precipitation
            WeatherMetricCard(
                icon: "cloud.rain.fill",
                title: "Precipitation",
                value: "0%",
                subtitle: "in last 24h",
                color: .blue
            )

            // Feels Like
            WeatherMetricCard(
                icon: "thermometer.medium",
                title: "Feels Like",
                value: "\(String(format: "%.0f", viewModel.feelsLikeTemperature))°",
                subtitle: "Similar to actual",
                color: .orange
            )

            // Sunrise/Sunset
            WeatherMetricCard(
                icon: "sunrise.fill",
                title: "Sunrise",
                value: "6:45 AM",
                subtitle: "Sunset: 7:30 PM",
                color: .yellow
            )

            // Air Quality
            WeatherMetricCard(
                icon: "aqi.medium",
                title: "Air Quality",
                value: "Good",
                subtitle: "AQI: 45",
                color: .green
            )

            // Pressure
            WeatherMetricCard(
                icon: "barometer",
                title: "Pressure",
                value: "29.92",
                subtitle: "inHg",
                color: .indigo
            )

            // Cloud Cover
            WeatherMetricCard(
                icon: "cloud.fill",
                title: "Cloud Cover",
                value: "25%",
                subtitle: "Mostly clear",
                color: .gray
            )
        }
    }

    // MARK: - Detailed Weather Metrics

    private var detailedWeatherMetrics: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Label("More Details", systemImage: "info.circle.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button("Less") {
                    withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0.2)) {
                        showingDetailedWeather = false
                    }
                }
                .font(.callout)
                .foregroundColor(.blue)
            }

            // Additional context about weather
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "thermometer.medium")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature Details")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Current: \(String(format: "%.1f", viewModel.currentTemperature))° • Feels like: \(String(format: "%.1f", viewModel.feelsLikeTemperature))°")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("High: \(String(format: "%.0f", viewModel.highTemperature))° • Low: \(String(format: "%.0f", viewModel.lowTemperature))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "cloud.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.weatherDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "humidity.fill")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                Text("\(viewModel.humidity)%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("\(String(format: "%.0f", viewModel.windSpeed)) mph")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visibility & UV")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("Visibility:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", viewModel.visibility)) mi")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 4) {
                                Text("UV Index:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.0f", viewModel.uvIndex))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Computed Properties

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.03),
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
}

// MARK: - Weather Alert Card

struct WeatherAlertCard: View {
    let alert: WeatherAlertDisplay
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.iconName)
                .font(.title3)
                .foregroundColor(alert.severityColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(alert.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(alert.severityColor.opacity(0.1))
        )
    }
}

// MARK: - Active Reminder Card

struct ActiveReminderCard: View {
    let reminder: WeatherReminderDisplay
    let weatherData: WeatherDataTransfer?
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: reminder.category.iconName)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let condition = reminder.triggerCondition {
                    Text("Trigger: When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature, specifier: "%.1f")°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Trigger: No condition set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Temperature difference indicator (simplified for Sendable types)
            if let weatherData = weatherData {
                Text("\(weatherData.temperature, specifier: "%.0f")°")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var statusColor: Color {
        guard weatherData != nil else {
            return .gray
        }

        // Simplified status logic for Sendable types
        return .orange
    }

    private var statusText: String {
        guard weatherData != nil else {
            return "Waiting for weather data"
        }

        return "Monitoring"
    }
}

// MARK: - Detailed Weather Card

struct DetailedWeatherCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Empty Active Reminders View

struct EmptyActiveRemindersView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("No active reminders")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Create your first weather reminder to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Forecast Range Enum

enum ForecastRange: Int {
    case fiveDay = 5
    case sevenDay = 7
    case tenDay = 10
}

// MARK: - Hourly Weather Card

struct HourlyWeatherCard: View {
    let hour: Int
    let temperature: Double
    let condition: String
    let precipChance: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(hourText)
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: condition)
                .font(.title3)
                .foregroundColor(conditionColor)
                .frame(height: 24)

            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundColor(.cyan)
                Text("\(precipChance)%")
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
            .opacity(precipChance > 0 ? 1 : 0)

            Text("\(String(format: "%.0f", temperature))°")
                .font(.callout)
                .fontWeight(.semibold)
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var conditionColor: Color {
        if condition.contains("sun") || condition.contains("clear") {
            return .orange
        } else if condition.contains("cloud.bolt") {
            return .purple
        } else if condition.contains("cloud.rain") || condition.contains("cloud.heavyrain") {
            return .blue
        } else if condition.contains("cloud.snow") || condition.contains("snowflake") {
            return .cyan
        } else if condition.contains("cloud.fog") || condition.contains("cloud.haze") {
            return .gray
        } else if condition.contains("cloud") {
            return .gray
        } else if condition.contains("wind") {
            return .teal
        } else if condition.contains("moon") {
            return .indigo
        } else {
            return .orange
        }
    }

    private var hourText: String {
        if hour == 0 {
            return "Now"
        }
        let futureHour = (Calendar.current.component(.hour, from: Date()) + hour) % 24
        let period = futureHour < 12 ? "AM" : "PM"
        let displayHour = futureHour == 0 ? 12 : (futureHour > 12 ? futureHour - 12 : futureHour)
        return "\(displayHour)\(period)"
    }
}

// MARK: - Enhanced Day Forecast Row

struct EnhancedDayForecastRow: View {
    let forecast: ForecastDay
    let minTemp: Double
    let maxTemp: Double

    var body: some View {
        HStack(spacing: 10) {
            // Day name
            Text(dayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 52, alignment: .leading)

            // Weather icon
            Image(systemName: forecast.weatherCondition.icon)
                .font(.body)
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 26)

            // Precipitation chance
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("\(forecast.precipitationProbability)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, alignment: .leading)
            .opacity(forecast.precipitationProbability > 0 ? 1 : 0)

            Spacer(minLength: 4)

            // Temperature bar
            HStack(spacing: 5) {
                Text("\(String(format: "%.0f", forecast.lowTemperature))°")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)

                TemperatureBar(
                    low: forecast.lowTemperature,
                    high: forecast.highTemperature,
                    minTemp: minTemp,
                    maxTemp: maxTemp
                )
                .frame(width: 75, height: 6)

                Text("\(String(format: "%.0f", forecast.highTemperature))°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: 30, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
    }

    private var dayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(forecast.date) {
            return "Today"
        } else if calendar.isDateInTomorrow(forecast.date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: forecast.date)
        }
    }
}

// MARK: - Temperature Bar

struct TemperatureBar: View {
    let low: Double
    let high: Double
    let minTemp: Double
    let maxTemp: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                // Temperature range
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: rangeWidth(in: geometry.size.width), height: 6)
                    .offset(x: startOffset(in: geometry.size.width))
            }
        }
        .frame(height: 6)
    }

    private func startOffset(in width: CGFloat) -> CGFloat {
        let normalized = max(0, min(1, (low - minTemp) / (maxTemp - minTemp)))
        return width * normalized
    }

    private func rangeWidth(in width: CGFloat) -> CGFloat {
        let normalizedLow = max(0, min(1, (low - minTemp) / (maxTemp - minTemp)))
        let normalizedHigh = max(0, min(1, (high - minTemp) / (maxTemp - minTemp)))
        return max(width * 0.15, width * (normalizedHigh - normalizedLow))
    }
}

// MARK: - Weather Metric Card

struct WeatherMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Empty Forecast View

struct EmptyForecastView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.slash")
                .font(.title)
                .foregroundColor(.secondary)

            Text("Forecast unavailable")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Pull to refresh weather data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Refreshable Scroll View

struct RefreshableScrollView<Content: View>: View {
    let onRefresh: () async -> Void
    let content: Content

    @State private var isRefreshing = false

    init(onRefresh: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            isRefreshing = true
            await onRefresh()
            isRefreshing = false
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .modelContainer(for: [
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            UserPreferences.self,
            LocationData.self
        ], inMemory: true)
}
