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
    func fetchActiveRemindersData() async throws -> [ReminderEvaluationData] {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isActive == true && 
                reminder.isCompleted == false && 
                reminder.isPaused == false
            }
        )
        
        let reminders = try modelContext.fetch(descriptor)
        
        // Convert to Sendable data transfer objects using MainActor isolation
        return await withTaskGroup(of: ReminderEvaluationData?.self) { group in
            for reminder in reminders {
                group.addTask {
                    await MainActor.run {
                        guard let condition = reminder.triggerCondition,
                              let location = reminder.location else { return nil }
                        
                        let conditionData = ModelDataConverter.convertTriggerCondition(condition)
                        let locationData = ModelDataConverter.convertLocationData(location)
                        
                        return ReminderEvaluationData(
                            reminderId: reminder.id,
                            triggerCondition: conditionData,
                            locationData: locationData
                        )
                    }
                }
            }
            
            var results: [ReminderEvaluationData] = []
            for await reminderData in group {
                if let reminderData = reminderData {
                    results.append(reminderData)
                }
            }
            return results
        }
    }
    
    /// Fetches evaluation data for a specific reminder
    func fetchReminderEvaluationData(for reminderId: UUID) async throws -> ReminderEvaluationData? {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate<WeatherReminder> { reminder in
                reminder.id == reminderId
            }
        )
        
        guard let reminder = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        // Access @MainActor isolated properties safely
        return await MainActor.run {
            guard let condition = reminder.triggerCondition,
                  let location = reminder.location else {
                return nil
            }
            
            let conditionData = ModelDataConverter.convertTriggerCondition(condition)
            let locationData = ModelDataConverter.convertLocationData(location)
            
            return ReminderEvaluationData(
                reminderId: reminder.id,
                triggerCondition: conditionData,
                locationData: locationData
            )
        }
    }
    
    /// Fetches active reminders for dashboard display
    func fetchActiveRemindersForDisplay() async throws -> [WeatherReminderDisplay] {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isActive == true && 
                reminder.isCompleted == false && 
                reminder.isPaused == false
            }
        )
        
        let reminders = try modelContext.fetch(descriptor)
        
        // Convert to Sendable data and sort using MainActor isolation
        let reminderData = await withTaskGroup(of: (WeatherReminderDisplay, Date)?.self) { group in
            var results: [(WeatherReminderDisplay, Date)] = []
            
            for reminder in reminders {
                group.addTask {
                    await MainActor.run {
                        let conditionDescription: String
                        if let condition = reminder.triggerCondition {
                            let conditionData = ModelDataConverter.convertTriggerCondition(condition)
                            conditionDescription = conditionData.formatDescription()
                        } else {
                            conditionDescription = "No condition set"
                        }
                        
                        let display = WeatherReminderDisplay(
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
                        
                        return (display, reminder.createdDate)
                    }
                }
            }
            
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            return results
        }
        
        // Sort by creation date (newest first)
        return reminderData.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
    
    /// Updates reminder trigger state
    func updateReminderTriggerState(
        reminderId: UUID,
        triggered: Bool,
        triggerTime: Date? = nil
    ) async throws {
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.id == reminderId
            }
        )
        
        guard let reminder = try modelContext.fetch(descriptor).first else {
            logger.warning("Reminder not found for trigger update: \(reminderId)")
            return
        }
        
        // Update properties safely using MainActor isolation
        await MainActor.run {
            let currentTriggerCount = reminder.triggerCount
            let newTriggerCount = currentTriggerCount + (triggered ? 1 : 0)
            
            reminder.triggerCount = newTriggerCount
            reminder.lastEvaluationDate = Date()
            
            if let triggerTime = triggerTime {
                reminder.lastTriggered = triggerTime
            }
        }
        
        try modelContext.save()
        logger.debug("Updated trigger state for reminder: \(reminderId)")
    }
    
    // MARK: - WeatherData Operations
    
    /// Saves weather data safely
    func saveWeatherData(_ data: WeatherDataTransfer) throws {
        // Create WeatherData directly in actor context since we're inserting into actor's modelContext
        let weatherData = data.toWeatherData()
        
        modelContext.insert(weatherData)
        try modelContext.save()
        
        logger.debug("Saved weather data for location: \(data.locationLatitude), \(data.locationLongitude)")
    }
    
    /// Fetches historical weather data for trend analysis
    func fetchHistoricalWeatherData(
        for location: CLLocation,
        daysBack: Int = 7
    ) async throws -> [WeatherDataTransfer] {
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Simplified predicate - filter location matches programmatically
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate<WeatherData> { data in
                data.timestamp >= startDate &&
                data.locationLatitude != 0.0 &&
                data.locationLongitude != 0.0
            }
        )
        
        let weatherDataResults = try modelContext.fetch(descriptor)
        
        // Filter by location programmatically since SwiftData predicates can't handle complex location logic
        let locationFilteredResults = weatherDataResults.filter { data in
            let latDiff = abs(data.locationLatitude - latitude)
            let lonDiff = abs(data.locationLongitude - longitude)
            return latDiff < 0.01 && lonDiff < 0.01
        }
        
        // Sort manually since we can't use key paths in Swift 6 strict mode
        let sortedResults = locationFilteredResults.sorted { $0.timestamp > $1.timestamp }
        
        // Convert to Sendable data using MainActor isolation
        return await withTaskGroup(of: WeatherDataTransfer.self) { group in
            var results: [WeatherDataTransfer] = []
            
            for weatherData in sortedResults {
                group.addTask {
                    await MainActor.run {
                        ModelDataConverter.convertWeatherData(weatherData)
                    }
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    // MARK: - Forecast Operations
    
    /// Fetches forecast days for weekly display
    func fetchForecastDays() async throws -> [ForecastDayDisplay] {
        let descriptor = FetchDescriptor<ForecastDay>()
        
        let forecastDays = try modelContext.fetch(descriptor)
        // Sort manually since we can't use key paths in Swift 6 strict mode
        let sortedForecastDays = forecastDays.sorted { $0.date < $1.date }
        
        return await withTaskGroup(of: ForecastDayDisplay.self) { group in
            var results: [ForecastDayDisplay] = []
            
            for forecast in sortedForecastDays {
                group.addTask {
                    await MainActor.run {
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
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    /// Fetches forecast days for display with location filtering
    func fetchForecastDaysForDisplay(for location: LocationDataTransfer, limit: Int = 7) async throws -> [ForecastDayDisplay] {
        let predicate = #Predicate<ForecastDay> { day in
            day.locationLatitude == location.latitude &&
            day.locationLongitude == location.longitude
        }
        
        let descriptor = FetchDescriptor<ForecastDay>(predicate: predicate)
        descriptor.fetchLimit = limit
        
        let forecastDays = try modelContext.fetch(descriptor)
        // Sort manually since we can't use key paths in Swift 6 strict mode
        let sortedForecastDays = forecastDays.sorted { $0.date < $1.date }
        
        return await withTaskGroup(of: ForecastDayDisplay.self) { group in
            var results: [ForecastDayDisplay] = []
            
            for day in sortedForecastDays {
                group.addTask {
                    await MainActor.run {
                        ForecastDayDisplay(
                            date: day.date,
                            highTemperature: day.highTemperature,
                            lowTemperature: day.lowTemperature,
                            weatherCondition: day.weatherCondition,
                            weatherDescription: day.weatherDescription,
                            precipitationProbability: day.precipitationProbability,
                            windSpeed: day.windSpeed,
                            humidity: day.humidity
                        )
                    }
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    /// Fetches historical temperature for a specific date
    func fetchHistoricalTemperature(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = #Predicate<WeatherData> { data in
            data.timestamp >= startOfDay && data.timestamp < endOfDay
        }
        
        let descriptor = FetchDescriptor<WeatherData>(predicate: predicate)
        
        let results = try modelContext.fetch(descriptor)
        // Sort manually since we can't use key paths in Swift 6 strict mode
        let sortedResults = results.sorted { $0.timestamp > $1.timestamp }
        
        guard let firstResult = sortedResults.first else { return nil }
        
        return await MainActor.run {
            firstResult.temperature
        }
    }
    
    /// Fetches historical temperatures for a location over a specified number of days
    func fetchHistoricalTemperatures(for location: LocationDataTransfer, days: Int = 30) async throws -> [Double] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let predicate = #Predicate<WeatherData> { data in
            data.locationLatitude == location.latitude &&
            data.locationLongitude == location.longitude &&
            data.timestamp >= startDate
        }
        
        let descriptor = FetchDescriptor<WeatherData>(predicate: predicate)
        
        let weatherData = try modelContext.fetch(descriptor)
        // Sort manually since we can't use key paths in Swift 6 strict mode
        let sortedData = weatherData.sorted { $0.timestamp > $1.timestamp }
        
        return await withTaskGroup(of: Double.self) { group in
            for data in sortedData {
                group.addTask {
                    await MainActor.run {
                        data.temperature
                    }
                }
            }
            
            var temperatures: [Double] = []
            for await temperature in group {
                temperatures.append(temperature)
            }
            return temperatures
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Cleans up old weather data to prevent database bloat
    func cleanupOldWeatherData(olderThanDays: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate { data in
                data.timestamp < cutoffDate
            }
        )
        
        let oldData = try modelContext.fetch(descriptor)
        
        await MainActor.run {
            for data in oldData {
                modelContext.delete(data)
            }
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
    
    nonisolated var clLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: lastUpdated
        )
    }
    
    nonisolated var locationKey: String {
        "\(latitude),\(longitude)"
    }
}

/// Sendable version of ReminderEvaluationData for cross-actor communication
struct ReminderEvaluationData: Sendable {
    let reminderId: UUID
    let triggerCondition: TriggerConditionData
    let locationData: LocationDataTransfer
    
    nonisolated var locationKey: String {
        locationData.locationKey
    }
    
    nonisolated var clLocation: CLLocation {
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
    
    /// Creates a WeatherAlertDisplay from a WeatherAlert
    static func from(weatherAlert: WeatherAlert) -> WeatherAlertDisplay {
        return WeatherAlertDisplay(
            id: weatherAlert.id,
            timestamp: weatherAlert.timestamp,
            title: weatherAlert.title,
            description: weatherAlert.description,
            severity: weatherAlert.severity,
            type: weatherAlert.type,
            area: weatherAlert.area,
            instructions: weatherAlert.instructions,
            expiresAt: weatherAlert.expiresAt,
            isActive: weatherAlert.isActive
        )
    }
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
    let seasonalType: SeasonalType?
    let historicalComparisonDays: Int
    let requiresHumidity: Bool
    let targetHumidity: Double?
    let humidityTolerance: Double
    let requiresWindSpeed: Bool
    let maxWindSpeed: Double?
    let requiresPrecipitation: Bool
    let precipitationRequirement: PrecipitationRequirement
    let timeOfDayStart: Date?
    let timeOfDayEnd: Date?
    let isEnabled: Bool
    let createdAt: Date
    let lastEvaluated: Date?
    let evaluationCount: Int
    let successfulTriggers: Int
    
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

// MARK: - MainActor Model Data Converter

/// @MainActor class for safely converting SwiftData models to Sendable DTOs
@MainActor
public final class ModelDataConverter {
    
    /// Converts LocationData to Sendable data
    static func convertLocationData(_ locationData: LocationData) -> LocationDataTransfer {
        return LocationDataTransfer(
            id: locationData.id,
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            altitude: locationData.altitude,
            city: locationData.city,
            state: locationData.state,
            country: locationData.country,
            displayName: locationData.displayName,
            timeZoneIdentifier: locationData.timeZoneIdentifier,
            lastUpdated: locationData.lastUpdated
        )
    }
    
    /// Converts TriggerCondition to Sendable data
    static func convertTriggerCondition(_ condition: TriggerCondition) -> TriggerConditionData {
        return TriggerConditionData(
            id: condition.id,
            triggerType: condition.triggerType,
            targetTemperature: condition.targetTemperature,
            temperatureTolerance: condition.temperatureTolerance,
            useFeelsLike: condition.useFeelsLike,
            minTemperature: condition.minTemperature,
            maxTemperature: condition.maxTemperature,
            consecutiveDays: condition.consecutiveDays,
            averagingPeriod: condition.averagingPeriod,
            comparisonType: condition.comparisonType,
            seasonalType: condition.seasonalType,
            historicalComparisonDays: condition.historicalComparisonDays,
            requiresHumidity: condition.requiresHumidity,
            targetHumidity: condition.targetHumidity,
            humidityTolerance: condition.humidityTolerance,
            requiresWindSpeed: condition.requiresWindSpeed,
            maxWindSpeed: condition.maxWindSpeed,
            requiresPrecipitation: condition.requiresPrecipitation,
            precipitationRequirement: condition.precipitationRequirement,
            timeOfDayStart: condition.timeOfDayStart,
            timeOfDayEnd: condition.timeOfDayEnd,
            isEnabled: condition.isEnabled,
            createdAt: condition.createdAt,
            lastEvaluated: condition.lastEvaluated,
            evaluationCount: condition.evaluationCount,
            successfulTriggers: condition.successfulTriggers
        )
    }
    
    /// Converts WeatherData to Sendable transfer object
    static func convertWeatherData(_ weatherData: WeatherData) -> WeatherDataTransfer {
        return WeatherDataTransfer(
            timestamp: weatherData.timestamp,
            temperature: weatherData.temperature,
            apparentTemperature: weatherData.apparentTemperature,
            humidity: weatherData.humidity,
            windSpeed: weatherData.windSpeed,
            pressure: weatherData.pressure,
            visibility: weatherData.visibility,
            uvIndex: weatherData.uvIndex,
            dewPoint: weatherData.dewPoint,
            windDirectionDegrees: weatherData.windDirectionDegrees,
            windGust: weatherData.windGust,
            precipitationAmount: weatherData.precipitationAmount,
            precipitationProbability: weatherData.precipitationProbability,
            cloudCoverage: weatherData.cloudCoverage,
            airQualityIndex: weatherData.airQualityIndex,
            pm25: weatherData.pm25,
            sunrise: weatherData.sunrise,
            sunset: weatherData.sunset,
            weatherCondition: weatherData.weatherCondition,
            weatherDescription: weatherData.weatherDescription,
            locationLatitude: weatherData.locationLatitude,
            locationLongitude: weatherData.locationLongitude
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
