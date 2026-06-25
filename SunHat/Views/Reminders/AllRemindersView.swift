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
    @Query(sort: \WeatherReminder.createdDate, order: .reverse) private var reminders: [WeatherReminder]

    @State private var searchText = ""
    @State private var selectedFilter: ReminderFilter = .all

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
            // Liquid glass background
            liquidGlassBackground
                .ignoresSafeArea()

            if reminders.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Reminders list
                ScrollView {
                    VStack(spacing: 12) {
                        if shouldShowSearchAndFilters {
                            searchBar
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            filterChips
                                .padding(.horizontal, 16)
                        }

                        remindersContent
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("All Tasks")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Liquid Glass Background

    private var liquidGlassBackground: some View {
        Color(.systemBackground)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search tasks...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 12))
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVStack(spacing: 12) {
                ForEach(reminders) { reminder in
                    ReminderGlassCard(reminder: reminder)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteReminder(reminder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tasks Yet", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Create your first weather-triggered task to get started.")
        }
        .padding()
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Tasks Found", systemImage: "magnifyingglass")
        } description: {
            Text("Try adjusting your search or filter")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helper Methods

    private func deleteReminder(_ reminder: WeatherReminder) {
        withAnimation {
            modelContext.delete(reminder)
        }
    }
}

// MARK: - Reminder Glass Card

struct ReminderGlassCard: View {
    let reminder: WeatherReminder

    var body: some View {
        NavigationLink {
            DetailedReminderView(reminder: reminder)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Activity icon
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: reminder.category.iconName)
                            .font(AppFontStyle.title3.font)
                            .foregroundStyle(Color.accentColor)
                    }

                    // Title and description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.displayTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Status indicator
                    VStack(spacing: 4) {
                        Circle()
                            .fill(reminder.isCurrentlyActive ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text(reminder.isCurrentlyActive ? "Active" : "Waiting")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Trigger condition
                if let condition = reminder.triggerCondition {
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Text("When temp is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(reminder.createdDate, format: .dateTime.month().day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [
                                    colorScheme == .dark ?
                                    Color.white.opacity(0.05) :
                                    Color.white.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? Color.clear :
                                    (colorScheme == .dark ?
                                     Color.white.opacity(0.1) :
                                     Color.white.opacity(0.3)),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
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
