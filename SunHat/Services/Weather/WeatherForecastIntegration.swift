//
//  WeatherForecastIntegration.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import Foundation

// MARK: - Real-time Weather Integration

struct RealTimeWeatherCard: View {
    let reminder: CustomReminder
    @State private var currentWeather: CurrentWeatherData?
    @State private var isLoading = true
    @State private var animateWeatherIcon = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Right Now")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let weather = currentWeather {
                // Current weather display
                HStack(spacing: 20) {
                    // Weather icon
                    VStack(spacing: 8) {
                        Image(systemName: weather.weatherIcon)
                            .font(.title)
                            .foregroundColor(weather.iconColor)
                            .scaleEffect(animateWeatherIcon ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateWeatherIcon)
                        
                        Text(weather.condition)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Temperature and details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(weather.temperature))°")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("F")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Feels like \(Int(weather.feelsLike))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Trigger status
                        TriggerStatusIndicator(
                            weather: weather,
                            reminder: reminder
                        )
                    }
                    
                    Spacer()
                }
            } else if !isLoading {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("Unable to load weather")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            loadCurrentWeather()
            animateWeatherIcon = true
        }
    }
    
    private func loadCurrentWeather() {
        // Simulate loading current weather
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            currentWeather = generateMockCurrentWeather()
            isLoading = false
        }
    }
    
    private func generateMockCurrentWeather() -> CurrentWeatherData {
        let temp = Double.random(in: 45...85)
        let conditions = ["Clear", "Partly Cloudy", "Cloudy", "Light Rain"]
        let condition = conditions.randomElement() ?? "Clear"
        
        return CurrentWeatherData(
            temperature: temp,
            feelsLike: temp + Double.random(in: -5...5),
            condition: condition,
            weatherIcon: getIconForCondition(condition),
            iconColor: getColorForCondition(condition)
        )
    }
    
    private func getIconForCondition(_ condition: String) -> String {
        switch condition {
        case "Clear":
            return "sun.max.fill"
        case "Partly Cloudy":
            return "cloud.sun.fill"
        case "Cloudy":
            return "cloud.fill"
        case "Light Rain":
            return "cloud.drizzle.fill"
        default:
            return "sun.max.fill"
        }
    }
    
    private func getColorForCondition(_ condition: String) -> Color {
        switch condition {
        case "Clear":
            return .yellow
        case "Partly Cloudy":
            return .orange
        case "Cloudy":
            return .gray
        case "Light Rain":
            return .blue
        default:
            return .yellow
        }
    }
}

// MARK: - Trigger Status Indicator

struct TriggerStatusIndicator: View {
    let weather: CurrentWeatherData
    let reminder: CustomReminder

    private var willTrigger: Bool {
        // Check temperature
        let tempMatch: Bool
        switch reminder.temperatureType {
        case .temperatureRange:
            tempMatch = weather.temperature >= reminder.minTemperature &&
                        weather.temperature <= reminder.maxTemperature
        case .exactTemperature:
            tempMatch = abs(weather.temperature - reminder.minTemperature) <= 2
        }

        // Check sky conditions against current weather condition string
        let skyMatch: Bool
        if reminder.selectedSkyConditions.isEmpty {
            skyMatch = true
        } else {
            // Map the current weather condition string to a SkyCondition
            let currentSky: SkyCondition
            switch weather.condition.lowercased() {
            case "clear": currentSky = .sunny
            case "partly cloudy": currentSky = .partlyCloudy
            case "cloudy": currentSky = .cloudy
            case "light rain", "rain": currentSky = .rainy
            case "snow": currentSky = .snowy
            default: currentSky = .sunny
            }

            switch reminder.conditionMode {
            case .include:
                skyMatch = reminder.selectedSkyConditions.contains(currentSky)
            case .exclude:
                skyMatch = !reminder.selectedSkyConditions.contains(currentSky)
            }
        }

        return tempMatch && skyMatch
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(willTrigger ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(willTrigger ? "Will trigger now!" : "Waiting for conditions")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(willTrigger ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((willTrigger ? Color.green : Color.orange).opacity(0.1))
        )
    }
}

// MARK: - Enhanced Forecast Timeline

struct ForecastTimelineView: View {
    let forecast: [WeatherForecastDay]
    let reminder: CustomReminder
    
    @State private var selectedDay: WeatherForecastDay?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("7-Day Outlook")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Details") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(forecast, id: \.date) { day in
                        ForecastDayCard(
                            day: day,
                            reminder: reminder,
                            isSelected: selectedDay?.date == day.date
                        ) {
                            selectedDay = day
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Selected day details
            if let selectedDay = selectedDay {
                DayDetailsCard(day: selectedDay, reminder: reminder)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingDetails) {
            DetailedForecastView(forecast: forecast, reminder: reminder)
        }
    }
}

struct ForecastDayCard: View {
    let day: WeatherForecastDay
    let reminder: CustomReminder
    let isSelected: Bool
    let onTap: () -> Void

    private var willTrigger: Bool {
        let tempMatch: Bool
        switch reminder.temperatureType {
        case .temperatureRange:
            tempMatch = day.highTemp >= Int(reminder.minTemperature) &&
                        day.highTemp <= Int(reminder.maxTemperature)
        case .exactTemperature:
            tempMatch = abs(Double(day.highTemp) - reminder.minTemperature) <= 2
        }
        let skyMatch = reminder.matchesSkyCondition(for: day.weatherCondition)
        return tempMatch && skyMatch
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Day name
                Text(day.dayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Weather icon
                Image(systemName: day.weatherIcon)
                    .font(.title3)
                    .foregroundColor(day.weatherColor)
                
                // Temperature
                Text("\(day.highTemp)°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Trigger indicator
                Circle()
                    .fill(willTrigger ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DayDetailsCard: View {
    let day: WeatherForecastDay
    let reminder: CustomReminder
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(day.dayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(day.shortDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                // Weather info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: day.weatherIcon)
                            .foregroundColor(day.weatherColor)
                        
                        Text("\(day.highTemp)° / \(day.lowTemp)°")
                            .fontWeight(.medium)
                    }
                    
                    Text("Conditions look good for \(reminder.displayTitle.lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Trigger probability
                VStack(alignment: .trailing, spacing: 4) {
                    Text("85%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Trigger chance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Data Models

struct CurrentWeatherData {
    let temperature: Double
    let feelsLike: Double
    let condition: String
    let weatherIcon: String
    let iconColor: Color
}

// MARK: - Detailed Forecast View

struct DetailedForecastView: View {
    let forecast: [WeatherForecastDay]
    let reminder: CustomReminder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(forecast, id: \.date) { day in
                        DetailedDayCard(day: day, reminder: reminder)
                    }
                }
                .padding()
            }
            .navigationTitle("Detailed Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailedDayCard: View {
    let day: WeatherForecastDay
    let reminder: CustomReminder
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(day.dayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(day.shortDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Image(systemName: day.weatherIcon)
                            .foregroundColor(day.weatherColor)
                        
                        Text("\(day.highTemp)°")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Low \(day.lowTemp)°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Trigger analysis
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trigger Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Perfect conditions for \(reminder.displayTitle.lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("85%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Likelihood")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RealTimeWeatherCard(
            reminder: CustomReminder()
        )
        
        ForecastTimelineView(
            forecast: [],
            reminder: CustomReminder()
        )
    }
    .padding()
}
