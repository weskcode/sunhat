//
//  AllRemindersView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct AllRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \WeatherReminder.createdDate, order: .reverse) private var reminders: [WeatherReminder]

    @State private var searchText = ""
    @State private var selectedFilter: ReminderFilter = .all
    @State private var deletionErrorMessage: String?

    enum ReminderFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
    }

    var filteredReminders: [WeatherReminder] {
        var filtered = reminders

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { reminder in
                reminder.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                reminder.reminderDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.isCurrentlyActive }
        case .inactive:
            filtered = filtered.filter { !$0.isCurrentlyActive }
        }

        return filtered
    }

    private var activeReminders: [WeatherReminder] {
        reminders.filter { $0.isCurrentlyActive }
    }

    private var inactiveReminders: [WeatherReminder] {
        reminders.filter { !$0.isCurrentlyActive }
    }

    private var shouldShowSearchAndFilters: Bool {
        reminders.count > 8
    }

    private var isSearchingOrFiltering: Bool {
        !searchText.isEmpty || selectedFilter != .all
    }

    var body: some View {
        ZStack {
            liquidGlassBackground
                .ignoresSafeArea()

            if reminders.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        remindersHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        if shouldShowSearchAndFilters {
                            searchBar
                                .padding(.horizontal, 16)

                            filterChips
                                .padding(.horizontal, 16)
                        }

                        remindersContent
                            .padding(.horizontal, 16)
                            .padding(.bottom, 132)
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .alert(
            "Couldn't Delete Task",
            isPresented: Binding(
                get: { deletionErrorMessage != nil },
                set: { if !$0 { deletionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "Please try again.")
        }
    }

    // MARK: - Liquid Glass Background

    private var liquidGlassBackground: some View {
        SunHatAtmosphereBackground(
            condition: .partlyCloudy,
            intensity: 0.58,
            showsConditionAccent: false
        )
    }

    private var remindersHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather Tasks")
                    .font(AppFontStyle.title2.font)
                    .foregroundStyle(.primary)

                Text("\(activeReminders.count) watching • \(inactiveReminders.count) paused")
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            SunHatStatusPill(
                text: "\(reminders.count)",
                systemImage: "list.bullet.rectangle",
                tint: .accentColor
            )
        }
        .padding(18)
        .sunHatSurface(tint: .accentColor, cornerRadius: 24, prominence: 0.78)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search tasks...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search tasks")

            if !searchText.isEmpty {
                Button {
                    withAnimation(SunHatMotion.cardToggle(reduceMotion: reduceMotion)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(SunHatPressButtonStyle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(14)
        .sunHatSurface(tint: .accentColor, cornerRadius: 18, prominence: 0.55)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(ReminderFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(SunHatMotion.cardToggle(reduceMotion: reduceMotion)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var remindersContent: some View {
        if shouldShowSearchAndFilters && isSearchingOrFiltering {
            if filteredReminders.isEmpty {
                noResultsView
                    .padding(.top, 60)
            } else {
                reminderSection(title: "Results", reminders: filteredReminders)
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if !activeReminders.isEmpty {
                    reminderSection(title: "Active", reminders: activeReminders)
                }

                if !inactiveReminders.isEmpty {
                    reminderSection(title: "Inactive", reminders: inactiveReminders)
                }
            }
        }
    }

    private func reminderSection(title: String, reminders: [WeatherReminder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: title == "Active" ? "dot.radiowaves.left.and.right" : "pause.circle")
                .font(AppFontStyle.headline.font)
                .foregroundStyle(.primary)

            LazyVStack(spacing: 12) {
                ForEach(reminders) { reminder in
                    ReminderGlassCard(reminder: reminder)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await deleteReminder(reminder) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer(minLength: 0)

            SunHatEmptyState(
                title: "No Tasks Yet",
                message: "Create your first weather-triggered task to start watching the weather.",
                systemImage: "list.bullet.clipboard"
            )
            .sunHatSurface(tint: .accentColor, cornerRadius: 24, prominence: 0.70)

            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        SunHatEmptyState(
            title: "No Tasks Found",
            message: "Try a different search or switch back to all tasks.",
            systemImage: "magnifyingglass"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helper Methods

    private func deleteReminder(_ reminder: WeatherReminder) async {
        let reminderId = reminder.id
        withAnimation {
            reminder.deleteOwnedData(from: modelContext)
        }

        do {
            try modelContext.save()
            SunHatSearchIndexer.deleteReminder(id: reminderId)
            await TriggerNotificationManager.shared.cancelNotifications(for: reminderId)
        } catch {
            modelContext.rollback()
            deletionErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AllRemindersView()
    }
    .modelContainer(for: [WeatherReminder.self], inMemory: true)
}

#Preview("Dark Mode") {
    NavigationStack {
        AllRemindersView()
    }
    .modelContainer(for: [WeatherReminder.self], inMemory: true)
    .preferredColorScheme(.dark)
}

#Preview("With Data") {
    let container = try! ModelContainer(for: WeatherReminder.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    // Add sample data
    let sampleReminder = WeatherReminder(
        title: "Morning Jog",
        reminderDescription: "Perfect weather for running",
        category: .exercise
    )
    container.mainContext.insert(sampleReminder)

    return NavigationStack {
        AllRemindersView()
    }
    .modelContainer(container)
}
