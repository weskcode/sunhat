//
//  RealTimeWeatherCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct RealTimeWeatherCard: View {
    let reminder: CustomReminder

    @State private var currentWeather: CurrentWeatherData?
    @State private var isLoading = true
    @State private var animateWeatherIcon = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if let weather = currentWeather {
                currentWeatherContent(weather)
            } else if !isLoading {
                errorContent
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        }
        .task {
            animateWeatherIcon = true
            await loadCurrentWeather()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(.blue)

            Text("Right Now")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private var errorContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Unable to load weather")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func currentWeatherContent(_ weather: CurrentWeatherData) -> some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: weather.weatherIcon)
                    .font(.title)
                    .foregroundStyle(weather.iconColor)
                    .scaleEffect(animateWeatherIcon ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateWeatherIcon)

                Text(weather.condition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(weather.temperature))°")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("F")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Feels like \(Int(weather.feelsLike))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TriggerStatusIndicator(
                    weather: weather,
                    reminder: reminder
                )
            }

            Spacer()
        }
    }

    private func loadCurrentWeather() async {
        do {
            try await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            currentWeather = generateMockCurrentWeather()
            isLoading = false
        } catch {
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
            weatherIcon: icon(for: condition),
            iconColor: color(for: condition)
        )
    }

    private func icon(for condition: String) -> String {
        switch condition {
        case "Clear":
            "sun.max.fill"
        case "Partly Cloudy":
            "cloud.sun.fill"
        case "Cloudy":
            "cloud.fill"
        case "Light Rain":
            "cloud.drizzle.fill"
        default:
            "sun.max.fill"
        }
    }

    private func color(for condition: String) -> Color {
        switch condition {
        case "Clear":
            .yellow
        case "Partly Cloudy":
            .orange
        case "Cloudy":
            .gray
        case "Light Rain":
            .blue
        default:
            .yellow
        }
    }
}

#Preview {
    RealTimeWeatherCard(reminder: CustomReminder())
        .padding()
}
