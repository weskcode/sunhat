//
//  WeatherModelActor.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreData
import CoreLocation
import SwiftUI
import OSLog

/// Actor for handling SwiftData operations in background with proper concurrency isolation
@ModelActor
actor WeatherModelActor {
    private let logger = Logger(subsystem: "com.sunhat.app", category: "WeatherModelActor")
    
    /// Fetches weather data with caching and backup provider support
    func fetchWeatherData(for location: CLLocation, forceRefresh: Bool = false) async throws -> WeatherData {
        let coordinate = location.coordinate
        logger.debug("Fetching weather data for location: \(coordinate.latitude), \(coordinate.longitude)")
        
do {
            let weatherData = try await fetchFromPrimaryProvider(location)
            logger.info("Successfully fetched weather data from primary provider")
            return weatherData
        } catch {
            logger.warning("Primary provider failed, trying backup: \(error.localizedDescription)")
            
            do {
                let weatherData = try await fetchFromBackupProvider(location)
                logger.info("Successfully fetched weather data from backup provider")
                return weatherData
            } catch {
                logger.error("All weather providers failed: \(error.localizedDescription)")
                throw WeatherError.allProvidersFailed
            }
        }
    }
    
    /// Fetches data from the primary weather provider
    private func fetchFromPrimaryProvider(_ location: CLLocation) async throws -> WeatherData {
        // Implementation for fetching from Apple WeatherKit
        throw WeatherError.serviceUnavailable(provider: .appleWeatherKit)
    }
    
    /// Fetches data from backup weather provider
    private func fetchFromBackupProvider(_ location: CLLocation) async throws -> WeatherData {
        // Implementation for fetching from OpenWeatherMap
        throw WeatherError.serviceUnavailable(provider: .openWeatherMap)
    }
    
    /// Caches weather data locally
    private func cacheWeatherData(_ weatherData: WeatherData, _ location: CLLocation) async {
        // Implementation for caching weather data
    }
    
    /// Fetches forecast data
    func fetchForecastData(for location: CLLocation, days: Int = 7) async throws -> [ForecastDayDisplay] {
        logger.debug("Fetching forecast data for \(days) days")
        // Implementation for fetching forecast data - currently returns empty array
        // In production, this would fetch from WeatherService and convert to ForecastDayDisplay
        return []
    }
    
    /// Saves weather data
    func saveWeatherData(_ weatherData: WeatherData) async throws {
        logger.debug("Saving weather data")
        modelContext.insert(weatherData)
        try modelContext.save()
        logger.info("Weather data saved successfully")
    }
    
    /// Fetches weather alerts
    func fetchWeatherAlerts() async throws -> [WeatherAlert] {
        logger.debug("Fetching weather alerts")
        // Implementation for fetching weather alerts
        return []
    }
    
    /// Clears old weather data
    func clearOldWeatherData(olderThan days: Int = 30) async throws {
        logger.debug("Clearing weather data older than \(days) days")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate { weatherData in
                weatherData.timestamp < cutoffDate
            }
        )

        let oldData = try modelContext.fetch(descriptor)

        for data in oldData {
            modelContext.delete(data)
        }

        try modelContext.save()
        logger.info("Cleared \(oldData.count) old weather data records")
    }

    /// Fetches historical weather data for a location
    func fetchHistoricalWeatherData(for location: CLLocation, daysBack: Int = 30) async throws -> [WeatherDataTransfer] {
        logger.debug("Fetching historical weather data for \(daysBack) days back")

        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate) else {
            logger.warning("Failed to calculate start date")
            return []
        }

        let targetLatitude = location.coordinate.latitude
        let targetLongitude = location.coordinate.longitude

        // Fetch all weather data first, then filter in memory
        // This avoids predicate macro issues with captured variables
        let allDescriptor = FetchDescriptor<WeatherData>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        let allWeatherData = try modelContext.fetch(allDescriptor)

        // Filter in memory for the specific location and date range
        let filteredData = allWeatherData.filter { weatherData in
            abs(weatherData.locationLatitude - targetLatitude) < 0.001 &&
            abs(weatherData.locationLongitude - targetLongitude) < 0.001 &&
            weatherData.timestamp >= startDate &&
            weatherData.timestamp <= endDate
        }

        // Convert to Sendable transfer objects
        let transfers = filteredData.map { weatherData in
            ModelDataConverter.convertWeatherData(weatherData)
        }

        logger.info("Fetched \(transfers.count) historical weather data records")
        return transfers
    }

    /// Fetches evaluation data for all active reminders
    func fetchActiveRemindersData() async throws -> [ReminderEvaluationData] {
        logger.debug("Fetching evaluation data for all active reminders")
        
        // Fetch all active reminders
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isActive && !reminder.isCompleted && !reminder.isPaused
            }
        )
        
        let reminders = try modelContext.fetch(descriptor)
        
        // Convert each reminder to ReminderEvaluationData
        var evaluationDataList: [ReminderEvaluationData] = []
        
        for reminder in reminders {
            guard let triggerCondition = reminder.triggerCondition,
                  let locationData = reminder.location else {
                logger.warning("Skipping reminder \(reminder.id) due to missing trigger condition or location")
                continue
            }
            
            // Create TriggerConditionData directly to avoid crossing actor boundaries
            let triggerConditionData = TriggerConditionData(
                id: triggerCondition.id,
                triggerType: triggerCondition.triggerType,
                targetTemperature: triggerCondition.targetTemperature,
                temperatureTolerance: triggerCondition.temperatureTolerance,
                useFeelsLike: triggerCondition.useFeelsLike,
                minTemperature: triggerCondition.minTemperature,
                maxTemperature: triggerCondition.maxTemperature,
                consecutiveDays: triggerCondition.consecutiveDays,
                averagingPeriod: triggerCondition.averagingPeriod,
                comparisonType: triggerCondition.comparisonType,
                seasonalType: triggerCondition.seasonalType,
                historicalComparisonDays: triggerCondition.historicalComparisonDays,
                requiresHumidity: triggerCondition.requiresHumidity,
                targetHumidity: triggerCondition.targetHumidity,
                humidityTolerance: triggerCondition.humidityTolerance,
                requiresWindSpeed: triggerCondition.requiresWindSpeed,
                maxWindSpeed: triggerCondition.maxWindSpeed,
                requiresPrecipitation: triggerCondition.requiresPrecipitation,
                precipitationRequirement: triggerCondition.precipitationRequirement,
                timeOfDayStart: triggerCondition.timeOfDayStart,
                timeOfDayEnd: triggerCondition.timeOfDayEnd,
                isEnabled: triggerCondition.isEnabled,
                createdAt: triggerCondition.createdAt,
                lastEvaluated: triggerCondition.lastEvaluated,
                evaluationCount: triggerCondition.evaluationCount,
                successfulTriggers: triggerCondition.successfulTriggers
            )
            
            let locationDataTransfer = LocationDataTransfer(
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
            
            let evaluationData = ReminderEvaluationData(
                reminderId: reminder.id,
                triggerCondition: triggerConditionData,
                locationData: locationDataTransfer
            )
            
            evaluationDataList.append(evaluationData)
        }
        
        logger.info("Found \(evaluationDataList.count) active reminders for evaluation")
        return evaluationDataList
    }

    /// Fetches reminder evaluation data for a specific reminder
    func fetchReminderEvaluationData(for reminderId: UUID) async throws -> ReminderEvaluationData? {
        logger.debug("Fetching evaluation data for reminder: \(reminderId)")

        // Fetch the reminder with its trigger condition and location
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.id == reminderId
            }
        )

        guard let reminder = try modelContext.fetch(descriptor).first else {
            logger.warning("Reminder not found: \(reminderId)")
            return nil
        }

        // Convert trigger condition to sendable data
        guard let triggerCondition = reminder.triggerCondition else {
            logger.warning("Reminder \(reminderId) has no trigger condition")
            return nil
        }

        // Create TriggerConditionData directly to avoid crossing actor boundaries
        let triggerConditionData = TriggerConditionData(
            id: triggerCondition.id,
            triggerType: triggerCondition.triggerType,
            targetTemperature: triggerCondition.targetTemperature,
            temperatureTolerance: triggerCondition.temperatureTolerance,
            useFeelsLike: triggerCondition.useFeelsLike,
            minTemperature: triggerCondition.minTemperature,
            maxTemperature: triggerCondition.maxTemperature,
            consecutiveDays: triggerCondition.consecutiveDays,
            averagingPeriod: triggerCondition.averagingPeriod,
            comparisonType: triggerCondition.comparisonType,
            seasonalType: triggerCondition.seasonalType,
            historicalComparisonDays: triggerCondition.historicalComparisonDays,
            requiresHumidity: triggerCondition.requiresHumidity,
            targetHumidity: triggerCondition.targetHumidity,
            humidityTolerance: triggerCondition.humidityTolerance,
            requiresWindSpeed: triggerCondition.requiresWindSpeed,
            maxWindSpeed: triggerCondition.maxWindSpeed,
            requiresPrecipitation: triggerCondition.requiresPrecipitation,
            precipitationRequirement: triggerCondition.precipitationRequirement,
            timeOfDayStart: triggerCondition.timeOfDayStart,
            timeOfDayEnd: triggerCondition.timeOfDayEnd,
            isEnabled: triggerCondition.isEnabled,
            createdAt: triggerCondition.createdAt,
            lastEvaluated: triggerCondition.lastEvaluated,
            evaluationCount: triggerCondition.evaluationCount,
            successfulTriggers: triggerCondition.successfulTriggers
        )

        // Create CLLocation from reminder's location data
        guard let locationData = reminder.location else {
            logger.warning("Reminder \(reminderId) has no location data")
            return nil
        }

        let locationDataTransfer = LocationDataTransfer(
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

        return ReminderEvaluationData(
            reminderId: reminder.id,
            triggerCondition: triggerConditionData,
            locationData: locationDataTransfer
        )
    }

    /// Fetches active reminders for dashboard display
    func fetchActiveRemindersForDisplay() async throws -> [WeatherReminderDisplay] {
        logger.debug("Fetching active reminders for display")

        // Fetch all active reminders
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isActive && !reminder.isCompleted
            },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )

        let reminders = try modelContext.fetch(descriptor)

        // Convert to WeatherReminderDisplay
        let displays = reminders.map { reminder -> WeatherReminderDisplay in
            let triggerConditionData: TriggerConditionData? = reminder.triggerCondition.map { condition in
                TriggerConditionData(
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

            let locationDataTransfer: LocationDataTransfer? = reminder.location.map { locationData in
                LocationDataTransfer(
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

            return WeatherReminderDisplay(
                id: reminder.id,
                title: reminder.title,
                reminderDescription: reminder.reminderDescription,
                category: reminder.category,
                isActive: reminder.isActive,
                isCompleted: reminder.isCompleted,
                isPaused: reminder.isPaused,
                priority: reminder.priority,
                createdDate: reminder.createdDate,
                lastTriggered: reminder.lastTriggered,
                triggerCondition: triggerConditionData,
                location: locationDataTransfer
            )
        }

        logger.info("Found \(displays.count) active reminders for display")
        return displays
    }

}

// MARK: - Data Transfer Objects

/// Sendable version of TriggerCondition for cross-actor communication
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
}

/// Sendable version of LocationData for cross-actor communication
struct LocationDataTransfer: Sendable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let city: String
    let state: String
    let country: String
    let displayName: String
    let timeZoneIdentifier: String
    let lastUpdated: Date

    // Location key for grouping/caching (computed property)
    nonisolated var locationKey: String {
        return "\(latitude),\(longitude)"
    }

    // CLLocation for convenience
    nonisolated var clLocation: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
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

/// Sendable version of WeatherReminder for dashboard display
struct WeatherReminderDisplay: Sendable {
    let id: UUID
    let title: String
    let reminderDescription: String
    let category: ReminderCategory
    let isActive: Bool
    let isCompleted: Bool
    let isPaused: Bool
    let priority: ReminderPriority
    let createdDate: Date
    let lastTriggered: Date?
    let triggerCondition: TriggerConditionData?
    let location: LocationDataTransfer?
}

/// Sendable data for reminder evaluation
struct ReminderEvaluationData: Sendable {
    let reminderId: UUID
    let triggerCondition: TriggerConditionData
    let locationData: LocationDataTransfer

    nonisolated var clLocation: CLLocation {
        CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
    }
}

/// Sendable version of WeatherAlert for UI display
struct WeatherAlertDisplay: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let title: String
    let description: String
    let severity: WeatherAlertSeverity
    let type: WeatherAlertType
    let area: String
    let instructions: String?
    let expiresAt: Date?
    let isActive: Bool
    
    // Computed properties for UI
    var iconName: String {
        switch type {
        case .temperature: return "thermometer.high"
        case .precipitation: return "cloud.rain.fill"
        case .wind: return "wind"
        case .airQuality: return "smoke.fill"
        case .heat: return "thermometer.high"
        case .frost: return "snowflake"
        case .storm: return "cloud.bolt.rain.fill"
        case .flood: return "water.wave"
        case .tornado: return "tornado"
        case .hurricane: return "hurricane"
        case .blizzard: return "snow"
        case .fire: return "flame.fill"
        case .general: return "exclamationmark.triangle.fill"
        case .uv: return "sun.max.fill"
        }
    }
    
    var severityColor: Color {
        switch severity {
        case .minor: return .green
        case .moderate: return .orange
        case .severe: return .red
        case .extreme: return .purple
        case .warning: return .yellow
        case .advisory: return .blue
        case .watch: return .indigo
        }
    }
}

// MARK: - Model Data Converter

public final class ModelDataConverter {

    /// Converts LocationData to Sendable data
    nonisolated static func convertLocationData(_ locationData: LocationData) -> LocationDataTransfer {
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
    nonisolated static func convertTriggerCondition(_ condition: TriggerCondition) -> TriggerConditionData {
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
    nonisolated static func convertWeatherData(_ weatherData: WeatherData) -> WeatherDataTransfer {
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
            cloudCoverage: weatherData.cloudCover,
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
    
    /// Creates WeatherAlertDisplay from WeatherAlert
    nonisolated static func createWeatherAlertDisplay(from weatherAlert: WeatherAlert) -> WeatherAlertDisplay {
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