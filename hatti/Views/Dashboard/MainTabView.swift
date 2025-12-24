//
//  MainTabView.swift
//  hatti
//
//  Created by Wesley Keetch on 12/23/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Active Reminders
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            // All Reminders Tab
            AllRemindersTabView()
                .tabItem {
                    Label("Reminders", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .tag(1)

            // Weather Tab
            WeatherTabView()
                .tabItem {
                    Label("Weather", systemImage: selectedTab == 2 ? "cloud.sun.fill" : "cloud.sun")
                }
                .tag(2)

            // Settings Tab
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}

// MARK: - Home Tab View

struct HomeTabView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingQuickCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with liquid glass effect
                liquidGlassBackground
                    .ignoresSafeArea()

                // Main content
                RefreshableScrollView {
                    await viewModel.refreshWeatherData()
                } content: {
                    LazyVStack(spacing: 20) {
                        // Current temperature widget with glass morphism
                        currentTemperatureCard
                            .padding(.top, 8)

                        // Weather alerts (if any)
                        if !viewModel.activeAlerts.isEmpty {
                            weatherAlertsCard
                        }

                        // Active reminders section
                        activeRemindersCard

                        // 7-day forecast preview
                        forecastPreviewCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Space for FAB
                }

                // Floating Action Button with liquid glass effect
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton {
                            showingQuickCreate = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 34)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        if let location = viewModel.currentLocationName {
                            Text(location)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingQuickCreate) {
                QuickCreateReminderView()
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
            }
        }
    }

    // MARK: - Liquid Glass Background

    private var liquidGlassBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colorScheme == .dark ? [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ] : [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.90, green: 0.94, blue: 0.98),
                    Color(red: 0.95, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated floating orbs for liquid effect
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: geometry.size.width * 0.7, y: geometry.size.height * 0.2)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width * 0.1, y: geometry.size.height * 0.6)
                }
            }
        }
    }

    // MARK: - Glass Morphism Card Modifier

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        colorScheme == .dark ?
                        Color.white.opacity(0.05) :
                        Color.white.opacity(0.7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                colorScheme == .dark ?
                                Color.white.opacity(0.1) :
                                Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
    }

    // MARK: - Current Temperature Card

    private var currentTemperatureCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        if let temp = viewModel.currentTemperature {
                            Text("\(Int(temp))°")
                                .font(.system(size: 56, weight: .thin, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            ProgressView()
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        if let condition = viewModel.currentCondition {
                            Image(systemName: condition.iconName)
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolEffect(.bounce, value: viewModel.currentTemperature)
                        }

                        if let feelsLike = viewModel.feelsLikeTemperature {
                            Text("Feels like \(Int(feelsLike))°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let description = viewModel.weatherDescription {
                    Text(description.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                // Mini forecast
                HStack(spacing: 16) {
                    if let high = viewModel.todayHigh, let low = viewModel.todayLow {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(Int(high))°")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(Int(low))°")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    Spacer()

                    if let humidity = viewModel.humidity {
                        HStack(spacing: 4) {
                            Image(systemName: "humidity.fill")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                            Text("\(humidity)%")
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(20)
        }
    }

    // MARK: - Weather Alerts Card

    private var weatherAlertsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Weather Alerts")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(viewModel.activeAlerts.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                        )
                }

                ForEach(viewModel.activeAlerts.prefix(2), id: \.id) { alert in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(alert.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Active Reminders Card

    private var activeRemindersCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Active Tasks")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    if !viewModel.activeReminders.isEmpty {
                        Text("\(viewModel.activeReminders.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }
                }

                if viewModel.activeReminders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.badge.questionmark.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.6), .cyan.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("No Active Tasks")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Create your first weather-triggered reminder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showingQuickCreate = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Task")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(viewModel.activeReminders.prefix(3)) { reminder in
                        ActiveReminderRow(reminder: reminder)
                    }

                    if viewModel.activeReminders.count > 3 {
                        NavigationLink {
                            AllRemindersView()
                        } label: {
                            HStack {
                                Text("View all \(viewModel.activeReminders.count) tasks")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Forecast Preview Card

    private var forecastPreviewCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("7-Day Forecast")
                    .font(.headline)
                    .fontWeight(.bold)

                // Simple forecast preview
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<7) { day in
                            VStack(spacing: 8) {
                                Text(dayLabel(for: day))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                Image(systemName: "cloud.sun.fill")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.orange, .yellow],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                Text("72°")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 50)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func dayLabel(for offset: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = offset == 0 ? "'Today'" : "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Active Reminder Row

struct ActiveReminderRow: View {
    let reminder: WeatherReminder

    var body: some View {
        HStack(spacing: 12) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(reminder.activity.color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: reminder.activity.iconName)
                    .font(.body)
                    .foregroundColor(reminder.activity.color)
            }

            // Reminder details
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let condition = reminder.triggerCondition {
                    Text("When temp is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(reminder.isCurrentlyActive ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                // Glass background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)

                // Gradient overlay
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // Plus icon
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(FloatingActionButtonStyle())
    }
}

// MARK: - All Reminders Tab (Placeholder)

struct AllRemindersTabView: View {
    var body: some View {
        NavigationStack {
            AllRemindersView()
        }
    }
}

// MARK: - Weather Tab (Placeholder)

struct WeatherTabView: View {
    var body: some View {
        NavigationStack {
            WeatherView()
        }
    }
}

// MARK: - Settings Tab (Placeholder)

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}

// MARK: - Refreshable Scroll View

struct RefreshableScrollView<Content: View>: View {
    let action: () async -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            await action()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(for: WeatherReminder.self, inMemory: true)
}

#Preview("Dark Mode") {
    MainTabView()
        .modelContainer(for: WeatherReminder.self, inMemory: true)
        .preferredColorScheme(.dark)
}
