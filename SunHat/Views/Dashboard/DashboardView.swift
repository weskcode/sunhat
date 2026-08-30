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
    @StateObject var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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
