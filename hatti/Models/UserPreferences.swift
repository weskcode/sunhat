//
//  UserPreferences.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CloudKit
import SwiftUI

@Model
final class UserPreferences {
    @Attribute(.unique) var id: UUID = UUID()
    var temperatureUnit: TemperatureUnit = TemperatureUnit.fahrenheit
    var defaultNotificationTiming: NotificationTiming = NotificationTiming.immediate
    var selectedActivityInterests: [String] = []
    var quietHoursEnabled: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var allowWeekendNotifications: Bool = true
    var maximumDailyNotifications: Int = 5
    
    // Advanced notification preferences
    var notificationGrouping: NotificationGrouping = NotificationGrouping.byType
    var lockScreenBehavior: LockScreenBehavior = LockScreenBehavior.showPreviews
    var criticalAlertsEnabled: Bool = false
    var vibrationPattern: VibrationPattern = VibrationPattern.default
    var notificationSounds: [String: String] = [:]  // ReminderCategory.rawValue -> sound file name
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // CloudKit sync properties
    var cloudKitRecordID: String?
    var lastSyncedAt: Date?
    
    init() {
        // Initialize with sensible defaults
        self.id = UUID()
        self.temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        self.defaultNotificationTiming = .immediate
        self.selectedActivityInterests = []
        self.quietHoursEnabled = true
        self.quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        self.quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        self.allowWeekendNotifications = true
        self.maximumDailyNotifications = 5
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Computed properties for convenience
    var quietHoursStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: quietHoursStart)
    }
    
    var quietHoursEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: quietHoursEnd)
    }
    
    var quietHoursDescription: String {
        if quietHoursEnabled {
            return "\(quietHoursStartTime) - \(quietHoursEndTime)"
        } else {
            return "Disabled"
        }
    }
    
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    // Activity interest management
    func addActivityInterest(_ interest: ActivityInterest) {
        if !selectedActivityInterests.contains(interest.rawValue) {
            selectedActivityInterests.append(interest.rawValue)
            updateTimestamp()
        }
    }
    
    func removeActivityInterest(_ interest: ActivityInterest) {
        selectedActivityInterests.removeAll { $0 == interest.rawValue }
        updateTimestamp()
    }
    
    func hasActivityInterest(_ interest: ActivityInterest) -> Bool {
        selectedActivityInterests.contains(interest.rawValue)
    }
    
    func toggleActivityInterest(_ interest: ActivityInterest) {
        if hasActivityInterest(interest) {
            removeActivityInterest(interest)
        } else {
            addActivityInterest(interest)
        }
    }
}

// MARK: - Supporting Enums





enum ActivityInterest: String, CaseIterable, Codable {
    case gardening = "gardening"
    case exercise = "exercise"
    case maintenance = "maintenance"
    case photography = "photography"
    case outdoorDining = "outdoor_dining"
    case sports = "sports"
    case walking = "walking"
    case cycling = "cycling"
    case hiking = "hiking"
    case cleaning = "cleaning"
    case carWash = "car_wash"
    case petCare = "pet_care"
    
    var displayName: String {
        switch self {
        case .gardening:
            return "Gardening"
        case .exercise:
            return "Exercise"
        case .maintenance:
            return "Home Maintenance"
        case .photography:
            return "Photography"
        case .outdoorDining:
            return "Outdoor Dining"
        case .sports:
            return "Sports"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .hiking:
            return "Hiking"
        case .cleaning:
            return "Cleaning"
        case .carWash:
            return "Car Washing"
        case .petCare:
            return "Pet Care"
        }
    }
    
    var icon: String {
        switch self {
        case .gardening:
            return "leaf.fill"
        case .exercise:
            return "figure.run"
        case .maintenance:
            return "hammer.fill"
        case .photography:
            return "camera.fill"
        case .outdoorDining:
            return "fork.knife"
        case .sports:
            return "sportscourt.fill"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "bicycle"
        case .hiking:
            return "figure.hiking"
        case .cleaning:
            return "sparkles"
        case .carWash:
            return "car.fill"
        case .petCare:
            return "pawprint.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .gardening:
            return .green
        case .exercise:
            return .blue
        case .maintenance:
            return .orange
        case .photography:
            return .purple
        case .outdoorDining:
            return .red
        case .sports:
            return .blue
        case .walking:
            return .green
        case .cycling:
            return .cyan
        case .hiking:
            return .brown
        case .cleaning:
            return .yellow
        case .carWash:
            return .blue
        case .petCare:
            return .pink
        }
    }
    
    var description: String {
        switch self {
        case .gardening:
            return "Plant care, yard work, and outdoor gardening activities"
        case .exercise:
            return "Outdoor workouts, running, and fitness activities"
        case .maintenance:
            return "Home repairs, painting, and outdoor maintenance tasks"
        case .photography:
            return "Outdoor photo sessions and landscape photography"
        case .outdoorDining:
            return "Picnics, barbecues, and outdoor meal planning"
        case .sports:
            return "Outdoor sports and recreational activities"
        case .walking:
            return "Daily walks, dog walking, and casual strolls"
        case .cycling:
            return "Bike rides and cycling adventures"
        case .hiking:
            return "Trail hiking and nature exploration"
        case .cleaning:
            return "Outdoor cleaning and washing tasks"
        case .carWash:
            return "Vehicle washing and detailing"
        case .petCare:
            return "Pet grooming and outdoor pet activities"
        }
    }
}

// MARK: - CloudKit Extensions

extension UserPreferences {
    var cloudKitRecord: CKRecord {
        let recordID = CKRecord.ID(recordName: cloudKitRecordID ?? UUID().uuidString)
        let record = CKRecord(recordType: "UserPreferences", recordID: recordID)
        
        record["temperatureUnit"] = temperatureUnit.rawValue
        record["defaultNotificationTiming"] = defaultNotificationTiming.rawValue
        record["selectedActivityInterests"] = selectedActivityInterests
        record["quietHoursEnabled"] = quietHoursEnabled
        record["quietHoursStart"] = quietHoursStart
        record["quietHoursEnd"] = quietHoursEnd
        record["allowWeekendNotifications"] = allowWeekendNotifications
        record["maximumDailyNotifications"] = maximumDailyNotifications
        record["notificationGrouping"] = notificationGrouping.rawValue
        record["lockScreenBehavior"] = lockScreenBehavior.rawValue
        record["criticalAlertsEnabled"] = criticalAlertsEnabled
        record["vibrationPattern"] = vibrationPattern.rawValue
        record["notificationSounds"] = notificationSounds as CKRecordValue
        record["createdAt"] = createdAt
        record["updatedAt"] = updatedAt
        
        return record
    }
    
    static func from(cloudKitRecord record: CKRecord) -> UserPreferences {
        let preferences = UserPreferences()
        
        preferences.cloudKitRecordID = record.recordID.recordName
        preferences.temperatureUnit = TemperatureUnit(rawValue: record["temperatureUnit"] as? String ?? "fahrenheit") ?? .fahrenheit
        preferences.defaultNotificationTiming = NotificationTiming(rawValue: record["defaultNotificationTiming"] as? String ?? "immediate") ?? .immediate
        preferences.selectedActivityInterests = record["selectedActivityInterests"] as? [String] ?? []
        preferences.quietHoursEnabled = record["quietHoursEnabled"] as? Bool ?? true
        preferences.quietHoursStart = record["quietHoursStart"] as? Date ?? Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        preferences.quietHoursEnd = record["quietHoursEnd"] as? Date ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        preferences.allowWeekendNotifications = record["allowWeekendNotifications"] as? Bool ?? true
        preferences.maximumDailyNotifications = record["maximumDailyNotifications"] as? Int ?? 5
        preferences.notificationGrouping = NotificationGrouping(rawValue: record["notificationGrouping"] as? String ?? "byType") ?? .byType
        preferences.lockScreenBehavior = LockScreenBehavior(rawValue: record["lockScreenBehavior"] as? String ?? "showPreviews") ?? .showPreviews
        preferences.criticalAlertsEnabled = record["criticalAlertsEnabled"] as? Bool ?? false
        preferences.vibrationPattern = VibrationPattern(rawValue: record["vibrationPattern"] as? String ?? "default") ?? .default
        preferences.notificationSounds = record["notificationSounds"] as? [String: String] ?? [:]
        preferences.createdAt = record["createdAt"] as? Date ?? Date()
        preferences.updatedAt = record["updatedAt"] as? Date ?? Date()
        preferences.lastSyncedAt = Date()
        
        return preferences
    }
}

// MARK: - Advanced Notification Enums

enum NotificationGrouping: String, CaseIterable, Codable {
    case none = "none"
    case byType = "byType"
    case byTime = "byTime"
    case byLocation = "byLocation"
    
    var displayName: String {
        switch self {
        case .none:
            return "No Grouping"
        case .byType:
            return "Group by Type"
        case .byTime:
            return "Group by Time"
        case .byLocation:
            return "Group by Location"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "Show each notification separately"
        case .byType:
            return "Group notifications by reminder category"
        case .byTime:
            return "Group notifications by delivery time"
        case .byLocation:
            return "Group notifications by location"
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return "list.bullet"
        case .byType:
            return "folder.fill"
        case .byTime:
            return "clock.fill"
        case .byLocation:
            return "location.fill"
        }
    }
}

enum LockScreenBehavior: String, CaseIterable, Codable {
    case showPreviews = "showPreviews"
    case hideDetails = "hideDetails"
    case hideNotifications = "hideNotifications"
    
    var displayName: String {
        switch self {
        case .showPreviews:
            return "Show Previews"
        case .hideDetails:
            return "Hide Details"
        case .hideNotifications:
            return "Hide Notifications"
        }
    }
    
    var description: String {
        switch self {
        case .showPreviews:
            return "Show full notification content on lock screen"
        case .hideDetails:
            return "Show notification but hide content details"
        case .hideNotifications:
            return "Hide notifications completely on lock screen"
        }
    }
    
    var icon: String {
        switch self {
        case .showPreviews:
            return "eye.fill"
        case .hideDetails:
            return "eye.trianglebadge.exclamationmark.fill"
        case .hideNotifications:
            return "eye.slash.fill"
        }
    }
}

enum VibrationPattern: String, CaseIterable, Codable {
    case none = "none"
    case `default` = "default"
    case subtle = "subtle"
    case prominent = "prominent"
    case alert = "alert"
    case heartbeat = "heartbeat"
    case sos = "sos"
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .default:
            return "Default"
        case .subtle:
            return "Subtle"
        case .prominent:
            return "Prominent"
        case .alert:
            return "Alert"
        case .heartbeat:
            return "Heartbeat"
        case .sos:
            return "SOS"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "No vibration"
        case .default:
            return "Standard system vibration"
        case .subtle:
            return "Light, gentle vibration"
        case .prominent:
            return "Strong, noticeable vibration"
        case .alert:
            return "Urgent alert pattern"
        case .heartbeat:
            return "Rhythmic pulse pattern"
        case .sos:
            return "Emergency SOS pattern"
        }
    }
    
    var pattern: [Double] {
        switch self {
        case .none:
            return []
        case .default:
            return [0.0, 0.1]
        case .subtle:
            return [0.0, 0.05, 0.1, 0.05]
        case .prominent:
            return [0.0, 0.2, 0.1, 0.2]
        case .alert:
            return [0.0, 0.1, 0.05, 0.1, 0.05, 0.1]
        case .heartbeat:
            return [0.0, 0.05, 0.05, 0.05, 0.1, 0.2]
        case .sos:
            return [0.0, 0.05, 0.05, 0.05, 0.05, 0.05, 0.1, 0.2, 0.1, 0.2, 0.1, 0.2, 0.1, 0.05, 0.05, 0.05, 0.05, 0.05]
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return "speaker.slash.fill"
        case .default:
            return "iphone.radiowaves.left.and.right"
        case .subtle:
            return "wave.3.left"
        case .prominent:
            return "wave.3.right"
        case .alert:
            return "exclamationmark.triangle.fill"
        case .heartbeat:
            return "heart.fill"
        case .sos:
            return "sos"
        }
    }
}

enum NotificationSound: String, CaseIterable, Codable {
    case `default` = "default"
    case none = "none"
    case chime = "chime"
    case bell = "bell"
    case alert = "alert"
    case gentle = "gentle"
    case urgent = "urgent"
    case weather = "weather"
    case nature = "nature"
    
    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .none:
            return "None"
        case .chime:
            return "Chime"
        case .bell:
            return "Bell"
        case .alert:
            return "Alert"
        case .gentle:
            return "Gentle"
        case .urgent:
            return "Urgent"
        case .weather:
            return "Weather"
        case .nature:
            return "Nature"
        }
    }
    
    var fileName: String? {
        switch self {
        case .default:
            return nil // Use system default
        case .none:
            return nil
        case .chime:
            return "notification_chime.caf"
        case .bell:
            return "notification_bell.caf"
        case .alert:
            return "notification_alert.caf"
        case .gentle:
            return "notification_gentle.caf"
        case .urgent:
            return "notification_urgent.caf"
        case .weather:
            return "notification_weather.caf"
        case .nature:
            return "notification_nature.caf"
        }
    }
    
    var icon: String {
        switch self {
        case .default:
            return "speaker.2.fill"
        case .none:
            return "speaker.slash.fill"
        case .chime:
            return "music.note"
        case .bell:
            return "bell.fill"
        case .alert:
            return "exclamationmark.triangle.fill"
        case .gentle:
            return "leaf.fill"
        case .urgent:
            return "alarm.fill"
        case .weather:
            return "cloud.rain.fill"
        case .nature:
            return "tree.fill"
        }
    }
}