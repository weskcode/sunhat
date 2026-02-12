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

    @State private var showingQuickCreate = false
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
                        // Search bar
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Filter chips
                        filterChips
                            .padding(.horizontal, 16)

                        // Reminders grid
                        if filteredReminders.isEmpty {
                            // No results for search/filter
                            noResultsView
                                .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredReminders) { reminder in
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
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }

            // Floating Action Button
            if !reminders.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingQuickCreate = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(FloatingActionButtonStyle())
                        .padding(.trailing, 20)
                        .padding(.bottom, 34)
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
        .sheet(isPresented: $showingQuickCreate) {
            StreamlinedReminderCreationView()
        }
    }

    // MARK: - Liquid Glass Background

    private var liquidGlassBackground: some View {
        ZStack {
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

            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 55)
                        .offset(x: geometry.size.width * 0.75, y: geometry.size.height * 0.15)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.08), Color.cyan.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 45)
                        .offset(x: geometry.size.width * 0.1, y: geometry.size.height * 0.7)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search tasks...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            colorScheme == .dark ?
                            Color.white.opacity(0.1) :
                            Color.white.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: showingQuickCreate)
            }

            VStack(spacing: 12) {
                Text("No Tasks Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create your first weather-triggered task to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingQuickCreate = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Create Task")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            .buttonStyle(BounceButtonStyle())

            Spacer()
        }
        .padding()
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))

            Text("No Tasks Found")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Try adjusting your search or filter")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink {
            DetailedReminderView(reminder: reminder)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Activity icon
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: reminder.category.iconName)
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    // Title and description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.displayTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }
                }

                // Trigger condition
                if let condition = reminder.triggerCondition {
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("When temp is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(reminder.createdDate, format: .dateTime.month().day())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                colorScheme == .dark ?
                                Color.white.opacity(0.08) :
                                Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
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
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [.blue, .cyan],
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
