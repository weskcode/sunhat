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
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 16)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: cardsVisible)

                            if showingDetailedWeather {
                                detailedWeatherMetrics
                                    .transition(detailsTransition)
                            }

                            if !viewModel.activeReminders.isEmpty {
                                readyNowSection
                                    .transition(detailsTransition)
                                    .opacity(cardsVisible ? 1 : 0)
                                    .offset(y: cardsVisible ? 0 : 16)
                                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.08), value: cardsVisible)
                            }

                            activeRemindersSection
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 16)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.15), value: cardsVisible)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
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
        .buttonStyle(.plain)
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
                        .symbolEffect(.bounce, value: viewModel.hasWeatherData)
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
            Image(systemName: "cloud.slash.fill")
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
        VStack(alignment: .leading, spacing: 12) {
            Label("Ready Now", systemImage: "checkmark.circle.fill")
                .font(AppFontStyle.headline.font)
                .foregroundStyle(.primary)

            if viewModel.activeReminders.isEmpty {
                Text("Create a weather task and SunHat will watch for matching conditions.")
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.activeAlerts.isEmpty {
                Text("No tasks match the weather right now. SunHat is still watching.")
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
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
        .glassEffect(in: .rect(cornerRadius: 16))
    }
    
    private var activeRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Watching", systemImage: "bell.badge.fill")
                    .font(AppFontStyle.headline.font)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button("View All") {
                    activeSheet = .allReminders
                }
                .font(AppFontStyle.callout.font)
                .foregroundStyle(Color.accentColor)
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
        .glassEffect(in: .rect(cornerRadius: 16))
    }
    
    private var cardToggleAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.14) : .smooth(duration: 0.28)
    }

    private var detailsTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity)
    }

    private var weatherAccessibilityLabel: String {
        guard viewModel.hasWeatherData else {
            return "Weather unavailable for \(viewModel.currentLocationName)"
        }

        return "Current weather for \(viewModel.currentLocationName): \(viewModel.currentTemperatureDisplay) degrees, feels like \(viewModel.feelsLikeTemperatureDisplay) degrees, \(viewModel.weatherDescription)"
    }

    // MARK: - Detailed Weather Metrics

    private var detailedWeatherMetrics: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Label("More Details", systemImage: "info.circle.fill")
                    .font(AppFontStyle.headline.font)
                    .foregroundStyle(.primary)

                Spacer()

                Button("Less") {
                    withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0.2)) {
                        showingDetailedWeather = false
                    }
                }
                .font(AppFontStyle.callout.font)
                .foregroundStyle(Color.accentColor)
            }

            // Additional context about weather
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "thermometer.medium")
                        .font(AppFontStyle.title2.font)
                        .foregroundStyle(.orange)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature Details")
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)

                        Text("Current: \(viewModel.currentTemperatureDisplay)° • Feels like: \(viewModel.feelsLikeTemperatureDisplay)°")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)

                        Text("High: \(viewModel.highTemperatureDisplay)° • Low: \(viewModel.lowTemperatureDisplay)°")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "cloud.fill")
                        .font(AppFontStyle.title2.font)
                        .foregroundStyle(.blue)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.weatherDescription)
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "humidity.fill")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.cyan)
                                Text("\(viewModel.humidity)%")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.green)
                                Text(viewModel.windSpeedDisplay)
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(AppFontStyle.title2.font)
                        .foregroundStyle(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visibility & UV")
                            .font(AppFontStyle.subheadline.font)
                            .fontWeight(.medium)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("Visibility:")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.secondary)
                                Text(viewModel.visibilityDisplay)
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.primary)
                            }

                            HStack(spacing: 4) {
                                Text("UV Index:")
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.secondary)
                                Text(viewModel.uvIndexDisplay)
                                    .font(AppFontStyle.caption.font)
                                    .foregroundStyle(.primary)
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
        .glassEffect(in: .rect(cornerRadius: 16))
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
