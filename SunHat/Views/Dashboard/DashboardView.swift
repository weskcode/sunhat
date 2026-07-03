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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeSheet: ActiveSheet?
    @State private var showingDetailedWeather = false
    @State private var cardsVisible = false

    private enum ActiveSheet: Identifiable {
        case allReminders
        case weatherAlerts

        var id: Self { self }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SunHatAtmosphereBackground(
                    condition: viewModel.weatherCondition,
                    intensity: viewModel.hasWeatherData ? 1 : 0.55
                )
                    .ignoresSafeArea()

                RefreshableScrollView {
                    await viewModel.refreshWeatherData()
                } content: {
                    LazyVStack(spacing: 18) {
                        currentTemperatureWidget
                            .padding(.top, 16)
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible || reduceMotion ? 0 : 16)
                            .animation(SunHatMotion.reveal(reduceMotion: reduceMotion), value: cardsVisible)

                        NextReadyReminderCompactView(
                            snapshot: NextReadyReminderSelector.snapshot(from: viewModel.activeReminders)
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible || reduceMotion ? 0 : 16)
                        .animation(SunHatMotion.reveal(reduceMotion: reduceMotion, delay: 0.05), value: cardsVisible)

                        if showingDetailedWeather {
                            detailedWeatherMetrics
                                .transition(detailsTransition)
                        }

                        if !viewModel.activeReminders.isEmpty {
                            readyNowSection
                                .transition(detailsTransition)
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible || reduceMotion ? 0 : 16)
                                .animation(SunHatMotion.reveal(reduceMotion: reduceMotion, delay: 0.08), value: cardsVisible)
                        }

                        activeRemindersSection
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible || reduceMotion ? 0 : 16)
                            .animation(SunHatMotion.reveal(reduceMotion: reduceMotion, delay: 0.15), value: cardsVisible)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("SunHat")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .allReminders:
                    AllRemindersView()
                case .weatherAlerts:
                    WeatherAlertsView(alerts: viewModel.activeAlerts)
                }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                cardsVisible = true
            }
        }
    }
    
    // MARK: - Current Temperature Widget

    private var currentTemperatureWidget: some View {
        Button(action: {
            withAnimation(cardToggleAnimation) {
                showingDetailedWeather.toggle()
            }
        }) {
            temperatureWidgetContent
        }
        .buttonStyle(SunHatPressButtonStyle())
        .accessibilityHint(showingDetailedWeather ? "Double tap to hide weather details." : "Double tap to show weather details.")
    }
    
    private var temperatureWidgetContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(Color.accentColor)
                        
                        Text(viewModel.currentLocationName)
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    
                    if let lastUpdate = viewModel.lastUpdateTime {
                        Text("Updated \(lastUpdate, style: .relative) ago")
                            .font(AppFontStyle.caption2.font)
                            .foregroundStyle(.secondary)
                    } else if viewModel.isLoading {
                        Text("Updating weather")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    SunHatStatusPill(
                        text: viewModel.hasWeatherData ? "Live" : "Standby",
                        systemImage: viewModel.hasWeatherData ? "dot.radiowaves.left.and.right" : "clock",
                        tint: viewModel.hasWeatherData ? .green : .secondary
                    )

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            weatherSummaryContent

            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(AppFontStyle.caption.font.weight(.semibold))
                    .rotationEffect(.degrees(showingDetailedWeather ? 180 : 0))
                    .animation(SunHatMotion.cardToggle(reduceMotion: reduceMotion), value: showingDetailedWeather)

                Text(showingDetailedWeather ? "Hide forecast detail" : "Show forecast detail")
                    .font(AppFontStyle.caption.font.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.primary.opacity(0.045), in: .capsule)
        }
        .padding(18)
        .sunHatSurface(tint: viewModel.weatherIconColor, cornerRadius: 28, prominence: 1.08)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weatherAccessibilityLabel)
        .accessibilityValue(showingDetailedWeather ? "Details shown" : "Details hidden")
    }

    @ViewBuilder
    private var weatherSummaryContent: some View {
        if viewModel.hasWeatherData {
            availableWeatherSummary
        } else {
            unavailableWeatherSummary
        }
    }

    private var availableWeatherSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 3) {
                        Text(viewModel.currentTemperatureDisplay)
                            .font(AppFont.system(size: dynamicTypeSize.isAccessibilitySize ? 58 : 82, weight: .thin))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.72)

                        Text("°")
                            .font(AppFont.system(size: dynamicTypeSize.isAccessibilitySize ? 22 : 28, weight: .light))
                            .foregroundStyle(.primary)
                            .offset(y: dynamicTypeSize.isAccessibilitySize ? 7 : 11)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.weatherDescription)
                            .font(AppFontStyle.headline.font)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text("Feels like \(viewModel.feelsLikeTemperatureDisplay)°")
                            .font(AppFontStyle.callout.font)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer(minLength: 8)

                SunHatWeatherDial(
                    systemImage: viewModel.weatherIconName,
                    tint: viewModel.weatherIconColor,
                    reduceMotion: reduceMotion
                )
            }

            SunHatForecastRibbon(
                current: viewModel.currentTemperature,
                high: viewModel.highTemperature,
                low: viewModel.lowTemperature,
                tint: viewModel.weatherIconColor
            )
            .frame(height: 54)
            .accessibilityHidden(true)

            HStack(spacing: 8) {
                WeatherHeroMetricPill(
                    title: "High",
                    value: "\(viewModel.highTemperatureDisplay)°",
                    systemImage: "arrow.up",
                    tint: .orange
                )

                WeatherHeroMetricPill(
                    title: "Low",
                    value: "\(viewModel.lowTemperatureDisplay)°",
                    systemImage: "arrow.down",
                    tint: .cyan
                )

                WeatherHeroMetricPill(
                    title: "Wind",
                    value: viewModel.windSpeedDisplay,
                    systemImage: "wind",
                    tint: .mint
                )
            }
        }
    }

    private var unavailableWeatherSummary: some View {
        HStack(spacing: 14) {
            SunHatWeatherDial(
                systemImage: "cloud.fill",
                tint: .secondary,
                reduceMotion: true
            )
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 5) {
                Text("Weather unavailable")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(viewModel.errorMessage ?? "Pull down to refresh once weather access is available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Active Reminders Section

    private var readyNowSection: some View {
        SunHatCardSection(
            title: "Ready Now",
            systemImage: "checkmark.circle.fill",
            subtitle: "Tasks matching the current forecast",
            tint: .green
        ) {
            if viewModel.activeReminders.isEmpty {
                SunHatEmptyState(
                    title: "No Tasks Yet",
                    message: "Create a weather task and SunHat will watch for matching conditions.",
                    systemImage: "bell.slash"
                )
            } else if viewModel.activeAlerts.isEmpty {
                SunHatEmptyState(
                    title: "Nothing Ready Right Now",
                    message: "SunHat is still watching your active tasks and will notify you when the weather matches.",
                    systemImage: "clock.badge.checkmark"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.activeAlerts.prefix(2)), id: \.id) { alert in
                        WeatherAlertCard(alert: alert)
                    }
                }
            }
        }
    }
    
    private var activeRemindersSection: some View {
        SunHatCardSection(
            title: "Watching",
            systemImage: "bell.badge.fill",
            subtitle: "\(viewModel.activeReminders.count) active task\(viewModel.activeReminders.count == 1 ? "" : "s")",
            actionTitle: "View All",
            actionSystemImage: "chevron.right",
            tint: .accentColor,
            action: {
                activeSheet = .allReminders
            }
        ) {
            if viewModel.activeReminders.isEmpty {
                SunHatEmptyState(
                    title: "No Active Tasks",
                    message: "Create a weather task and SunHat will watch for matching conditions.",
                    systemImage: "list.bullet.clipboard"
                )
            } else {
                LazyVStack(spacing: 12) {
                    SwiftUI.ForEach(Array(viewModel.activeReminders.prefix(3)), id: \.id) { reminder in
                        ActiveReminderCard(reminder: reminder, weatherData: viewModel.currentWeatherData)
                    }
                }
            }
        }
    }
    
    private var cardToggleAnimation: Animation {
        SunHatMotion.cardToggle(reduceMotion: reduceMotion)
    }

    private var detailsTransition: AnyTransition {
        SunHatMotion.transition(reduceMotion: reduceMotion)
    }

    private var weatherAccessibilityLabel: String {
        guard viewModel.hasWeatherData else {
            return "Weather unavailable for \(viewModel.currentLocationName)"
        }

        return "Current weather for \(viewModel.currentLocationName): \(viewModel.currentTemperatureDisplay) degrees, feels like \(viewModel.feelsLikeTemperatureDisplay) degrees, \(viewModel.weatherDescription)"
    }

    // MARK: - Detailed Weather Metrics

    private var detailedWeatherMetrics: some View {
        SunHatCardSection(
            title: "More Details",
            systemImage: "info.circle.fill",
            subtitle: "Forecast context for your reminders",
            actionTitle: "Less",
            actionSystemImage: "chevron.up",
            tint: .blue,
            action: {
                withAnimation(SunHatMotion.emphasized(reduceMotion: reduceMotion)) {
                    showingDetailedWeather = false
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DashboardMetricRow(
                    systemImage: "thermometer.medium",
                    tint: .orange,
                    title: "Temperature",
                    primary: "Current \(viewModel.currentTemperatureDisplay)° • Feels like \(viewModel.feelsLikeTemperatureDisplay)°",
                    secondary: "High \(viewModel.highTemperatureDisplay)° • Low \(viewModel.lowTemperatureDisplay)°"
                )

                Divider()

                DashboardMetricRow(
                    systemImage: "cloud.fill",
                    tint: .blue,
                    title: viewModel.weatherDescription,
                    primary: "Humidity \(viewModel.humidity)%",
                    secondary: "Wind \(viewModel.windSpeedDisplay)"
                )

                Divider()

                DashboardMetricRow(
                    systemImage: "eye.fill",
                    tint: .purple,
                    title: "Visibility & UV",
                    primary: "Visibility \(viewModel.visibilityDisplay)",
                    secondary: "UV Index \(viewModel.uvIndexDisplay)"
                )
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
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
