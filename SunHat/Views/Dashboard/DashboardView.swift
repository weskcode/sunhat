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

    @State private var activeSheet: ActiveSheet?
    @State private var showingDetailedWeather = false
    @State private var selectedForecastDays: ForecastRange = .sevenDay

    private enum ActiveSheet: Identifiable {
        case quickCreate
        case allReminders
        case weatherAlerts

        var id: Self { self }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    backgroundGradient
                        .ignoresSafeArea()
                    
                    RefreshableScrollView {
                        await viewModel.refreshWeatherData()
                    } content: {
                        LazyVStack(spacing: 20) {
                            currentTemperatureWidget
                                .padding(.top, 16)

                            if showingDetailedWeather {
                                detailedWeatherMetrics
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 0.95).combined(with: .opacity)
                                    ))
                            }

                            readyNowSection
                            activeRemindersSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("SunHat")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                quickCreateButton
                    .padding(.trailing, 18)
                    .padding(.bottom, 10)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .quickCreate:
                    StreamlinedReminderCreationView(onReminderCreated: {
                        if !onboardingCoordinator.hasCreatedFirstReminder {
                            onboardingCoordinator.markFirstReminderCreated()
                        }
                    })
                case .allReminders:
                    AllRemindersView()
                case .weatherAlerts:
                    WeatherAlertsView(alerts: viewModel.activeAlerts)
                }
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
                            .font(AppFontStyle.caption.font)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.currentLocationName)
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    if let lastUpdate = viewModel.lastUpdateTime {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(AppFontStyle.caption2.font)
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
                        .font(AppFontStyle.title3.font)
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
                            .font(AppFont.inter(size: dynamicTypeSize.isAccessibilitySize ? 64 : 72, weight: .thin))
                            .foregroundColor(.primary)
                        
                        Text("°")
                            .font(AppFont.inter(size: 24, weight: .light))
                            .foregroundColor(.primary)
                            .offset(y: 8)
                    }
                    
                    // Feels like temperature
                    Text("Feels like \(viewModel.feelsLikeTemperature, specifier: "%.0f")°")
                        .font(AppFontStyle.callout.font)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    // Weather icon and condition
                    VStack(alignment: .trailing, spacing: 8) {
                        Image(systemName: viewModel.weatherIconName)
                            .font(AppFont.inter(size: 44))
                            .foregroundStyle(viewModel.weatherIconColor)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text(viewModel.weatherDescription)
                            .font(AppFontStyle.caption.font)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // High/Low
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("H: \(viewModel.highTemperature, specifier: "%.0f")°")
                            .font(AppFontStyle.callout.font)
                            .foregroundColor(.primary)
                        
                        Text("L: \(viewModel.lowTemperature, specifier: "%.0f")°")
                            .font(AppFontStyle.callout.font)
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
                    .font(AppFontStyle.headline.font)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("View All") {
                    activeSheet = .weatherAlerts
                }
                .font(AppFontStyle.callout.font)
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

    private var readyNowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ready Now", systemImage: "checkmark.circle.fill")
                .font(AppFontStyle.headline.font)
                .foregroundColor(.primary)

            if viewModel.activeReminders.isEmpty {
                Text("Create a weather task and SunHat will watch for matching conditions.")
                    .font(AppFontStyle.callout.font)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.activeAlerts.isEmpty {
                Text("No tasks match the weather right now. SunHat is still watching.")
                    .font(AppFontStyle.callout.font)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.activeAlerts.prefix(2)), id: \.id) { alert in
                        WeatherAlertCard(alert: alert)
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
    
    private var activeRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Watching", systemImage: "bell.badge.fill")
                    .font(AppFontStyle.headline.font)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    activeSheet = .allReminders
                }
                .font(AppFontStyle.callout.font)
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
                    .font(AppFontStyle.headline.font)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("°\(viewModel.temperatureUnit.symbol.dropFirst())")
                    .font(AppFontStyle.caption.font)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.forecastData.isEmpty {
                Text("Forecast data unavailable")
                    .font(AppFontStyle.callout.font)
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
        GlassCreateTaskButton {
            activeSheet = .quickCreate
        }
    }
    
    // MARK: - Hourly Forecast Section

    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Hourly Forecast", systemImage: "clock.fill")
                    .font(AppFontStyle.headline.font)
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
                    .font(AppFontStyle.headline.font)
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
                    .font(AppFontStyle.headline.font)
                    .foregroundColor(.primary)

                Spacer()

                Button("Less") {
                    withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0.2)) {
                        showingDetailedWeather = false
                    }
                }
                .font(AppFontStyle.callout.font)
                .foregroundColor(.blue)
            }

            // Additional context about weather
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "thermometer.medium")
                        .font(AppFontStyle.title2.font)
                        .foregroundColor(.orange)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature Details")
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)

                        Text("Current: \(String(format: "%.1f", viewModel.currentTemperature))° • Feels like: \(String(format: "%.1f", viewModel.feelsLikeTemperature))°")
                            .font(AppFontStyle.caption.font)
                            .foregroundColor(.secondary)

                        Text("High: \(String(format: "%.0f", viewModel.highTemperature))° • Low: \(String(format: "%.0f", viewModel.lowTemperature))°")
                            .font(AppFontStyle.caption.font)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "cloud.fill")
                        .font(AppFontStyle.title2.font)
                        .foregroundColor(.blue)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.weatherDescription)
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "humidity.fill")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.cyan)
                                Text("\(viewModel.humidity)%")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.green)
                                Text("\(String(format: "%.0f", viewModel.windSpeed)) mph")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(AppFontStyle.title2.font)
                        .foregroundColor(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visibility & UV")
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("Visibility:")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", viewModel.visibility)) mi")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 4) {
                                Text("UV Index:")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.0f", viewModel.uvIndex))")
                                    .font(AppFontStyle.caption.font)
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
