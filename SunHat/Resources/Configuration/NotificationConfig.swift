//
//  NotificationConfig.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import UserNotifications

@Model
final class NotificationConfig {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Basic notification settings
    var isEnabled: Bool = true
    var title: String = ""
    var message: String = ""
    var customSound: String?
    
    // Timing configuration
    var deliveryTime: NotificationDeliveryTime = NotificationDeliveryTime.immediate
    var customDeliveryHour: Int = 8
    var customDeliveryMinute: Int = 0
    var advanceNoticeHours: Int = 0
    
    // Notification behavior
    var priority: NotificationPriority = NotificationPriority.normal
    var allowsRepeating: Bool = false
    var maxRepeats: Int = 1
    var repeatIntervalHours: Int = 24
    var cooldownPeriodHours: Int = 24
    
    // Rich notification content
    var includeWeatherSummary: Bool = true
    var includeTemperature: Bool = true
    var includeForecast: Bool = false
    var includeActionButtons: Bool = true
    
    // Action buttons
    var primaryActionTitle: String = "Mark Complete"
    var secondaryActionTitle: String = "Snooze"
    var snoozeHours: Int = 2
    
    // Advanced features
    var requiresLocationPermission: Bool = true
    var respectsDoNotDisturb: Bool = true
    var respectsFocusModes: Bool = true
    var criticalAlert: Bool = false
    
    // Context-aware timing
    var avoidNighttime: Bool = true
    var avoidEarlyMorning: Bool = true
    var preferredStartHour: Int = 7
    var preferredEndHour: Int = 22
    
    // Notification categories and threading
    var categoryIdentifier: String = "WEATHER_REMINDER"
    var threadIdentifier: String?
    var targetContentIdentifier: String?
    
    // CloudKit optimization
    @Attribute(.externalStorage) var customNotificationData: Data?
    
    // Relationship
    var weatherReminder: WeatherReminder?
    
    // Tracking
    var createdAt: Date = Date()
    var lastDelivered: Date?
    var deliveryCount: Int = 0
    var successfulDeliveries: Int = 0
    
    init(
        title: String = "Weather Reminder",
        message: String = "Your weather condition has been met!",
        deliveryTime: NotificationDeliveryTime = .immediate
    ) {
        self.title = title
        self.message = message
        self.deliveryTime = deliveryTime
    }
}

enum NotificationDeliveryTime: String, Codable, CaseIterable {
    case immediate = "immediate"
    case customTime = "custom_time"
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case beforeSunrise = "before_sunrise"
    case afterSunrise = "after_sunrise"
    case beforeSunset = "before_sunset"
    case afterSunset = "after_sunset"
    case advanceNotice = "advance_notice"
}

enum NotificationPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}

extension NotificationConfig {
    var notificationContent: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.categoryIdentifier = categoryIdentifier
        
        if let threadIdentifier = threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }
        
        if let targetContentIdentifier = targetContentIdentifier {
            content.targetContentIdentifier = targetContentIdentifier
        }
        
        // Priority mapping
        switch priority {
        case .low:
            content.interruptionLevel = .passive
        case .normal:
            content.interruptionLevel = .active
        case .high:
            content.interruptionLevel = .timeSensitive
        case .critical:
            content.interruptionLevel = .critical
        }
        
        if criticalAlert {
            content.sound = .defaultCritical
        } else if let customSound = customSound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(customSound))
        } else {
            content.sound = .default
        }
        
        return content
    }
    
    func shouldDeliverAt(_ date: Date) -> Bool {
        guard isEnabled else { return false }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        if avoidNighttime && (hour < preferredStartHour || hour > preferredEndHour) {
            return false
        }
        
        if avoidEarlyMorning && hour < 6 {
            return false
        }
        
        return true
    }
    
    func nextDeliveryDate(after date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        
        switch deliveryTime {
        case .immediate:
            return date
        case .customTime:
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = customDeliveryHour
            components.minute = customDeliveryMinute
            if let customDate = calendar.date(from: components), customDate > date {
                return customDate
            } else {
                // Next day
                components.day! += 1
                return calendar.date(from: components)
            }
        case .morning:
            return nextDeliveryTime(at: 8, after: date)
        case .afternoon:
            return nextDeliveryTime(at: 14, after: date)
        case .evening:
            return nextDeliveryTime(at: 18, after: date)
        case .advanceNotice:
            return calendar.date(byAdding: .hour, value: -advanceNoticeHours, to: date)
        default:
            return date
        }
    }
    
    private func nextDeliveryTime(at hour: Int, after date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        
        if let targetDate = calendar.date(from: components), targetDate > date {
            return targetDate
        } else {
            components.day! += 1
            return calendar.date(from: components)
        }
    }
}
