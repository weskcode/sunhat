//
//  ReminderManagementViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CloudKit
import Combine
import os.log

@MainActor
final class ReminderManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var displayedReminders: [WeatherReminder] = []
    @Published var seasonalSections: [SeasonalArchiveSection] = []
    @Published var sectionCounts: [ManagementSection: Int] = [:]
    
    @Published var searchText = "" {
        didSet {
            applyFiltersAndSearch()
        }
    }
    
    @Published var sortOption: SortOption = .dateCreated {
        didSet {
            applyFiltersAndSearch()
        }
    }
    
    @Published var sortOrder: SortOrder = .descending {
        didSet {
            applyFiltersAndSearch()
        }
    }
    
    @Published var selectedCategories: Set<ReminderCategory> = [] {
        didSet {
            applyFiltersAndSearch()
        }
    }
    
    @Published var selectedStatuses: Set<ReminderStatus> = [] {
        didSet {
            applyFiltersAndSearch()
        }
    }
    
    @Published var temperatureRange: ClosedRange<Double> = 0...100 {
        didSet {
            applyFiltersAndSearch()
        }
    }
    
    @Published var canLoadMore = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var allReminders: [WeatherReminder] = []
    private var currentSection: ManagementSection = .active
    private var cancellables = Set<AnyCancellable>()
    private var triggeredHistoryOffset = 0
    private let triggeredHistoryLimit = 50
    
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "ReminderManagementViewModel")
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || !selectedStatuses.isEmpty || temperatureRange != 0...100
    }
    
    // MARK: - Public Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupBindings()
    }
    
    func loadReminders(for section: ManagementSection) {
        currentSection = section
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let reminders = try await fetchReminders(for: section)
                
                await MainActor.run {
                    allReminders = reminders
                    
                    if section == .archive {
                        organizeBySeasons(reminders)
                    } else {
                        applyFiltersAndSearch()
                    }
                    
                    updateSectionCounts()
                    isLoading = false
                }
                
                // Sync with CloudKit in background
                await syncWithCloudKit()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    logger.error("Failed to load reminders: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func refreshReminders(for section: ManagementSection) async {
        // Force refresh from CloudKit
        await syncWithCloudKit()
        loadReminders(for: section)
    }
    
    func loadMoreTriggeredHistory() {
        guard currentSection == .triggered, let modelContext = modelContext else { return }
        
        triggeredHistoryOffset += triggeredHistoryLimit
        
        Task {
            do {
                let additionalReminders = try await fetchTriggeredHistory(
                    offset: triggeredHistoryOffset,
                    limit: triggeredHistoryLimit
                )
                
                await MainActor.run {
                    allReminders.append(contentsOf: additionalReminders)
                    applyFiltersAndSearch()
                    canLoadMore = additionalReminders.count == triggeredHistoryLimit
                }
                
            } catch {
                logger.error("Failed to load more triggered history: \(error.localizedDescription)")
            }
        }
    }
    
    func updateReminderStatus(_ reminder: WeatherReminder, isActive: Bool) {
        guard let modelContext = modelContext else { return }
        
        reminder.isActive = isActive
        reminder.lastModified = Date()
        
        if !isActive {
            reminder.isPaused = true
        } else {
            reminder.isPaused = false
        }
        
        do {
            try modelContext.save()
            applyFiltersAndSearch()
            
            // Log the change
            reminder.addHistoryEntry(isActive ? .resumed : .paused)
            
        } catch {
            logger.error("Failed to update reminder status: \(error.localizedDescription)")
        }
    }
    
    func deleteReminder(_ reminder: WeatherReminder) {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(reminder)
        
        do {
            try modelContext.save()
            allReminders.removeAll { $0.id == reminder.id }
            applyFiltersAndSearch()
            
        } catch {
            logger.error("Failed to delete reminder: \(error.localizedDescription)")
        }
    }
    
    func duplicateReminder(_ reminder: WeatherReminder) {
        guard let modelContext = modelContext else { return }
        
        // Create a new reminder with the same properties
        let duplicate = WeatherReminder(
            title: "\(reminder.title) (Copy)",
            reminderDescription: reminder.reminderDescription,
            category: reminder.category
        )
        
        // Copy trigger condition
        if let originalCondition = reminder.triggerCondition {
            let newCondition = TriggerCondition(
                triggerType: originalCondition.triggerType,
                targetTemperature: originalCondition.targetTemperature,
                comparisonType: originalCondition.comparisonType
            )
            newCondition.temperatureTolerance = originalCondition.temperatureTolerance
            newCondition.useFeelsLike = originalCondition.useFeelsLike
            newCondition.minTemperature = originalCondition.minTemperature
            newCondition.maxTemperature = originalCondition.maxTemperature
            
            duplicate.triggerCondition = newCondition
        }
        
        // Copy notification config
        if let originalConfig = reminder.notificationConfig {
            let newConfig = NotificationConfig(
                title: originalConfig.title,
                message: originalConfig.message
            )
            newConfig.cooldownPeriodHours = originalConfig.cooldownPeriodHours
            
            duplicate.notificationConfig = newConfig
        }
        
        // Copy location
        if let originalLocation = reminder.location {
            let newLocation = LocationData(
                latitude: originalLocation.latitude,
                longitude: originalLocation.longitude,
                name: originalLocation.name,
                address: originalLocation.address
            )
            duplicate.location = newLocation
        }
        
        modelContext.insert(duplicate)
        
        do {
            try modelContext.save()
            loadReminders(for: currentSection)
            
        } catch {
            logger.error("Failed to duplicate reminder: \(error.localizedDescription)")
        }
    }
    
    func clearFilters() {
        selectedCategories.removeAll()
        selectedStatuses.removeAll()
        temperatureRange = 0...100
    }
    
    // MARK: - Bulk Operations
    
    func bulkActivate(_ reminderIds: Set<UUID>) {
        performBulkOperation(reminderIds) { reminder in
            reminder.isActive = true
            reminder.isPaused = false
            reminder.addHistoryEntry(.resumed)
        }
    }
    
    func bulkDeactivate(_ reminderIds: Set<UUID>) {
        performBulkOperation(reminderIds) { reminder in
            reminder.isActive = false
            reminder.isPaused = true
            reminder.addHistoryEntry(.paused)
        }
    }
    
    func bulkDelete(_ reminderIds: Set<UUID>) {
        guard let modelContext = modelContext else { return }
        
        let remindersToDelete = allReminders.filter { reminderIds.contains($0.id) }
        
        for reminder in remindersToDelete {
            modelContext.delete(reminder)
        }
        
        do {
            try modelContext.save()
            allReminders.removeAll { reminderIds.contains($0.id) }
            applyFiltersAndSearch()
            
        } catch {
            logger.error("Failed to bulk delete reminders: \(error.localizedDescription)")
        }
    }
    
    func bulkDuplicate(_ reminderIds: Set<UUID>) {
        let remindersToDuplicate = allReminders.filter { reminderIds.contains($0.id) }
        
        for reminder in remindersToDuplicate {
            duplicateReminder(reminder)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-refresh every 5 minutes to sync changes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.syncWithCloudKit()
                }
            }
            .store(in: &cancellables)
    }
    
    private func fetchReminders(for section: ManagementSection) async throws -> [WeatherReminder] {
        guard let modelContext = modelContext else { return [] }
        
        let predicate: Predicate<WeatherReminder>
        let sortDescriptors: [SortDescriptor<WeatherReminder>]
        
        switch section {
        case .active:
            predicate = #Predicate { reminder in
                reminder.isActive && !reminder.isCompleted
            }
            sortDescriptors = [
                SortDescriptor(\WeatherReminder.priority.sortOrder),
                SortDescriptor(\WeatherReminder.createdDate, order: .reverse)
            ]
            
        case .triggered:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            predicate = #Predicate { reminder in
                reminder.lastTriggered != nil && reminder.lastTriggered! >= thirtyDaysAgo
            }
            sortDescriptors = [SortDescriptor(\WeatherReminder.lastTriggered, order: .reverse)]
            
        case .archive:
            predicate = #Predicate { reminder in
                reminder.isCompleted || (!reminder.isActive && reminder.isPaused)
            }
            sortDescriptors = [SortDescriptor(\WeatherReminder.completedDate, order: .reverse)]
        }
        
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: sortDescriptors
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchTriggeredHistory(offset: Int, limit: Int) async throws -> [WeatherReminder] {
        guard let modelContext = modelContext else { return [] }
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let predicate = #Predicate<WeatherReminder> { reminder in
            reminder.lastTriggered != nil && reminder.lastTriggered! >= thirtyDaysAgo
        }
        
        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\WeatherReminder.lastTriggered, order: .reverse)]
        )
        
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func applyFiltersAndSearch() {
        var filtered = allReminders
        
        // Apply search filter
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let searchTerm = searchText.lowercased()
            filtered = filtered.filter { reminder in
                reminder.title.lowercased().contains(searchTerm) ||
                reminder.reminderDescription.lowercased().contains(searchTerm) ||
                reminder.category.displayName.lowercased().contains(searchTerm)
            }
        }
        
        // Apply category filter
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { reminder in
                selectedCategories.contains(reminder.category)
            }
        }
        
        // Apply status filter
        if !selectedStatuses.isEmpty {
            filtered = filtered.filter { reminder in
                let status = getReminderStatus(reminder)
                return selectedStatuses.contains(status)
            }
        }
        
        // Apply temperature filter
        if temperatureRange != 0...100 {
            filtered = filtered.filter { reminder in
                guard let condition = reminder.triggerCondition else { return false }
                return temperatureRange.contains(condition.targetTemperature)
            }
        }
        
        // Apply sorting
        filtered = applySorting(to: filtered)
        
        displayedReminders = filtered
    }
    
    private func applySorting(to reminders: [WeatherReminder]) -> [WeatherReminder] {
        let sorted: [WeatherReminder]
        
        switch sortOption {
        case .dateCreated:
            sorted = reminders.sorted { $0.createdDate < $1.createdDate }
        case .dateModified:
            sorted = reminders.sorted { $0.lastModified < $1.lastModified }
        case .temperature:
            sorted = reminders.sorted { 
                ($0.triggerCondition?.targetTemperature ?? 0) < 
                ($1.triggerCondition?.targetTemperature ?? 0)
            }
        case .activity:
            sorted = reminders.sorted { $0.category.displayName < $1.category.displayName }
        case .priority:
            sorted = reminders.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
        case .triggerCount:
            sorted = reminders.sorted { $0.triggerCount < $1.triggerCount }
        }
        
        return sortOrder == .ascending ? sorted : sorted.reversed()
    }
    
    private func organizeBySeasons(_ reminders: [WeatherReminder]) {
        let grouped = Dictionary(grouping: reminders) { reminder in
            let date = reminder.completedDate ?? reminder.lastModified
            return Season.from(date: date)
        }
        
        seasonalSections = grouped.map { season, reminders in
            SeasonalArchiveSection(season: season, reminders: reminders.sorted { $0.lastModified > $1.lastModified })
        }.sorted { $0.season.rawValue < $1.season.rawValue }
    }
    
    private func updateSectionCounts() {
        Task {
            guard let modelContext = modelContext else { return }
            
            do {
                // Count active reminders
                let activeDescriptor = FetchDescriptor<WeatherReminder>(
                    predicate: #Predicate { reminder in
                        reminder.isActive && !reminder.isCompleted
                    }
                )
                let activeCount = try modelContext.fetchCount(activeDescriptor)
                
                // Count triggered reminders (last 30 days)
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                let triggeredDescriptor = FetchDescriptor<WeatherReminder>(
                    predicate: #Predicate { reminder in
                        reminder.lastTriggered != nil && reminder.lastTriggered! >= thirtyDaysAgo
                    }
                )
                let triggeredCount = try modelContext.fetchCount(triggeredDescriptor)
                
                // Count archived reminders
                let archivedDescriptor = FetchDescriptor<WeatherReminder>(
                    predicate: #Predicate { reminder in
                        reminder.isCompleted || (!reminder.isActive && reminder.isPaused)
                    }
                )
                let archivedCount = try modelContext.fetchCount(archivedDescriptor)
                
                await MainActor.run {
                    sectionCounts = [
                        .active: activeCount,
                        .triggered: triggeredCount,
                        .archive: archivedCount
                    ]
                }
                
            } catch {
                logger.error("Failed to update section counts: \(error.localizedDescription)")
            }
        }
    }
    
    private func performBulkOperation(_ reminderIds: Set<UUID>, operation: (WeatherReminder) -> Void) {
        guard let modelContext = modelContext else { return }
        
        let remindersToUpdate = allReminders.filter { reminderIds.contains($0.id) }
        
        for reminder in remindersToUpdate {
            operation(reminder)
            reminder.lastModified = Date()
        }
        
        do {
            try modelContext.save()
            applyFiltersAndSearch()
            
        } catch {
            logger.error("Failed to perform bulk operation: \(error.localizedDescription)")
        }
    }
    
    private func getReminderStatus(_ reminder: WeatherReminder) -> ReminderStatus {
        if reminder.isCompleted {
            return .completed
        } else if !reminder.isActive {
            return .inactive
        } else if reminder.isPaused {
            return .paused
        } else if let snoozedUntil = reminder.snoozedUntil, snoozedUntil > Date() {
            return .snoozed
        } else {
            return .active
        }
    }
    
    private func syncWithCloudKit() async {
        // CloudKit sync is handled automatically by SwiftData
        // but we can implement custom sync logic here if needed
        logger.info("Syncing reminders with CloudKit...")
        
        // Custom sync logic would go here
        // For now, SwiftData handles the sync automatically
    }
}

// MARK: - Supporting Enums

enum SortOption: String, CaseIterable {
    case dateCreated = "dateCreated"
    case dateModified = "dateModified"
    case temperature = "temperature"
    case activity = "activity"
    case priority = "priority"
    case triggerCount = "triggerCount"
    
    var displayName: String {
        switch self {
        case .dateCreated: return "Date Created"
        case .dateModified: return "Last Modified"
        case .temperature: return "Temperature"
        case .activity: return "Activity"
        case .priority: return "Priority"
        case .triggerCount: return "Trigger Count"
        }
    }
    
    var icon: String {
        switch self {
        case .dateCreated: return "calendar.badge.plus"
        case .dateModified: return "calendar.badge.clock"
        case .temperature: return "thermometer"
        case .activity: return "heart"
        case .priority: return "exclamationmark"
        case .triggerCount: return "number"
        }
    }
}

enum SortOrder: String, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
    
    var icon: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

enum ReminderStatus: String, CaseIterable {
    case active = "active"
    case inactive = "inactive"
    case paused = "paused"
    case snoozed = "snoozed"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .paused: return "Paused"
        case .snoozed: return "Snoozed"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "play.circle"
        case .inactive: return "stop.circle"
        case .paused: return "pause.circle"
        case .snoozed: return "zzz"
        case .completed: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .gray
        case .paused: return .orange
        case .snoozed: return .blue
        case .completed: return .purple
        }
    }
}