//
//  WeatherReminder.swift
//  hatti
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
    
    var isCurrentlyActive: Bool {
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
    
    var canTrigger: Bool {
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
    
    var displayTitle: String {
        return title.isEmpty ? "Untitled Reminder" : title
    }
    
    var shortDescription: String {
        if !reminderDescription.isEmpty {
            return String(reminderDescription.prefix(100))
        } else if let condition = triggerCondition {
            return "When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature)°"
        } else {
            return "Weather reminder"
        }
    }
    
    var statusText: String {
        if !isActive {
            return "Inactive"
        } else if isPaused {
            return "Paused"
        } else if isCompleted {
            return "Completed"
        } else if let snoozedUntil = snoozedUntil, snoozedUntil > Date() {
            return "Snoozed"
        } else {
            return "Active"
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
        
        lastTriggered = Date()
        triggerCount += 1
        totalNotificationsSent += 1
        
        // Update consecutive trigger days
        if let lastTrigger = lastTriggered {
            let calendar = Calendar.current
            if calendar.isDate(lastTrigger, inSameDayAs: Date()) {
                consecutiveTriggerDays += 1
            } else {
                consecutiveTriggerDays = 1
            }
        }
        
        addHistoryEntry(.triggered, details: "Reminder triggered", weatherData: weatherData)
    }
    
    func complete() {
        isCompleted = true
        completedDate = Date()
        successfulCompletions += 1
        addHistoryEntry(.completed, details: "Reminder marked as complete")
    }
    
    func snooze(for hours: Int = 2) {
        snoozedUntil = Calendar.current.date(byAdding: .hour, value: hours, to: Date())
        lastUserInteraction = Date()
        addHistoryEntry(.snoozed, details: "Snoozed for \(hours) hours")
    }
    
    func skip() {
        skippedCount += 1
        lastUserInteraction = Date()
        addHistoryEntry(.skipped, details: "Reminder skipped by user")
    }
    
    func pause() {
        isPaused = true
        lastModified = Date()
        addHistoryEntry(.paused, details: "Reminder paused")
    }
    
    func resume() {
        isPaused = false
        snoozedUntil = nil
        lastModified = Date()
        addHistoryEntry(.resumed, details: "Reminder resumed")
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

enum ReminderCategory: String, Codable, CaseIterable {
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
        case .general: return "General"
        case .outdoor: return "Outdoor Activities"
        case .gardening: return "Gardening"
        case .exercise: return "Exercise & Fitness"
        case .maintenance: return "Home Maintenance"
        case .travel: return "Travel"
        case .health: return "Health & Wellness"
        case .sports: return "Sports"
        case .work: return "Work Related"
        case .seasonal: return "Seasonal Tasks"
        case .emergency: return "Emergency Preparedness"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
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

enum ReminderPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
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
        case .created: return "Created"
        case .triggered: return "Triggered"
        case .completed: return "Completed"
        case .snoozed: return "Snoozed"
        case .skipped: return "Skipped"
        case .paused: return "Paused"
        case .resumed: return "Resumed"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .notificationSent: return "Notification Sent"
        case .notificationFailed: return "Notification Failed"
        case .conditionMet: return "Condition Met"
        case .conditionNoLongerMet: return "Condition No Longer Met"
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

