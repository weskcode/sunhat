//
//  WeatherReminder.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData

@Model
final class WeatherReminder {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Basic reminder information
    var title: String = ""
    var reminderDescription: String = ""
    var category: ReminderCategory = ReminderCategory.general
    var priority: ReminderPriority = ReminderPriority.normal
    
    init(title: String = "", 
         reminderDescription: String = "",
         category: ReminderCategory = .general,
         priority: ReminderPriority = .normal) {
        self.title = title
        self.reminderDescription = reminderDescription
        self.category = category
        self.priority = priority
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    // State management
    var isActive: Bool = true
    var isCompleted: Bool = false
    var isPaused: Bool = false
    
    // Timing and lifecycle
    var createdDate: Date = Date()
    var lastTriggered: Date?
    var lastModified: Date = Date()
    var completedDate: Date?
    var scheduledStartDate: Date?
    var scheduledEndDate: Date?
    
    // Trigger tracking
    var triggerCount: Int = 0
    var maxTriggers: Int?
    var consecutiveTriggerDays: Int = 0
    var lastEvaluationDate: Date?
    var nextEvaluationDate: Date?
    
    // User interaction
    var lastUserInteraction: Date?
    var snoozedUntil: Date?
    var userNotes: String = ""
    var tags: [String] = []

    // Appearance chosen in the creation flow; nil falls back to the category's
    // defaults. Tint is stored as a stable ReminderTint raw value, not a
    // localized color name.
    var customIconName: String?
    var customTintName: String?

    var displayIconName: String {
        customIconName ?? category.iconName
    }
    
    // Success tracking
    var successfulCompletions: Int = 0
    var skippedCount: Int = 0
    var totalNotificationsSent: Int = 0
    
    // CloudKit sync optimization
    @Attribute(.externalStorage) var customReminderData: Data?
    var lastSyncDate: Date?
    var cloudKitRecordID: String?
    
    // Relationships
    var triggerCondition: TriggerCondition?
    var notificationConfig: NotificationConfig?
    var location: LocationData?
    var history: [ReminderHistory] = []
    
    init(
        id: UUID = UUID(),
        title: String = "",
        reminderDescription: String = "",
        category: ReminderCategory = .general,
        priority: ReminderPriority = .normal,
        isActive: Bool = true,
        isCompleted: Bool = false,
        isPaused: Bool = false,
        createdDate: Date = Date(),
        lastTriggered: Date? = nil,
        lastModified: Date = Date(),
        completedDate: Date? = nil,
        scheduledStartDate: Date? = nil,
        scheduledEndDate: Date? = nil,
        triggerCount: Int = 0,
        maxTriggers: Int? = nil,
        consecutiveTriggerDays: Int = 0,
        lastEvaluationDate: Date? = nil,
        nextEvaluationDate: Date? = nil,
        lastUserInteraction: Date? = nil,
        snoozedUntil: Date? = nil,
        userNotes: String = "",
        tags: [String] = [],
        successfulCompletions: Int = 0,
        skippedCount: Int = 0,
        totalNotificationsSent: Int = 0,
        customReminderData: Data? = nil,
        lastSyncDate: Date? = nil,
        cloudKitRecordID: String? = nil,
        triggerCondition: TriggerCondition? = nil,
        notificationConfig: NotificationConfig? = nil,
        location: LocationData? = nil,
        history: [ReminderHistory] = []
    ) {
        self.id = id
        self.title = title
        self.reminderDescription = reminderDescription
        self.category = category
        self.priority = priority
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.isPaused = isPaused
        self.createdDate = createdDate
        self.lastTriggered = lastTriggered
        self.lastModified = lastModified
        self.completedDate = completedDate
        self.scheduledStartDate = scheduledStartDate
        self.scheduledEndDate = scheduledEndDate
        self.triggerCount = triggerCount
        self.maxTriggers = maxTriggers
        self.consecutiveTriggerDays = consecutiveTriggerDays
        self.lastEvaluationDate = lastEvaluationDate
        self.nextEvaluationDate = nextEvaluationDate
        self.lastUserInteraction = lastUserInteraction
        self.snoozedUntil = snoozedUntil
        self.userNotes = userNotes
        self.tags = tags
        self.successfulCompletions = successfulCompletions
        self.skippedCount = skippedCount
        self.totalNotificationsSent = totalNotificationsSent
        self.customReminderData = customReminderData
        self.lastSyncDate = lastSyncDate
        self.cloudKitRecordID = cloudKitRecordID
        self.triggerCondition = triggerCondition
        self.notificationConfig = notificationConfig
        self.location = location
        self.history = history
    }
    
    init(title: String = "", 
         triggerCondition: TriggerCondition? = nil,
         isActive: Bool = true,
         location: LocationData? = nil,
         notificationSettings: NotificationConfig? = nil) {
        self.id = UUID()
        self.title = title
        self.triggerCondition = triggerCondition
        self.isActive = isActive
        self.createdDate = Date()
        self.location = location
        self.notificationConfig = notificationSettings
    }
    
    // Removed previous partial init
    
    nonisolated var isCurrentlyActive: Bool {
        guard isActive && !isCompleted && !isPaused else { return false }
        
        if let snoozedUntil = snoozedUntil, snoozedUntil > Date() {
            return false
        }
        
        if let startDate = scheduledStartDate, startDate > Date() {
            return false
        }
        
        if let endDate = scheduledEndDate, endDate < Date() {
            return false
        }
        
        if let maxTriggers = maxTriggers, triggerCount >= maxTriggers {
            return false
        }
        
        return true
    }
    
    nonisolated var canTrigger: Bool {
        guard isCurrentlyActive else { return false }
        
        // Check cooldown period
        if let lastTriggered = lastTriggered,
           let cooldownHours = notificationConfig?.cooldownPeriodHours,
           cooldownHours > 0 {
            let cooldownEnd = Calendar.current.date(byAdding: .hour, value: cooldownHours, to: lastTriggered)
            if let cooldownEnd = cooldownEnd, Date() < cooldownEnd {
                return false
            }
        }
        
        return true
    }
    
    nonisolated var displayTitle: String {
        return title.isEmpty ? String(localized: "Untitled Reminder", comment: "Fallback title when reminder has no title") : title
    }

    var shortDescription: String {
        if !reminderDescription.isEmpty {
            return String(reminderDescription.prefix(100))
        } else if let condition = triggerCondition {
            return String(localized: "When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature)°", comment: "Short description of a reminder's temperature trigger")
        } else {
            return String(localized: "Weather reminder", comment: "Fallback short description for a reminder")
        }
    }

    var statusText: String {
        if !isActive {
            return String(localized: "Inactive", comment: "Reminder status")
        } else if isPaused {
            return String(localized: "Paused", comment: "Reminder status")
        } else if isCompleted {
            return String(localized: "Completed", comment: "Reminder status")
        } else if let snoozedUntil = snoozedUntil, snoozedUntil > Date() {
            return String(localized: "Snoozed", comment: "Reminder status")
        } else {
            return String(localized: "Active", comment: "Reminder status")
        }
    }
    
    func addHistoryEntry(_ action: HistoryAction, details: String = "", weatherData: WeatherData? = nil) {
        let historyEntry = ReminderHistory(
            action: action,
            details: details,
            weatherConditions: weatherData?.weatherDescription ?? "",
            temperature: weatherData?.temperature
        )
        historyEntry.weatherReminder = self
        history.append(historyEntry)
        lastModified = Date()
    }
    
    func trigger(with weatherData: WeatherData? = nil) {
        guard canTrigger else { return }

        let now = Date()
        let calendar = Calendar.current

        if let previousTrigger = lastTriggered {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
            if let yesterday, calendar.isDate(previousTrigger, inSameDayAs: yesterday) {
                consecutiveTriggerDays += 1
            } else if !calendar.isDate(previousTrigger, inSameDayAs: now) {
                consecutiveTriggerDays = 1
            }
        } else {
            consecutiveTriggerDays = 1
        }

        lastTriggered = now
        triggerCount += 1
        totalNotificationsSent += 1
        
        addHistoryEntry(.triggered, details: String(localized: "Reminder triggered", comment: "Reminder history timeline entry"), weatherData: weatherData)
    }

    func complete() {
        isCompleted = true
        completedDate = Date()
        successfulCompletions += 1
        addHistoryEntry(.completed, details: String(localized: "Reminder marked as complete", comment: "Reminder history timeline entry"))
    }

    func snooze(for hours: Int = 2) {
        snoozedUntil = Calendar.current.date(byAdding: .hour, value: hours, to: Date())
        lastUserInteraction = Date()
        addHistoryEntry(.snoozed, details: String(localized: "Snoozed for \(hours) hours", comment: "Reminder history timeline entry"))
    }

    func skip() {
        skippedCount += 1
        lastUserInteraction = Date()
        addHistoryEntry(.skipped, details: String(localized: "Reminder skipped by user", comment: "Reminder history timeline entry"))
    }

    func pause() {
        isPaused = true
        lastModified = Date()
        addHistoryEntry(.paused, details: String(localized: "Reminder paused", comment: "Reminder history timeline entry"))
    }

    func resume() {
        isPaused = false
        snoozedUntil = nil
        lastModified = Date()
        addHistoryEntry(.resumed, details: String(localized: "Reminder resumed", comment: "Reminder history timeline entry"))
    }

    /// Deletes the reminder and records that are exclusively owned by it.
    /// LocationData is intentionally preserved because locations can be shared
    /// by multiple reminders and weather records.
    func deleteOwnedData(from modelContext: ModelContext) {
        if let triggerCondition {
            modelContext.delete(triggerCondition)
        }
        if let notificationConfig {
            modelContext.delete(notificationConfig)
        }
        for historyEntry in history {
            modelContext.delete(historyEntry)
        }
        modelContext.delete(self)
    }
}

@Model
final class ReminderHistory {
    @Attribute(.unique) var id: UUID = UUID()
    
    var timestamp: Date = Date()
    var action: HistoryAction = HistoryAction.created
    var details: String = ""
    var weatherConditionsAtTime: String = ""
    var temperatureAtTime: Double?
    var userResponse: UserResponse = UserResponse.none
    var responseTime: Date?
    
    init(action: HistoryAction = .created,
         details: String = "",
         weatherConditions: String = "",
         temperature: Double? = nil,
         userResponse: UserResponse = .none) {
        self.timestamp = Date()
        self.action = action
        self.details = details
        self.weatherConditionsAtTime = weatherConditions
        self.temperatureAtTime = temperature
        self.userResponse = userResponse
    }
    
    // Relationship
    var weatherReminder: WeatherReminder?
    
    init(
        action: HistoryAction = .created,
        details: String = "",
        weatherConditions: String = "",
        temperature: Double? = nil
    ) {
        self.action = action
        self.details = details
        self.weatherConditionsAtTime = weatherConditions
        self.temperatureAtTime = temperature
    }
    

}

enum ReminderCategory: String, Codable, CaseIterable, Sendable {
    case general = "general"
    case outdoor = "outdoor"
    case gardening = "gardening"
    case exercise = "exercise"
    case maintenance = "maintenance"
    case travel = "travel"
    case health = "health"
    case sports = "sports"
    case work = "work"
    case seasonal = "seasonal"
    case emergency = "emergency"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .general: return String(localized: "General", comment: "Reminder category name")
        case .outdoor: return String(localized: "Outdoor Activities", comment: "Reminder category name")
        case .gardening: return String(localized: "Gardening", comment: "Reminder category name")
        case .exercise: return String(localized: "Exercise & Fitness", comment: "Reminder category name")
        case .maintenance: return String(localized: "Home Maintenance", comment: "Reminder category name")
        case .travel: return String(localized: "Travel", comment: "Reminder category name")
        case .health: return String(localized: "Health & Wellness", comment: "Reminder category name")
        case .sports: return String(localized: "Sports", comment: "Reminder category name")
        case .work: return String(localized: "Work Related", comment: "Reminder category name")
        case .seasonal: return String(localized: "Seasonal Tasks", comment: "Reminder category name")
        case .emergency: return String(localized: "Emergency Preparedness", comment: "Reminder category name")
        case .custom: return String(localized: "Custom", comment: "Reminder category name")
        }
    }
    
    nonisolated var iconName: String {
        switch self {
        case .general: return "bell"
        case .outdoor: return "figure.hiking"
        case .gardening: return "leaf"
        case .exercise: return "figure.run"
        case .maintenance: return "house"
        case .travel: return "car"
        case .health: return "heart"
        case .sports: return "sportscourt"
        case .work: return "briefcase"
        case .seasonal: return "calendar"
        case .emergency: return "exclamationmark.triangle"
        case .custom: return "star"
        }
    }
}

enum ReminderPriority: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return String(localized: "Low", comment: "Reminder priority level")
        case .normal: return String(localized: "Normal", comment: "Reminder priority level")
        case .high: return String(localized: "High", comment: "Reminder priority level")
        case .urgent: return String(localized: "Urgent", comment: "Reminder priority level")
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }
}

enum HistoryAction: String, Codable, CaseIterable {
    case created = "created"
    case triggered = "triggered"
    case completed = "completed"
    case snoozed = "snoozed"
    case skipped = "skipped"
    case paused = "paused"
    case resumed = "resumed"
    case modified = "modified"
    case deleted = "deleted"
    case notificationSent = "notification_sent"
    case notificationFailed = "notification_failed"
    case conditionMet = "condition_met"
    case conditionNoLongerMet = "condition_no_longer_met"
    
    var displayName: String {
        switch self {
        case .created: return String(localized: "Created", comment: "Reminder history action label")
        case .triggered: return String(localized: "Triggered", comment: "Reminder history action label")
        case .completed: return String(localized: "Completed", comment: "Reminder history action label")
        case .snoozed: return String(localized: "Snoozed", comment: "Reminder history action label")
        case .skipped: return String(localized: "Skipped", comment: "Reminder history action label")
        case .paused: return String(localized: "Paused", comment: "Reminder history action label")
        case .resumed: return String(localized: "Resumed", comment: "Reminder history action label")
        case .modified: return String(localized: "Modified", comment: "Reminder history action label")
        case .deleted: return String(localized: "Deleted", comment: "Reminder history action label")
        case .notificationSent: return String(localized: "Notification Sent", comment: "Reminder history action label")
        case .notificationFailed: return String(localized: "Notification Failed", comment: "Reminder history action label")
        case .conditionMet: return String(localized: "Condition Met", comment: "Reminder history action label")
        case .conditionNoLongerMet: return String(localized: "Condition No Longer Met", comment: "Reminder history action label")
        }
    }
}

enum UserResponse: String, Codable, CaseIterable {
    case none = "none"
    case completed = "completed"
    case snoozed = "snoozed"
    case skipped = "skipped"
    case dismissed = "dismissed"
    case opened = "opened"
}
