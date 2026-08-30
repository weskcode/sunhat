//
//  CurrentConditionsSection.swift
//  SunHat
//
//  The "Now" tab content of WeatherView: current conditions, detailed
//  metrics, air quality/sun, historical comparison, and trigger predictions.
//

import SwiftUI

extension WeatherView {
    // MARK: - Current Conditions Section

    var currentConditionsSection: some View {
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

    // MARK: - Additional Metrics Section

    var additionalMetricsSection: some View {
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

    var hasHistoricalComparison: Bool {
        viewModel.yesterdayTemp != nil ||
            viewModel.lastWeekTemp != nil ||
            viewModel.historicalAvgTemp != nil
    }

    var historicalComparisonSection: some View {
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

    var triggerPredictionsSection: some View {
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

    // MARK: - Description Helpers

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
