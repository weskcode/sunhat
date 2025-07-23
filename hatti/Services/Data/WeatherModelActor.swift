//
//  WeatherModelActor.swift
//  hatti
//
//  Created by Claude Code on 7/23/25.
//

import Foundation
import SwiftData
import SwiftUI
import CoreLocation
import os

/// A dedicated ModelActor for handling SwiftData operations in background contexts
/// This provides thread-safe access to SwiftData models without violating Swift 6 concurrency rules
@ModelActor
actor WeatherModelActor {
    private let logger = Logger(subsystem: "com.hatti.app", category: "WeatherModelActor")
    
    // MARK: - WeatherReminder Operations
    
    /// Fetches active reminders for evaluation (returns Sendable data)
    func fetchActiveRemindersData() throws -> [ReminderEvaluationData] {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { $0.isActive && !$0.isCompleted && !$0.isPaused }
        )
        
        let reminders = try modelContext.fetch(descriptor)
        
        // Convert to Sendable data transfer objects
        return try reminders.compactMap { reminder -> ReminderEvaluationData? in
            guard let condition = reminder.triggerCondition,
                  let location = reminder.location else { return nil }
            
            return ReminderEvaluationData(
                reminderId: reminder.id,
                triggerCondition: condition.toSendableData(),
                locationData: location.toSendableData()
            )
        }
    }
    
    /// Fetches evaluation data for a specific reminder
    func fetchReminderEvaluationData(for reminderId: UUID) throws -> ReminderEvaluationData? {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate<WeatherReminder> { $0.id == reminderId }
        )
        
        guard let reminder = try modelContext.fetch(descriptor).first,
              let condition = reminder.triggerCondition,
              let location = reminder.location else {
            return nil
        }
        
        return ReminderEvaluationData(
            reminderId: reminder.id,
            triggerCondition: condition.toSendableData(),
            locationData: location.toSendableData()
        )
    }
    
    /// Fetches active reminders for dashboard display
    func fetchActiveRemindersForDisplay() throws -> [WeatherReminderDisplay] {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { $0.isActive && !$0.isCompleted && !$0.isPaused },
            sortBy: [SortDescriptor(\WeatherReminder.createdDate, order: .reverse)]
        )
        
        let reminders = try modelContext.fetch(descriptor)
        
        return reminders.map { reminder in
            let conditionDescription = reminder.triggerCondition?.formatDescription() ?? "No condition set"
            
            return WeatherReminderDisplay(
                id: reminder.id,
                title: reminder.title,
                reminderDescription: reminder.reminderDescription,
                category: reminder.category,
                priority: reminder.priority,
                isActive: reminder.isActive,
                isCompleted: reminder.isCompleted,
                isPaused: reminder.isPaused,
                createdDate: reminder.createdDate,
                lastTriggered: reminder.lastTriggered,
                triggerCount: reminder.triggerCount,
                nextEvaluationDate: reminder.nextEvaluationDate,
                conditionDescription: conditionDescription
            )
        }
    }
    
    /// Updates reminder trigger state
    func updateReminderTriggerState(
        reminderId: UUID,
        triggered: Bool,
        triggerTime: Date? = nil
    ) throws {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { $0.id == reminderId }
        )
        
        guard let reminder = try modelContext.fetch(descriptor).first else {
            logger.warning("Reminder not found for trigger update: \(reminderId)")
            return
        }
        
        reminder.triggerCount += triggered ? 1 : 0
        reminder.lastEvaluationDate = Date()
        
        if let triggerTime = triggerTime {
            reminder.lastTriggered = triggerTime
        }
        
        try modelContext.save()
        logger.debug("Updated trigger state for reminder: \(reminderId)")
    }
    
    // MARK: - WeatherData Operations
    
    /// Saves weather data safely
    func saveWeatherData(_ data: WeatherDataTransfer) throws {
        let weatherData = WeatherData(
            temperature: data.temperature,
            feelsLike: data.apparentTemperature,
            humidity: data.humidity
        )
        weatherData.timestamp = data.timestamp
        weatherData.temperature = data.temperature
        weatherData.feelsLike = data.apparentTemperature
        weatherData.humidity = data.humidity
        weatherData.windSpeed = data.windSpeed
        weatherData.pressure = data.pressure
        weatherData.visibility = data.visibility
        weatherData.uvIndex = data.uvIndex
        weatherData.dewPoint = data.dewPoint
        weatherData.windDirectionDegrees = data.windDirectionDegrees
        weatherData.windDirection = Int(data.windDirectionDegrees)
        weatherData.windGust = data.windGust
        weatherData.precipitationAmount = data.precipitationAmount
        weatherData.precipitationProbability = data.precipitationProbability
        weatherData.cloudCoverage = data.cloudCoverage
        weatherData.cloudCover = data.cloudCoverage
        weatherData.airQualityIndex = data.airQualityIndex
        weatherData.pm25 = data.pm25
        weatherData.sunrise = data.sunrise
        weatherData.sunset = data.sunset
        weatherData.weatherCondition = data.weatherCondition
        weatherData.weatherDescription = data.weatherDescription
        weatherData.locationLatitude = data.locationLatitude
        weatherData.locationLongitude = data.locationLongitude
        
        modelContext.insert(weatherData)
        try modelContext.save()
        
        logger.debug("Saved weather data for location: \(data.locationLatitude), \(data.locationLongitude)")
    }
    
    /// Fetches historical weather data for trend analysis
    func fetchHistoricalWeatherData(
        for location: CLLocation,
        daysBack: Int = 7
    ) throws -> [WeatherDataTransfer] {
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Simplified predicate - filter location matches programmatically
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate<WeatherData> { data in
                data.timestamp >= startDate &&
                data.locationLatitude != 0.0 &&
                data.locationLongitude != 0.0
            },
            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .reverse)]
        )
        
        let weatherDataResults = try modelContext.fetch(descriptor)
        
        // Filter by location programmatically since SwiftData predicates can't handle complex location logic
        let locationFilteredResults = weatherDataResults.filter { data in
            let latDiff = abs(data.locationLatitude - latitude)
            let lonDiff = abs(data.locationLongitude - longitude)
            return latDiff < 0.01 && lonDiff < 0.01
        }
        
        return locationFilteredResults.map { $0.toSendableData() }
    }
    
    // MARK: - Forecast Operations
    
    /// Fetches forecast days for weekly display
    func fetchForecastDays() throws -> [ForecastDayDisplay] {
        let descriptor = FetchDescriptor<ForecastDay>(
            sortBy: [SortDescriptor(\ForecastDay.date)]
        )
        
        let forecastDays = try modelContext.fetch(descriptor)
        return forecastDays.map { forecast in
            ForecastDayDisplay(
                date: forecast.date,
                highTemperature: forecast.highTemperature,
                lowTemperature: forecast.lowTemperature,
                weatherCondition: forecast.weatherCondition,
                weatherDescription: forecast.weatherDescription,
                precipitationProbability: forecast.precipitationProbability,
                windSpeed: forecast.windSpeed,
                humidity: forecast.humidity
            )
        }
    }
    
    /// Fetches historical temperature for a specific date
    func fetchHistoricalTemperature(for date: Date) throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = #Predicate<WeatherData> { data in
            data.timestamp >= startOfDay && data.timestamp < endOfDay
        }
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .reverse)]
        )
        
        let results = try modelContext.fetch(descriptor)
        return results.first?.temperature
    }
    
    // MARK: - Cleanup Operations
    
    /// Cleans up old weather data to prevent database bloat
    func cleanupOldWeatherData(olderThanDays: Int = 30) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate { $0.timestamp < cutoffDate }
        )
        
        let oldData = try modelContext.fetch(descriptor)
        for data in oldData {
            modelContext.delete(data)
        }
        
        try modelContext.save()
        logger.info("Cleaned up \(oldData.count) old weather data records")
    }
}

// MARK: - Sendable Data Transfer Objects

/// Sendable version of LocationData for cross-actor communication
struct LocationDataTransfer: Sendable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let city: String
    let state: String
    let country: String
    let displayName: String
    let timeZoneIdentifier: String
    let lastUpdated: Date
    
    var clLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: lastUpdated
        )
    }
    
    var locationKey: String {
        "\(latitude),\(longitude)"
    }
}

/// Sendable version of ReminderEvaluationData for cross-actor communication
struct ReminderEvaluationData: Sendable {
    let reminderId: UUID
    let triggerCondition: TriggerConditionData
    let locationData: LocationDataTransfer
    
    var locationKey: String {
        locationData.locationKey
    }
    
    var clLocation: CLLocation {
        locationData.clLocation
    }
}

/// Sendable version of WeatherReminder for UI display
struct WeatherReminderDisplay: Sendable {
    let id: UUID
    let title: String
    let reminderDescription: String
    let category: ReminderCategory
    let priority: ReminderPriority
    let isActive: Bool
    let isCompleted: Bool
    let isPaused: Bool
    let createdDate: Date
    let lastTriggered: Date?
    let triggerCount: Int
    let nextEvaluationDate: Date?
    let conditionDescription: String
}

/// Sendable version of WeatherAlert for UI display
struct WeatherAlertDisplay: Sendable, Identifiable {
    let id: UUID
    /// The timestamp when the alert was issued
    let timestamp: Date = Date()
    let title: String
    let description: String
    let severity: WeatherAlertSeverity
    let type: WeatherAlertType
    let area: String
    let instructions: String?
    let expiresAt: Date?
    let isActive: Bool
}

/// Sendable version of ForecastDay for UI display
struct ForecastDayDisplay: Sendable {
    let date: Date
    let highTemperature: Double
    let lowTemperature: Double
    let weatherCondition: WeatherCondition
    let weatherDescription: String
    let precipitationProbability: Int
    let windSpeed: Double
    let humidity: Int
}

/// Sendable version of TriggerCondition data
struct TriggerConditionData: Sendable {
    let id: UUID
    let triggerType: TriggerType
    let targetTemperature: Double
    let temperatureTolerance: Double
    let useFeelsLike: Bool
    let minTemperature: Double?
    let maxTemperature: Double?
    let consecutiveDays: Int
    let averagingPeriod: Int
    let comparisonType: ComparisonType
    let isEnabled: Bool
    let lastEvaluated: Date?
    let evaluationCount: Int
    let successfulTriggers: Int
}

/// Sendable version of WeatherData for cross-actor communication
struct WeatherDataTransfer: Sendable {
    let timestamp: Date
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let pressure: Double
    let visibility: Double
    let uvIndex: Double
    let dewPoint: Double
    let windDirectionDegrees: Double
    let windGust: Double?
    let precipitationAmount: Double
    let precipitationProbability: Int
    let cloudCoverage: Int
    let airQualityIndex: Int?
    let pm25: Double?
    let sunrise: Date?
    let sunset: Date?
    let weatherCondition: WeatherCondition
    let weatherDescription: String
    let locationLatitude: Double
    let locationLongitude: Double
}

// MARK: - Model Extensions for Sendable Conversion

extension LocationData {
    /// Converts LocationData to Sendable data
    @MainActor
    func toSendableData() -> LocationDataTransfer {
        return LocationDataTransfer(
            id: self.id,
            latitude: self.latitude,
            longitude: self.longitude,
            altitude: self.altitude,
            city: self.city,
            state: self.state,
            country: self.country,
            displayName: self.displayName,
            timeZoneIdentifier: self.timeZoneIdentifier,
            lastUpdated: self.lastUpdated
        )
    }
}

extension TriggerCondition {
    /// Converts TriggerCondition to Sendable data
    @MainActor
    func toSendableData() -> TriggerConditionData {
        return TriggerConditionData(
            id: self.id,
            triggerType: self.triggerType,
            targetTemperature: self.targetTemperature,
            temperatureTolerance: self.temperatureTolerance,
            useFeelsLike: self.useFeelsLike,
            minTemperature: self.minTemperature,
            maxTemperature: self.maxTemperature,
            consecutiveDays: self.consecutiveDays,
            averagingPeriod: self.averagingPeriod,
            comparisonType: self.comparisonType,
            isEnabled: self.isEnabled,
            lastEvaluated: self.lastEvaluated,
            evaluationCount: self.evaluationCount,
            successfulTriggers: self.successfulTriggers
        )
    }
}

extension TriggerCondition {
    /// Formats condition description for display
    func formatDescription() -> String {
        switch self.comparisonType {
        case .above:
            return "When temp > \(String(format: "%.0f", self.targetTemperature))°"
        case .below:
            return "When temp < \(String(format: "%.0f", self.targetTemperature))°"
        case .equals:
            return "When temp ≈ \(String(format: "%.0f", self.targetTemperature))°"
        case .between:
            if let min = self.minTemperature, let max = self.maxTemperature {
                return "When temp \(String(format: "%.0f", min))°-\(String(format: "%.0f", max))°"
            }
            return "Temperature range"
        }
    }
}

extension WeatherData {
    /// Converts WeatherData to Sendable transfer object
    func toSendableData() -> WeatherDataTransfer {
        return WeatherDataTransfer(
            timestamp: self.timestamp,
            temperature: self.temperature,
            apparentTemperature: self.apparentTemperature,
            humidity: self.humidity,
            windSpeed: self.windSpeed,
            pressure: self.pressure,
            visibility: self.visibility,
            uvIndex: self.uvIndex,
            dewPoint: self.dewPoint,
            windDirectionDegrees: self.windDirectionDegrees,
            windGust: self.windGust,
            precipitationAmount: self.precipitationAmount,
            precipitationProbability: self.precipitationProbability,
            cloudCoverage: self.cloudCoverage,
            airQualityIndex: self.airQualityIndex,
            pm25: self.pm25,
            sunrise: self.sunrise,
            sunset: self.sunset,
            weatherCondition: self.weatherCondition,
            weatherDescription: self.weatherDescription,
            locationLatitude: self.locationLatitude,
            locationLongitude: self.locationLongitude
        )
    }
}

// MARK: - WeatherDataTransfer Extensions

extension WeatherDataTransfer {
    /// Converts WeatherDataTransfer to WeatherData for internal processing
    func toWeatherData() -> WeatherData {
        let weatherData = WeatherData(
            temperature: self.temperature,
            feelsLike: self.apparentTemperature,
            humidity: self.humidity
        )
        
        // Set all additional properties
        weatherData.timestamp = self.timestamp
        weatherData.dewPoint = self.dewPoint
        weatherData.windSpeed = self.windSpeed
        weatherData.windDirectionDegrees = self.windDirectionDegrees
        weatherData.windDirection = Int(self.windDirectionDegrees)
        weatherData.windGust = self.windGust
        weatherData.pressure = self.pressure
        weatherData.visibility = self.visibility
        weatherData.uvIndex = self.uvIndex
        weatherData.precipitationAmount = self.precipitationAmount
        weatherData.precipitationProbability = self.precipitationProbability
        weatherData.cloudCoverage = self.cloudCoverage
        weatherData.cloudCover = self.cloudCoverage
        weatherData.airQualityIndex = self.airQualityIndex
        weatherData.pm25 = self.pm25
        weatherData.sunrise = self.sunrise
        weatherData.sunset = self.sunset
        weatherData.weatherCondition = self.weatherCondition
        weatherData.weatherDescription = self.weatherDescription
        weatherData.locationLatitude = self.locationLatitude
        weatherData.locationLongitude = self.locationLongitude
        
        return weatherData
    }
}

// MARK: - WeatherAlertDisplay Extensions

extension WeatherAlertDisplay {
    var iconName: String {
        switch type {
        case .temperature, .heat:
            return "thermometer.sun.fill"
        case .precipitation:
            return "cloud.rain.fill"
        case .wind:
            return "wind"
        case .uv:
            return "sun.max.fill"
        case .airQuality:
            return "leaf.fill"
        case .frost:
            return "thermometer.snowflake"
        case .storm:
            return "cloud.bolt.rain.fill"
        case .flood:
            return "water.waves"
        case .tornado:
            return "tornado"
        case .hurricane:
            return "hurricane"
        case .blizzard:
            return "cloud.snow.fill"
        case .fire:
            return "flame.fill"
        case .general:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var severityColor: Color {
        switch severity {
        case .minor, .advisory:
            return .blue
        case .moderate, .watch:
            return .yellow
        case .severe, .warning:
            return .orange
        case .extreme:
            return .red
        }
    }
}
