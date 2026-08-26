//
//  ScreenshotSeeder.swift
//  SunHat
//
//  Debug-only sample data for App Store screenshot capture. Only compiled into
//  Debug builds and only runs when the app is launched with the
//  "-SunHatScreenshotSeed" argument (see AppStore/Screenshots_v2/capture.sh),
//  so it can never affect a Release/TestFlight/App Store build.
//

#if DEBUG
import Foundation
import SwiftData
import CoreLocation

@MainActor
enum ScreenshotSeeder {
    private static let launchArgument = "-SunHatScreenshotSeed"

    static func seedIfRequested(modelContainer: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }

        let context = modelContainer.mainContext

        if let existing = try? context.fetch(FetchDescriptor<WeatherReminder>()), !existing.isEmpty {
            // Already seeded on a previous launch of the same simulator install.
            markOnboardingComplete()
            return
        }

        let location = makeLocation()
        context.insert(location)

        // WeatherViewModel (Weather tab) resolves its location through
        // LocationPermissionManager.shared.manualLocation, not through
        // UserPreferences.manualLocationLatitude/Longitude below (that's a separate
        // path only DashboardViewModel reads), without this, the Weather tab has no
        // location at all in a screenshot build and falls back to an all-zero empty
        // state instead of showing the seeded data.
        LocationPermissionManager.shared.manualLocation = ManualLocationData(
            name: location.city,
            coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        )

        let preferences = makePreferences(location: location)
        context.insert(preferences)

        let weatherData = makeWeatherData(location: location)
        context.insert(weatherData)
        for day in makeForecastDays() {
            day.weatherData = weatherData
            weatherData.forecastDays.append(day)
            context.insert(day)
        }

        // Stored history so the Weather tab's historical comparison section has
        // real data to compare against (it shows "Not enough history yet" otherwise).
        for pastDay in makeHistoricalWeather(location: location) {
            context.insert(pastDay)
        }

        for reminder in makeReminders(location: location) {
            context.insert(reminder)
            if let condition = reminder.triggerCondition {
                context.insert(condition)
            }
            if let config = reminder.notificationConfig {
                context.insert(config)
            }
            for entry in reminder.history {
                context.insert(entry)
            }
        }

        try? context.save()
        markOnboardingComplete()
    }

    private static func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCreatedFirstReminder")
    }

    // MARK: - Location & Preferences

    private static func makeLocation() -> LocationData {
        let location = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco",
            timeZoneIdentifier: "America/Los_Angeles"
        )
        location.displayName = "San Francisco"
        location.isUserLocation = false
        location.isManuallyEntered = true
        return location
    }

    private static func makePreferences(location: LocationData) -> UserPreferences {
        let preferences = UserPreferences()
        preferences.temperatureUnit = .fahrenheit
        preferences.locationMode = "manual"
        preferences.manualLocationLatitude = location.latitude
        preferences.manualLocationLongitude = location.longitude
        preferences.manualLocationName = location.city
        preferences.notificationsEnabled = true
        preferences.quietHoursEnabled = true
        preferences.quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        preferences.quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        preferences.maximumDailyNotifications = 5
        preferences.selectedActivityInterests = [
            ActivityInterest.gardening.rawValue,
            ActivityInterest.exercise.rawValue,
            ActivityInterest.photography.rawValue
        ]
        return preferences
    }

    // MARK: - Weather

    private static func makeWeatherData(location: LocationData) -> WeatherData {
        let data = WeatherData(temperature: 72, feelsLike: 70, humidity: 55, location: location)
        data.dewPoint = 55
        data.pressure = 30.1
        data.visibility = 10
        data.uvIndex = 5
        data.cloudCover = 40
        data.windSpeed = 8
        data.windDirection = 270
        data.windDirectionDegrees = 270
        data.precipitationAmount = 0
        data.precipitationProbability = 10
        data.precipitationType = .none
        data.weatherCondition = .partlyCloudy
        data.weatherDescription = "Partly Cloudy"
        data.iconName = WeatherCondition.partlyCloudy.icon
        data.dataSource = .appleWeatherKit
        data.accuracy = .high
        data.lastUpdated = Date()
        data.expiresAt = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        return data
    }

    private static func makeHistoricalWeather(location: LocationData) -> [WeatherData] {
        let calendar = Calendar.current
        let plan: [(daysAgo: Int, temperature: Double, condition: WeatherCondition)] = [
            (1, 68, .partlyCloudy),
            (2, 74, .clear),
            (3, 70, .cloudy),
            (7, 64, .partlyCloudy),
            (10, 71, .clear),
            (14, 66, .cloudy)
        ]

        return plan.compactMap { entry in
            guard let timestamp = calendar.date(byAdding: .day, value: -entry.daysAgo, to: Date()) else { return nil }
            let data = WeatherData(temperature: entry.temperature, feelsLike: entry.temperature - 2, humidity: 55, location: location)
            data.timestamp = timestamp
            data.lastUpdated = timestamp
            data.weatherCondition = entry.condition
            data.weatherDescription = entry.condition.displayName
            data.iconName = entry.condition.icon
            data.locationLatitude = location.latitude
            data.locationLongitude = location.longitude
            data.dataSource = .appleWeatherKit
            data.accuracy = .high
            return data
        }
    }

    private static func makeForecastDays() -> [ForecastDay] {
        let calendar = Calendar.current
        let today = Date()
        let plan: [(daysOut: Int, high: Double, low: Double, condition: WeatherCondition, precip: Int)] = [
            (0, 76, 58, .partlyCloudy, 10),
            (1, 80, 60, .clear, 5),
            (2, 68, 52, .cloudy, 20),
            (3, 84, 64, .clear, 0),
            (4, 71, 55, .rain, 70),
            (5, 65, 48, .clear, 0),
            (6, 77, 59, .partlyCloudy, 15)
        ]

        return plan.map { entry in
            let date = calendar.date(byAdding: .day, value: entry.daysOut, to: today) ?? today
            let day = ForecastDay(date: date, highTemperature: entry.high, lowTemperature: entry.low, weatherCondition: entry.condition)
            day.weatherDescription = entry.condition.displayName
            day.iconName = entry.condition.icon
            day.precipitationProbability = entry.precip
            day.humidity = 55
            day.uvIndex = 5
            day.windSpeed = 8
            day.confidence = entry.daysOut < 3 ? .high : .medium
            return day
        }
    }

    // MARK: - Reminders

    private static func makeReminders(location: LocationData) -> [WeatherReminder] {
        [
            gardenWatering(location: location),
            morningRun(location: location),
            beachDay(location: location),
            goldenHourPhotoWalk(location: location),
            poolDay(location: location),
            firstFrostWatch(location: location)
        ]
    }

    private static func gardenWatering(location: LocationData) -> WeatherReminder {
        let condition = TriggerCondition(triggerType: .exactTemperature, targetTemperature: 72, comparisonType: .above)
        condition.temperatureTolerance = 3

        let reminder = WeatherReminder(
            title: "Garden Watering",
            reminderDescription: "Skip watering when it's already warm and moist enough outside.",
            category: .gardening,
            priority: .normal,
            triggerCondition: condition,
            notificationConfig: NotificationConfig(title: "Garden Watering", message: "It's warm enough, hold off on watering today."),
            location: location
        )
        reminder.addHistoryEntry(.created, details: "Reminder created")
        reminder.lastTriggered = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        reminder.triggerCount = 3
        reminder.successfulCompletions = 2
        reminder.addHistoryEntry(.triggered, details: "Conditions matched", weatherData: nil)
        reminder.addHistoryEntry(.completed, details: "Marked complete")
        return reminder
    }

    private static func morningRun(location: LocationData) -> WeatherReminder {
        let condition = TriggerCondition(triggerType: .temperatureRange, targetTemperature: 62, comparisonType: .between)
        condition.minTemperature = 55
        condition.maxTemperature = 70
        condition.timeOfDayStart = Calendar.current.date(from: DateComponents(hour: 6, minute: 0))
        condition.timeOfDayEnd = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))

        let reminder = WeatherReminder(
            title: "Morning Run",
            reminderDescription: "Perfect jogging weather, before it gets hot.",
            category: .exercise,
            priority: .normal,
            triggerCondition: condition,
            notificationConfig: NotificationConfig(title: "Morning Run", message: "Temperatures are ideal for a run right now."),
            location: location
        )
        reminder.addHistoryEntry(.created, details: "Reminder created")
        return reminder
    }

    private static func beachDay(location: LocationData) -> WeatherReminder {
        let condition = TriggerCondition(triggerType: .exactTemperature, targetTemperature: 80, comparisonType: .above)
        condition.temperatureTolerance = 2
        condition.selectedSkyConditions = [.sunny]
        condition.conditionMode = .include

        let reminder = WeatherReminder(
            title: "Beach Day",
            reminderDescription: "Sunny and warm enough for the coast.",
            category: .outdoor,
            priority: .normal,
            triggerCondition: condition,
            notificationConfig: NotificationConfig(title: "Beach Day", message: "Sunny and warm, a great day for the beach."),
            location: location
        )
        reminder.addHistoryEntry(.created, details: "Reminder created")
        reminder.lastTriggered = Calendar.current.date(byAdding: .day, value: -6, to: Date())
        reminder.triggerCount = 1
        reminder.successfulCompletions = 1
        reminder.addHistoryEntry(.triggered, details: "Conditions matched")
        reminder.addHistoryEntry(.completed, details: "Marked complete")
        return reminder
    }

    private static func goldenHourPhotoWalk(location: LocationData) -> WeatherReminder {
        let condition = TriggerCondition(triggerType: .composite, targetTemperature: 68, comparisonType: .above)
        condition.requiresHumidity = true
        condition.targetHumidity = 45
        condition.humidityTolerance = 15
        condition.requiresWindSpeed = true
        condition.maxWindSpeed = 10
        condition.requiresPrecipitation = true
        condition.precipitationRequirement = .dry

        let reminder = WeatherReminder(
            title: "Golden Hour Photo Walk",
            reminderDescription: "Warm, calm, and dry, ideal golden-hour light.",
            category: .outdoor,
            priority: .low,
            triggerCondition: condition,
            notificationConfig: NotificationConfig(title: "Golden Hour Photo Walk", message: "Calm, dry, warm conditions, good light for photos."),
            location: location
        )
        reminder.addHistoryEntry(.created, details: "Reminder created")
        return reminder
    }

    private static func poolDay(location: LocationData) -> WeatherReminder {
        let condition = TriggerCondition(triggerType: .temperatureRange, targetTemperature: 85, comparisonType: .between)
        condition.minTemperature = 78
        condition.maxTemperature = 95

        let reminder = WeatherReminder(
            title: "Pool Day",
            reminderDescription: "Warm enough to make the pool worth it.",
            category: .sports,
            priority: .low,
            isPaused: true,
            triggerCondition: condition,
            notificationConfig: NotificationConfig(title: "Pool Day", message: "It's warm enough for the pool."),
            location: location
        )
        reminder.addHistoryEntry(.created, details: "Reminder created")
        reminder.addHistoryEntry(.paused, details: "Paused for the season")
        return reminder
    }

    private static func firstFrostWatch(location: LocationData) -> WeatherReminder {
        let condition = TriggerCondition(triggerType: .seasonalMarker, targetTemperature: 32, comparisonType: .below)
        condition.seasonalType = .firstFrost

        let reminder = WeatherReminder(
            title: "First Frost Watch",
            reminderDescription: "Bring in the tender plants before the first frost.",
            category: .seasonal,
            priority: .high,
            triggerCondition: condition,
            notificationConfig: NotificationConfig(title: "First Frost Watch", message: "Frost is likely tonight, bring in tender plants."),
            location: location
        )
        reminder.addHistoryEntry(.created, details: "Reminder created")
        return reminder
    }
}

private extension WeatherReminder {
    convenience init(
        title: String,
        reminderDescription: String,
        category: ReminderCategory,
        priority: ReminderPriority,
        isPaused: Bool = false,
        triggerCondition: TriggerCondition,
        notificationConfig: NotificationConfig,
        location: LocationData
    ) {
        self.init(
            title: title,
            reminderDescription: reminderDescription,
            category: category,
            priority: priority,
            isActive: true,
            isCompleted: false,
            isPaused: isPaused,
            triggerCondition: triggerCondition,
            notificationConfig: notificationConfig,
            location: location
        )
    }
}
#endif
