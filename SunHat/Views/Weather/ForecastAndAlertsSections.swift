//
//  ForecastAndAlertsSections.swift
//  SunHat
//
//  The "24 Hours"/"7 Days" tab content of WeatherView, plus the weather
//  alerts banner shown regardless of the selected timeframe.
//

import SwiftUI

extension WeatherView {
    // MARK: - Hourly Forecast Section

    var hourlyForecastSection: some View {
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

    var weeklyForecastSection: some View {
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

    var weatherAlertsSection: some View {
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
}
