//
//  ReminderManagementView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct ReminderManagementView: View {
    @StateObject private var viewModel = ReminderManagementViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText = ""
    @State private var selectedReminders = Set<UUID>()
    @State private var isSelectionMode = false
    @State private var showingCreateReminder = false
    @State private var showingSortOptions = false
    @State private var showingFilterOptions = false
    @State private var selectedSection: ManagementSection = .active
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom segmented control for sections
                sectionSelector
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Search and filter bar
                searchAndFilterBar
                
                // Main content
                ZStack {
                    if viewModel.isLoading {
                        ProgressView("Loading reminders...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        mainContent
                    }
                }
            }
            .navigationTitle("Manage Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            exitSelectionMode()
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        Menu {
                            bulkActionMenu
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(selectedReminders.isEmpty)
                    } else {
                        HStack(spacing: 16) {
                            Button(action: {
                                showingSortOptions = true
                            }) {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            
                            Button(action: {
                                showingCreateReminder = true
                            }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateReminder) {
                ComprehensiveReminderCreationView()
            }
            .sheet(isPresented: $showingSortOptions) {
                SortOptionsView(
                    selectedSort: $viewModel.sortOption,
                    selectedOrder: $viewModel.sortOrder
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingFilterOptions) {
                FilterOptionsView(
                    selectedCategories: $viewModel.selectedCategories,
                    selectedStatuses: $viewModel.selectedStatuses,
                    temperatureRange: $viewModel.temperatureRange
                )
                .presentationDetents([.large])
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadReminders(for: selectedSection)
            }
            .onChange(of: selectedSection) { _, newSection in
                viewModel.loadReminders(for: newSection)
                exitSelectionMode()
            }
            .onChange(of: searchText) { _, newText in
                viewModel.searchText = newText
            }
        }
    }
    
    // MARK: - Section Selector
    
    private var sectionSelector: some View {
        HStack(spacing: 0) {
            ForEach(ManagementSection.allCases, id: \.self) { section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedSection = section
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.caption)
                            
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedSection == section ? .white : .blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSection == section ? Color.blue : Color.clear)
                        )
                        
                        if let count = viewModel.sectionCounts[section] {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if section != ManagementSection.allCases.last {
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search reminders...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
            
            // Filter button
            Button(action: {
                showingFilterOptions = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .foregroundColor(viewModel.hasActiveFilters ? .blue : .secondary)
                    
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Selection mode toggle
            Button(action: {
                toggleSelectionMode()
            }) {
                Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(isSelectionMode ? .blue : .secondary)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        Group {
            if viewModel.displayedReminders.isEmpty {
                emptyStateView
            } else {
                remindersList
            }
        }
    }
    
    // MARK: - Reminders List
    
    private var remindersList: some View {
        List {
            // Results summary
            if !searchText.isEmpty || viewModel.hasActiveFilters {
                Section {
                    HStack {
                        Text("\(viewModel.displayedReminders.count) reminders found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if viewModel.hasActiveFilters {
                            Button("Clear Filters") {
                                viewModel.clearFilters()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            
            // Reminders sections
            if selectedSection == .archive {
                // Seasonal archive organization
                ForEach(viewModel.seasonalSections, id: \.season) { section in
                    Section(section.season.displayName) {
                        ForEach(section.reminders, id: \.id) { reminder in
                            ReminderManagementRow(
                                reminder: reminder,
                                isSelected: selectedReminders.contains(reminder.id),
                                isSelectionMode: isSelectionMode,
                                onToggleSelection: {
                                    toggleSelection(for: reminder)
                                },
                                onToggleActive: { isActive in
                                    viewModel.updateReminderStatus(reminder, isActive: isActive)
                                }
                            )
                            .swipeActions(edge: .trailing) {
                                swipeActions(for: reminder)
                            }
                        }
                    }
                }
            } else {
                // Regular list for active/triggered sections
                ForEach(viewModel.displayedReminders, id: \.id) { reminder in
                    ReminderManagementRow(
                        reminder: reminder,
                        isSelected: selectedReminders.contains(reminder.id),
                        isSelectionMode: isSelectionMode,
                        onToggleSelection: {
                            toggleSelection(for: reminder)
                        },
                        onToggleActive: { isActive in
                            viewModel.updateReminderStatus(reminder, isActive: isActive)
                        }
                    )
                    .swipeActions(edge: .trailing) {
                        swipeActions(for: reminder)
                    }
                    .swipeActions(edge: .leading) {
                        Button(action: {
                            viewModel.duplicateReminder(reminder)
                        }) {
                            Image(systemName: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                }
            }
            
            // Load more button for triggered history
            if selectedSection == .triggered && viewModel.canLoadMore {
                Section {
                    Button("Load More History") {
                        viewModel.loadMoreTriggeredHistory()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await viewModel.refreshReminders(for: selectedSection)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: selectedSection.emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(selectedSection.emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(selectedSection.emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if selectedSection == .active {
                Button("Create Your First Reminder") {
                    showingCreateReminder = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    private func swipeActions(for reminder: WeatherReminder) -> some View {
        Button(action: {
            viewModel.deleteReminder(reminder)
        }) {
            Image(systemName: "trash")
        }
        .tint(.red)
        
        Button(action: {
            // Edit reminder - would navigate to edit view
            editReminder(reminder)
        }) {
            Image(systemName: "pencil")
        }
        .tint(.orange)
        
        if selectedSection != .triggered {
            Button(action: {
                viewModel.duplicateReminder(reminder)
            }) {
                Image(systemName: "plus.square.on.square")
            }
            .tint(.blue)
        }
    }
    
    // MARK: - Bulk Action Menu
    
    private var bulkActionMenu: some View {
        Group {
            Button(action: {
                viewModel.bulkActivate(selectedReminders)
                exitSelectionMode()
            }) {
                Label("Activate Selected", systemImage: "play.circle")
            }
            
            Button(action: {
                viewModel.bulkDeactivate(selectedReminders)
                exitSelectionMode()
            }) {
                Label("Deactivate Selected", systemImage: "pause.circle")
            }
            
            Button(action: {
                viewModel.bulkDuplicate(selectedReminders)
                exitSelectionMode()
            }) {
                Label("Duplicate Selected", systemImage: "plus.square.on.square")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                viewModel.bulkDelete(selectedReminders)
                exitSelectionMode()
            }) {
                Label("Delete Selected", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedReminders.removeAll()
            }
        }
    }
    
    private func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode = false
            selectedReminders.removeAll()
        }
    }
    
    private func toggleSelection(for reminder: WeatherReminder) {
        if selectedReminders.contains(reminder.id) {
            selectedReminders.remove(reminder.id)
        } else {
            selectedReminders.insert(reminder.id)
        }
    }
    
    private func editReminder(_ reminder: WeatherReminder) {
        // This would navigate to the edit view
        // For now, just show a placeholder action
        print("Edit reminder: \(reminder.displayTitle)")
    }
}

// MARK: - Management Sections

enum ManagementSection: String, CaseIterable {
    case active = "active"
    case triggered = "triggered"
    case archive = "archive"
    
    var title: String {
        switch self {
        case .active: return "Active"
        case .triggered: return "History"
        case .archive: return "Archive"
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "play.circle"
        case .triggered: return "clock.arrow.circlepath"
        case .archive: return "archivebox"
        }
    }
    
    var emptyStateIcon: String {
        switch self {
        case .active: return "bell.slash"
        case .triggered: return "clock"
        case .archive: return "archivebox"
        }
    }
    
    var emptyStateTitle: String {
        switch self {
        case .active: return "No Active Reminders"
        case .triggered: return "No Recent Activity"
        case .archive: return "No Archived Reminders"
        }
    }
    
    var emptyStateMessage: String {
        switch self {
        case .active: return "Create weather reminders to get notifications when conditions are perfect for your activities."
        case .triggered: return "Your triggered reminders from the last 30 days will appear here."
        case .archive: return "Completed and old reminders are organized here by season."
        }
    }
}

// MARK: - Seasonal Archive Section

struct SeasonalArchiveSection {
    let season: Season
    let reminders: [WeatherReminder]
}

enum Season: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .fall: return "Fall"
        case .winter: return "Winter"
        case .unknown: return "Other"
        }
    }
    
    static func from(date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .fall
        case 12, 1, 2: return .winter
        default: return .unknown
        }
    }
}

// MARK: - Preview

#Preview {
    ReminderManagementView()
        .modelContainer(for: [
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            ReminderHistory.self,
            NotificationConfig.self
        ], inMemory: true)
}