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

    @State private var cardsVisible = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                RefreshableScrollView {
                    await viewModel.refreshWeatherData()
                } content: {
                    LazyVStack(spacing: 22) {
                        currentTemperatureWidget
                            .padding(.top, 12)
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible || reduceMotion ? 0 : 16)
                            .animation(SunHatMotion.reveal(reduceMotion: reduceMotion), value: cardsVisible)

                        NextReadyReminderCompactView(
                            snapshot: NextReadyReminderSelector.snapshot(from: viewModel.activeReminders)
                        )
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible || reduceMotion ? 0 : 16)
                        .animation(SunHatMotion.reveal(reduceMotion: reduceMotion, delay: 0.05), value: cardsVisible)

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
                    .padding(.bottom, 132)
                }
            }
            .navigationTitle("SunHat")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                cardsVisible = true
            }
        }
    }
    
    // MARK: - Current Temperature Widget

    @ViewBuilder
    private var currentTemperatureWidget: some View {
        temperatureWidgetContent
            .accessibilityHint(
                viewModel.hasWeatherData
                    ? ""
                    : "Pull down to refresh when weather access is available."
            )
    }
    
    private var temperatureWidgetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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

        }
        .padding(18)
        .sunHatSurface(tint: viewModel.weatherIconColor, cornerRadius: 26, prominence: 0.88)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weatherAccessibilityLabel)
        .accessibilityValue(weatherAccessibilityValue)
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
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cloud.fill")
                .font(AppFontStyle.title2.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)
                .background(.secondary.opacity(0.10), in: .circle)
                .accessibilityHidden(true)

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
        .padding(.vertical, 2)
    }

    // MARK: - Active Reminders Section

    private var readyNowSection: some View {
        SunHatCardSection(
            title: String(localized: "Ready Now", comment: "Dashboard section title for tasks matching the current forecast"),
            systemImage: "checkmark.circle.fill",
            subtitle: String(localized: "Tasks matching the current forecast", comment: "Dashboard section subtitle for the Ready Now card"),
            tint: .green
        ) {
            if viewModel.activeReminders.isEmpty {
                SunHatEmptyState(
                    title: String(localized: "No Tasks Yet", comment: "Empty state title when the user has no weather tasks"),
                    message: String(localized: "Create a weather task and SunHat will watch for matching conditions.", comment: "Empty state message when the user has no weather tasks"),
                    systemImage: "bell.slash"
                )
            } else if viewModel.activeAlerts.isEmpty {
                SunHatEmptyState(
                    title: String(localized: "Nothing Ready Right Now", comment: "Empty state title when no active tasks currently match the weather"),
                    message: String(localized: "SunHat is still watching your active tasks and will notify you when the weather matches.", comment: "Empty state message when no active tasks currently match the weather"),
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
            title: String(localized: "Watching", comment: "Dashboard section title for the list of active weather tasks"),
            systemImage: "bell.badge.fill",
            subtitle: String(localized: "\(viewModel.activeReminders.count) active task\(viewModel.activeReminders.count == 1 ? "" : "s")", comment: "Dashboard subtitle showing the count of active weather tasks being watched"),
            tint: .accentColor
        ) {
            if viewModel.activeReminders.isEmpty {
                SunHatEmptyState(
                    title: String(localized: "No Active Tasks", comment: "Empty state title when the user has no active weather tasks"),
                    message: String(localized: "Create a weather task and SunHat will watch for matching conditions.", comment: "Empty state message when the user has no active weather tasks"),
                    systemImage: "list.bullet.clipboard"
                )
                .padding(.vertical, 4)
            } else {
                LazyVStack(spacing: 12) {
                    SwiftUI.ForEach(Array(viewModel.activeReminders.prefix(3)), id: \.id) { reminder in
                        ActiveReminderCard(reminder: reminder, weatherData: viewModel.currentWeatherData)
                    }

                    if viewModel.activeReminders.count > 3 {
                        Button {
                            NotificationCenter.default.post(name: .sunHatShowRemindersTab, object: nil)
                        } label: {
                            Text("View All \(viewModel.activeReminders.count) Tasks", comment: "Button under the dashboard's truncated task list; opens the Reminders tab")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
    }
    
    private var detailsTransition: AnyTransition {
        SunHatMotion.transition(reduceMotion: reduceMotion)
    }

    private var weatherAccessibilityLabel: String {
        guard viewModel.hasWeatherData else {
            return String(localized: "Weather unavailable for \(viewModel.currentLocationName)", comment: "Accessibility label when weather data could not be loaded for the current location")
        }

        return String(localized: "Current weather for \(viewModel.currentLocationName): \(viewModel.currentTemperatureDisplay) degrees, feels like \(viewModel.feelsLikeTemperatureDisplay) degrees, \(viewModel.weatherDescription)", comment: "Accessibility label summarizing the current weather for the dashboard's weather card")
    }

    private var weatherAccessibilityValue: String {
        guard viewModel.hasWeatherData else {
            return String(localized: "Pull down to refresh when weather access is available", comment: "Accessibility value hint shown when weather data isn't available yet")
        }

        return String(localized: "High \(viewModel.highTemperatureDisplay) degrees, low \(viewModel.lowTemperatureDisplay) degrees, wind \(viewModel.windSpeedDisplay)", comment: "Accessibility value with high/low temperature and wind speed for the dashboard's weather card")
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
