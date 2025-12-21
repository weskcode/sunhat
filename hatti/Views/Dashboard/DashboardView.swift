//
//  DashboardView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var showingQuickCreate = false
    @State private var showingAllReminders = false
    @State private var showingWeatherAlerts = false
    
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
                            // Current temperature widget
                            currentTemperatureWidget
                                .padding(.top, 8)
                            
                            // Weather alerts (if any)
                            if !viewModel.activeAlerts.isEmpty {
                                weatherAlertsSection
                            }
                            
                            // Active reminders section
                            activeRemindersSection
                            
                            // 7-day temperature trend
                            temperatureTrendSection
                            
                            // Quick stats
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
            .navigationTitle("hatti")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        NavigationLink("All Reminders", destination: AllRemindersView())
                        NavigationLink("Weather Details", destination: WeatherView())
                        NavigationLink("Settings", destination: SettingsView())
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingQuickCreate) {
                QuickCreateReminderView()
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
        NavigationLink(destination: WeatherView()) {
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
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
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
        guard let weatherData = weatherData else {
            return .gray
        }
        
        // Simplified status logic for Sendable types
        return .orange
    }
    
    private var statusText: String {
        guard let weatherData = weatherData else {
            return "Waiting for weather data"
        }
        
        return "Monitoring"
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
