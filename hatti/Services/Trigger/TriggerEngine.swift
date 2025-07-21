//
//  TriggerEngine.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation
import UserNotifications
import BackgroundTasks
import os.log

// MARK: - Trigger Evaluation Result

struct TriggerEvaluationResult: Sendable {
    let reminderId: UUID
    let condition: TriggerCondition
    let triggered: Bool
    let confidence: Double
    let evaluationTime: Date
    let weatherData: WeatherData?
    let triggerReason: String
    let nextEvaluationTime: Date?
    let metadata: [String: String]
    
    init(
        reminderId: UUID,
        condition: TriggerCondition,
        triggered: Bool,
        confidence: Double = 1.0,
        weatherData: WeatherData? = nil,
        triggerReason: String = "",
        nextEvaluationTime: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.reminderId = reminderId
        self.condition = condition
        self.triggered = triggered
        self.confidence = confidence
        self.evaluationTime = Date()
        self.weatherData = weatherData
        self.triggerReason = triggerReason
        self.nextEvaluationTime = nextEvaluationTime
        self.metadata = metadata
    }
}

// MARK: - Historical Weather Context

struct HistoricalWeatherContext: Sendable {
    let location: CLLocation
    let currentDate: Date
    let historicalData: [WeatherData]
    let yearlyAverages: [String: Double] // Month-day key to average temp
    let seasonalPatterns: SeasonalPatterns
    
    struct SeasonalPatterns: Sendable {
        let averageFirstFrost: Date?
        let averageLastFrost: Date?
        let averageSpringTransition: Date?
        let averageFallTransition: Date?
        let growingSeasonStart: Date?
        let growingSeasonEnd: Date?
    }
}

// MARK: - Trend Analysis Data

struct TrendAnalysis: Sendable {
    let consecutiveDaysAbove: Int
    let consecutiveDaysBelow: Int
    let averageOverPeriod: Double
    let trendDirection: TrendDirection
    let volatility: Double
    let peakTemperature: Double
    let lowTemperature: Double
    
    enum TrendDirection: Sendable {
        case rising
        case falling
        case stable
        case volatile
    }
}

// MARK: - Main Trigger Engine Actor

actor TriggerEngine {
    static let shared = TriggerEngine()
    
    private var modelContext: ModelContext?
    private let weatherService = WeatherService.shared
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "TriggerEngine")
    
    // Evaluation caches
    private var evaluationCache: [UUID: TriggerEvaluationResult] = [:]
    private var historicalDataCache: [String: HistoricalWeatherContext] = [:]
    private var trendAnalysisCache: [String: TrendAnalysis] = [:]
    
    // Performance metrics
    private var evaluationCount = 0
    private var lastEvaluationTime: Date?
    private var averageEvaluationDuration: TimeInterval = 0
    
    private init() {}
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("TriggerEngine configured")
    }
    
    // MARK: - Main Evaluation Methods
    
    func evaluateAllActiveReminders() async -> [TriggerEvaluationResult] {
        let startTime = Date()
        evaluationCount += 1
        
        guard let modelContext = modelContext else {
            logger.error("TriggerEngine not configured with ModelContext")
            return []
        }
        
        logger.debug("Starting evaluation of all active reminders")
        
        // Fetch all active reminders
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isCurrentlyActive && reminder.canTrigger
            }
        )
        
        do {
            let activeReminders = try modelContext.fetch(descriptor)
            logger.debug("Found \(activeReminders.count) active reminders to evaluate")
            
            // Group reminders by location to optimize weather data fetching
            let locationGroups = Dictionary(grouping: activeReminders) { reminder in
                reminder.location?.coordinate ?? CLLocationCoordinate2D()
            }
            
            var allResults: [TriggerEvaluationResult] = []
            
            // Evaluate each location group
            for (coordinate, reminders) in locationGroups {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let results = await evaluateRemindersForLocation(reminders, at: location)
                allResults.append(contentsOf: results)
            }
            
            // Update performance metrics
            let duration = Date().timeIntervalSince(startTime)
            updatePerformanceMetrics(duration: duration)
            
            logger.info("Completed evaluation of \(activeReminders.count) reminders in \(duration)s")
            return allResults
            
        } catch {
            logger.error("Failed to fetch active reminders: \(error)")
            return []
        }
    }
    
    func evaluateReminder(_ reminder: WeatherReminder) async -> TriggerEvaluationResult? {
        guard let location = reminder.location?.clLocation,
              let condition = reminder.triggerCondition else {
            return nil
        }
        
        return await evaluateCondition(condition, for: reminder.id, at: location)
    }
    
    private func evaluateRemindersForLocation(_ reminders: [WeatherReminder], at location: CLLocation) async -> [TriggerEvaluationResult] {
        do {
            // Fetch current weather data for the location
            let weatherData = try await weatherService.fetchWeatherData(for: location)
            
            var results: [TriggerEvaluationResult] = []
            
            for reminder in reminders {
                guard let condition = reminder.triggerCondition else { continue }
                
                if let result = await evaluateCondition(condition, for: reminder.id, at: location, with: weatherData) {
                    results.append(result)
                }
            }
            
            return results
            
        } catch {
            logger.warning("Failed to fetch weather data for location \(location.coordinate): \(error)")
            return []
        }
    }
    
    // MARK: - Condition Evaluation Logic
    
    private func evaluateCondition(
        _ condition: TriggerCondition,
        for reminderId: UUID,
        at location: CLLocation,
        with weatherData: WeatherData? = nil
    ) async -> TriggerEvaluationResult? {
        
        // Check cache first
        if let cachedResult = evaluationCache[reminderId],
           Date().timeIntervalSince(cachedResult.evaluationTime) < 300 { // 5 min cache
            return cachedResult
        }
        
        let currentWeatherData: WeatherData
        if let providedData = weatherData {
            currentWeatherData = providedData
        } else {
            do {
                currentWeatherData = try await weatherService.fetchWeatherData(for: location)
            } catch {
                logger.warning("Failed to fetch weather data for evaluation: \(error)")
                return nil
            }
        }
        
        let result: TriggerEvaluationResult
        
        switch condition.triggerType {
        case .exactTemperature:
            result = await evaluateExactTemperature(condition, reminderId: reminderId, weatherData: currentWeatherData)
            
        case .temperatureRange:
            result = await evaluateTemperatureRange(condition, reminderId: reminderId, weatherData: currentWeatherData)
            
        case .consecutiveDays:
            result = await evaluateConsecutiveDays(condition, reminderId: reminderId, location: location, currentWeather: currentWeatherData)
            
        case .averageTemperature:
            result = await evaluateAverageTemperature(condition, reminderId: reminderId, location: location, currentWeather: currentWeatherData)
            
        case .seasonalMarker:
            result = await evaluateSeasonalMarker(condition, reminderId: reminderId, location: location, currentWeather: currentWeatherData)
            
        case .composite:
            result = await evaluateComposite(condition, reminderId: reminderId, location: location, weatherData: currentWeatherData)
            
        case .historicalComparison:
            result = await evaluateHistoricalComparison(condition, reminderId: reminderId, location: location, currentWeather: currentWeatherData)
        }
        
        // Cache the result
        evaluationCache[reminderId] = result
        
        return result
    }
}

// MARK: - Temperature Evaluators Extension

extension TriggerEngine {
    
    private func evaluateExactTemperature(
        _ condition: TriggerCondition,
        reminderId: UUID,
        weatherData: WeatherData
    ) async -> TriggerEvaluationResult {
        
        let currentTemp = condition.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
        let targetTemp = condition.targetTemperature
        let tolerance = condition.temperatureTolerance
        
        let triggered: Bool
        let confidence: Double
        let triggerReason: String
        
        switch condition.comparisonType {
        case .above:
            triggered = currentTemp > targetTemp
            confidence = min(1.0, max(0.0, (currentTemp - targetTemp) / 10.0))
            triggerReason = triggered ? 
                "Temperature \(currentTemp, specifier: "%.1f")° is above target \(targetTemp, specifier: "%.1f")°" :
                "Temperature \(currentTemp, specifier: "%.1f")° is below target \(targetTemp, specifier: "%.1f")°"
            
        case .below:
            triggered = currentTemp < targetTemp
            confidence = min(1.0, max(0.0, (targetTemp - currentTemp) / 10.0))
            triggerReason = triggered ?
                "Temperature \(currentTemp, specifier: "%.1f")° is below target \(targetTemp, specifier: "%.1f")°" :
                "Temperature \(currentTemp, specifier: "%.1f")° is above target \(targetTemp, specifier: "%.1f")°"
            
        case .equals:
            let difference = abs(currentTemp - targetTemp)
            triggered = difference <= tolerance
            confidence = max(0.0, 1.0 - (difference / tolerance))
            triggerReason = triggered ?
                "Temperature \(currentTemp, specifier: "%.1f")° matches target \(targetTemp, specifier: "%.1f")° (±\(tolerance, specifier: "%.1f")°)" :
                "Temperature \(currentTemp, specifier: "%.1f")° differs from target \(targetTemp, specifier: "%.1f")° by \(difference, specifier: "%.1f")°"
            
        case .between:
            if let minTemp = condition.minTemperature, let maxTemp = condition.maxTemperature {
                triggered = currentTemp >= minTemp && currentTemp <= maxTemp
                confidence = triggered ? 1.0 : 0.0
                triggerReason = triggered ?
                    "Temperature \(currentTemp, specifier: "%.1f")° is within range \(minTemp, specifier: "%.1f")° - \(maxTemp, specifier: "%.1f")°" :
                    "Temperature \(currentTemp, specifier: "%.1f")° is outside range \(minTemp, specifier: "%.1f")° - \(maxTemp, specifier: "%.1f")°"
            } else {
                triggered = false
                confidence = 0.0
                triggerReason = "Invalid temperature range configuration"
            }
        }
        
        let metadata = [
            "current_temperature": String(currentTemp),
            "target_temperature": String(targetTemp),
            "comparison_type": condition.comparisonType.rawValue,
            "uses_feels_like": String(condition.useFeelsLike)
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            condition: condition,
            triggered: triggered,
            confidence: confidence,
            weatherData: weatherData,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
    
    private func evaluateTemperatureRange(
        _ condition: TriggerCondition,
        reminderId: UUID,
        weatherData: WeatherData
    ) async -> TriggerEvaluationResult {
        
        guard let minTemp = condition.minTemperature,
              let maxTemp = condition.maxTemperature else {
            return TriggerEvaluationResult(
                reminderId: reminderId,
                condition: condition,
                triggered: false,
                confidence: 0.0,
                weatherData: weatherData,
                triggerReason: "Invalid temperature range - missing min or max temperature"
            )
        }
        
        let currentTemp = condition.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
        let triggered = currentTemp >= minTemp && currentTemp <= maxTemp
        
        let confidence: Double
        if triggered {
            // Calculate confidence based on how far from the edges we are
            let rangeWidth = maxTemp - minTemp
            let distanceFromMin = currentTemp - minTemp
            let distanceFromMax = maxTemp - currentTemp
            let minDistance = min(distanceFromMin, distanceFromMax)
            confidence = min(1.0, minDistance / (rangeWidth * 0.1)) // 10% of range for full confidence
        } else {
            confidence = 0.0
        }
        
        let triggerReason = triggered ?
            "Temperature \(currentTemp, specifier: "%.1f")° is within range \(minTemp, specifier: "%.1f")° - \(maxTemp, specifier: "%.1f")°" :
            "Temperature \(currentTemp, specifier: "%.1f")° is outside range \(minTemp, specifier: "%.1f")° - \(maxTemp, specifier: "%.1f")°"
        
        let metadata = [
            "current_temperature": String(currentTemp),
            "min_temperature": String(minTemp),
            "max_temperature": String(maxTemp),
            "uses_feels_like": String(condition.useFeelsLike)
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            condition: condition,
            triggered: triggered,
            confidence: confidence,
            weatherData: weatherData,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
}

// MARK: - Performance Metrics

extension TriggerEngine {
    
    private func updatePerformanceMetrics(duration: TimeInterval) {
        lastEvaluationTime = Date()
        
        if averageEvaluationDuration == 0 {
            averageEvaluationDuration = duration
        } else {
            averageEvaluationDuration = (averageEvaluationDuration * 0.8) + (duration * 0.2)
        }
        
        logger.debug("Evaluation #\(evaluationCount) completed in \(duration)s (avg: \(averageEvaluationDuration)s)")
    }
    
    func getPerformanceMetrics() -> (count: Int, lastEvaluation: Date?, averageDuration: TimeInterval) {
        return (evaluationCount, lastEvaluationTime, averageEvaluationDuration)
    }
    
    func clearCaches() {
        evaluationCache.removeAll()
        historicalDataCache.removeAll()
        trendAnalysisCache.removeAll()
        logger.info("Cleared all TriggerEngine caches")
    }
}