//
//  UserPreferences.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class UserPreferences {
    @Attribute(.unique) var id: UUID = UUID()
    var temperatureUnit: TemperatureUnit = TemperatureUnit.fahrenheit
    var defaultNotificationTiming: NotificationTiming = NotificationTiming.immediate
    var selectedActivityInterests: [String] = []
    /// App-level master switch for reminder notifications. Distinct from the
    /// system permission: the user can silence SunHat without revoking the
    /// permission in Settings. Checked by every notification send path.
    var notificationsEnabled: Bool = true
    var quietHoursEnabled: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var allowWeekendNotifications: Bool = true
    var maximumDailyNotifications: Int = 5
    /// Running count of notifications delivered on `lastNotificationDate`. Resets
    /// automatically when the calendar day changes so it self-heals across launches.
    var dailyNotificationCount: Int = 0
    var lastNotificationDate: Date?

    // Advanced notification preferences
    var notificationGrouping: NotificationGrouping = NotificationGrouping.byType
    var lockScreenBehavior: LockScreenBehavior = LockScreenBehavior.showPreviews
    var criticalAlertsEnabled: Bool = false
    var vibrationPattern: VibrationPattern = VibrationPattern.default
    var notificationSounds: [String: String] = [:]  // ReminderCategory.rawValue -> sound file name
    
    // Location preferences (persisted from onboarding)
    var locationMode: String = "gps"  // "gps" or "manual"
    var manualLocationLatitude: Double = 0.0
    var manualLocationLongitude: Double = 0.0
    var manualLocationName: String = ""
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Sync properties (prepared for future CloudKit integration)
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
    
    // MARK: - Notification Delivery Policy

    /// Whether a reminder notification may be delivered at `date` according to
    /// the user's app-level notification preferences: the master switch, quiet
    /// hours (handling windows that cross midnight, e.g. 22:00–07:00), and the
    /// weekend rule. System permission is checked separately by the senders.
    /// `respectingQuietHours` lets a reminder that has opted out of quiet hours
    /// skip that one check; the master switch and daily limit always apply.
    func allowsNotificationDelivery(
        at date: Date = Date(),
        calendar: Calendar = .current,
        respectingQuietHours: Bool = true
    ) -> Bool {
        guard notificationsEnabled else { return false }
        if !allowWeekendNotifications && calendar.isDateInWeekend(date) { return false }
        if respectingQuietHours && quietHoursEnabled && isInQuietHours(date, calendar: calendar) { return false }
        let todayCount: Int
        if let lastDate = lastNotificationDate, calendar.isDate(lastDate, inSameDayAs: date) {
            todayCount = dailyNotificationCount
        } else {
            todayCount = 0
        }
        if todayCount >= maximumDailyNotifications { return false }
        return true
    }

    /// Call after successfully delivering a notification to increment the daily count.
    /// Automatically resets the counter when the calendar day has changed.
    func recordNotificationDelivered(at date: Date = Date(), calendar: Calendar = .current) {
        if let lastDate = lastNotificationDate, calendar.isDate(lastDate, inSameDayAs: date) {
            dailyNotificationCount += 1
        } else {
            dailyNotificationCount = 1
        }
        lastNotificationDate = date
        updateTimestamp()
    }

    /// Whether `date` falls inside the quiet-hours window, comparing only the
    /// time of day. A window whose end is earlier than its start (22:00–07:00)
    /// wraps past midnight.
    func isInQuietHours(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        func minutesIntoDay(_ d: Date) -> Int {
            let components = calendar.dateComponents([.hour, .minute], from: d)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }

        let now = minutesIntoDay(date)
        let start = minutesIntoDay(quietHoursStart)
        let end = minutesIntoDay(quietHoursEnd)

        if start == end { return false }
        if start < end {
            return now >= start && now < end
        }
        return now >= start || now < end
    }

    var quietHoursDescription: String {
        if quietHoursEnabled {
            return String(localized: "\(quietHoursStartTime) - \(quietHoursEndTime)", comment: "Quiet hours time range, e.g. 10:00 PM - 7:00 AM")
        } else {
            return String(localized: "Disabled", comment: "Quiet hours status: feature turned off")
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
            return String(localized: "Gardening", comment: "Activity interest option: gardening")
        case .exercise:
            return String(localized: "Exercise", comment: "Activity interest option: exercise")
        case .maintenance:
            return String(localized: "Home Maintenance", comment: "Activity interest option: home maintenance")
        case .photography:
            return String(localized: "Photography", comment: "Activity interest option: photography")
        case .outdoorDining:
            return String(localized: "Outdoor Dining", comment: "Activity interest option: outdoor dining")
        case .sports:
            return String(localized: "Sports", comment: "Activity interest option: sports")
        case .walking:
            return String(localized: "Walking", comment: "Activity interest option: walking")
        case .cycling:
            return String(localized: "Cycling", comment: "Activity interest option: cycling")
        case .hiking:
            return String(localized: "Hiking", comment: "Activity interest option: hiking")
        case .cleaning:
            return String(localized: "Cleaning", comment: "Activity interest option: cleaning")
        case .carWash:
            return String(localized: "Car Washing", comment: "Activity interest option: car washing")
        case .petCare:
            return String(localized: "Pet Care", comment: "Activity interest option: pet care")
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
            return String(localized: "Plant care, yard work, and outdoor gardening activities", comment: "Description of gardening activity interest")
        case .exercise:
            return String(localized: "Outdoor workouts, running, and fitness activities", comment: "Description of exercise activity interest")
        case .maintenance:
            return String(localized: "Home repairs, painting, and outdoor maintenance tasks", comment: "Description of home maintenance activity interest")
        case .photography:
            return String(localized: "Outdoor photo sessions and landscape photography", comment: "Description of photography activity interest")
        case .outdoorDining:
            return String(localized: "Picnics, barbecues, and outdoor meal planning", comment: "Description of outdoor dining activity interest")
        case .sports:
            return String(localized: "Outdoor sports and recreational activities", comment: "Description of sports activity interest")
        case .walking:
            return String(localized: "Daily walks, dog walking, and casual strolls", comment: "Description of walking activity interest")
        case .cycling:
            return String(localized: "Bike rides and cycling adventures", comment: "Description of cycling activity interest")
        case .hiking:
            return String(localized: "Trail hiking and nature exploration", comment: "Description of hiking activity interest")
        case .cleaning:
            return String(localized: "Outdoor cleaning and washing tasks", comment: "Description of cleaning activity interest")
        case .carWash:
            return String(localized: "Vehicle washing and detailing", comment: "Description of car washing activity interest")
        case .petCare:
            return String(localized: "Pet grooming and outdoor pet activities", comment: "Description of pet care activity interest")
        }
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
            return String(localized: "No Grouping", comment: "Notification grouping option: don't group notifications")
        case .byType:
            return String(localized: "Group by Type", comment: "Notification grouping option: group by reminder category")
        case .byTime:
            return String(localized: "Group by Time", comment: "Notification grouping option: group by delivery time")
        case .byLocation:
            return String(localized: "Group by Location", comment: "Notification grouping option: group by location")
        }
    }

    var description: String {
        switch self {
        case .none:
            return String(localized: "Show each notification separately", comment: "Description of no-grouping notification option")
        case .byType:
            return String(localized: "Group notifications by reminder category", comment: "Description of group-by-type notification option")
        case .byTime:
            return String(localized: "Group notifications by delivery time", comment: "Description of group-by-time notification option")
        case .byLocation:
            return String(localized: "Group notifications by location", comment: "Description of group-by-location notification option")
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
            return String(localized: "Show Previews", comment: "Lock screen behavior option: show full notification previews")
        case .hideDetails:
            return String(localized: "Hide Details", comment: "Lock screen behavior option: hide notification content details")
        case .hideNotifications:
            return String(localized: "Hide Notifications", comment: "Lock screen behavior option: hide notifications entirely")
        }
    }

    var description: String {
        switch self {
        case .showPreviews:
            return String(localized: "Show full notification content on lock screen", comment: "Description of show-previews lock screen option")
        case .hideDetails:
            return String(localized: "Show notification but hide content details", comment: "Description of hide-details lock screen option")
        case .hideNotifications:
            return String(localized: "Hide notifications completely on lock screen", comment: "Description of hide-notifications lock screen option")
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
            return String(localized: "None", comment: "Vibration pattern option: no vibration")
        case .default:
            return String(localized: "Default", comment: "Vibration pattern option: system default")
        case .subtle:
            return String(localized: "Subtle", comment: "Vibration pattern option: light gentle vibration")
        case .prominent:
            return String(localized: "Prominent", comment: "Vibration pattern option: strong noticeable vibration")
        case .alert:
            return String(localized: "Alert", comment: "Vibration pattern option: urgent alert pattern")
        case .heartbeat:
            return String(localized: "Heartbeat", comment: "Vibration pattern option: rhythmic pulse pattern")
        case .sos:
            return String(localized: "SOS", comment: "Vibration pattern option: emergency SOS pattern")
        }
    }

    var description: String {
        switch self {
        case .none:
            return String(localized: "No vibration", comment: "Description of no-vibration pattern option")
        case .default:
            return String(localized: "Standard system vibration", comment: "Description of default vibration pattern option")
        case .subtle:
            return String(localized: "Light, gentle vibration", comment: "Description of subtle vibration pattern option")
        case .prominent:
            return String(localized: "Strong, noticeable vibration", comment: "Description of prominent vibration pattern option")
        case .alert:
            return String(localized: "Urgent alert pattern", comment: "Description of alert vibration pattern option")
        case .heartbeat:
            return String(localized: "Rhythmic pulse pattern", comment: "Description of heartbeat vibration pattern option")
        case .sos:
            return String(localized: "Emergency SOS pattern", comment: "Description of SOS vibration pattern option")
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
            return String(localized: "Default", comment: "Notification sound option: system default")
        case .none:
            return String(localized: "None", comment: "Notification sound option: no sound")
        case .chime:
            return String(localized: "Chime", comment: "Notification sound option: chime")
        case .bell:
            return String(localized: "Bell", comment: "Notification sound option: bell")
        case .alert:
            return String(localized: "Alert", comment: "Notification sound option: alert")
        case .gentle:
            return String(localized: "Gentle", comment: "Notification sound option: gentle")
        case .urgent:
            return String(localized: "Urgent", comment: "Notification sound option: urgent")
        case .weather:
            return String(localized: "Weather", comment: "Notification sound option: weather-themed")
        case .nature:
            return String(localized: "Nature", comment: "Notification sound option: nature-themed")
        }
    }
    
    var fileName: String? {
        let candidate: String?
        switch self {
        case .default, .none:
            candidate = nil // Use system default
        case .chime:
            candidate = "notification_chime.caf"
        case .bell:
            candidate = "notification_bell.caf"
        case .alert:
            candidate = "notification_alert.caf"
        case .gentle:
            candidate = "notification_gentle.caf"
        case .urgent:
            candidate = "notification_urgent.caf"
        case .weather:
            candidate = "notification_weather.caf"
        case .nature:
            candidate = "notification_nature.caf"
        }

        // Only use a custom sound when the audio file is actually bundled.
        // The .caf assets are not yet shipped, so without this guard the UI
        // would promise distinct sounds while iOS silently plays the default.
        // Returning nil here cleanly falls back to the system default, and the
        // custom sounds activate automatically once the files are added.
        guard let candidate else { return nil }
        let resource = (candidate as NSString).deletingPathExtension
        let ext = (candidate as NSString).pathExtension
        guard Bundle.main.url(forResource: resource, withExtension: ext) != nil else {
            return nil
        }
        return candidate
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
