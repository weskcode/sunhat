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
                backgroundGradient
                    .ignoresSafeArea()

                WeatherConditionLayer(
                    condition: viewModel.weatherCondition,
                    reduceMotion: reduceMotion || !viewModel.hasWeatherData
                )
                .ignoresSafeArea()

                RefreshableScrollView {
                    await viewModel.refreshWeatherData()
                } content: {
                    LazyVStack(spacing: 20) {
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
        VStack(spacing: 0) {
            // Location and time
            HStack {
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

                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    Image(systemName: "chevron.down.circle.fill")
                        .font(AppFontStyle.title3.font)
                        .foregroundStyle(Color.accentColor)
                        .rotationEffect(.degrees(showingDetailedWeather ? 180 : 0))
                        .animation(.interpolatingSpring(duration: 0.3, bounce: 0.25), value: showingDetailedWeather)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            weatherSummaryContent
        }
        .glassEffect(in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 4) {
                    Text(viewModel.currentTemperatureDisplay)
                        .font(AppFont.system(size: dynamicTypeSize.isAccessibilitySize ? 64 : 72, weight: .thin))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("°")
                        .font(AppFont.system(size: 24, weight: .light))
                        .foregroundStyle(.primary)
                        .offset(y: 8)
                }

                Text("Feels like \(viewModel.feelsLikeTemperatureDisplay)°")
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 12) {
                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: viewModel.weatherIconName)
                        .font(AppFont.system(size: 44))
                        .foregroundStyle(viewModel.weatherIconColor)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.bounce, value: reduceMotion ? false : viewModel.hasWeatherData)
                        .contentTransition(.symbolEffect(.replace))

                    Text(viewModel.weatherDescription)
                        .font(AppFontStyle.caption.font)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("H: \(viewModel.highTemperatureDisplay)°")
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("L: \(viewModel.lowTemperatureDisplay)°")
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var unavailableWeatherSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 34, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text("Weather unavailable")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(viewModel.errorMessage ?? "Pull down to refresh once weather access is available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
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

    // MARK: - Computed Properties

    private var backgroundGradient: some View {
        Color(.systemBackground)
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

private struct DashboardMetricRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(AppFontStyle.title3.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(tint.opacity(0.12))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFontStyle.subheadline.font.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(primary)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Text(secondary)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(primary), \(secondary)")
    }
}
