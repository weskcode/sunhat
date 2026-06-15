//
//  TriggerEngine.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation
import UserNotifications
import BackgroundTasks
import os

// MARK: - Trigger Evaluation Result

struct TriggerEvaluationResult: Sendable {
    let reminderId: UUID
    let conditionData: TriggerConditionData  // Changed to Sendable version
    let triggered: Bool
    let confidence: Double
    let evaluationTime: Date
    let weatherData: WeatherDataTransfer?    // Changed to Sendable version
    let triggerReason: String
    let nextEvaluationTime: Date?
    let metadata: [String: String]
    
    nonisolated init(
        reminderId: UUID,
        conditionData: TriggerConditionData,
        triggered: Bool,
        confidence: Double = 1.0,
        weatherData: WeatherDataTransfer? = nil,
        triggerReason: String = "",
        nextEvaluationTime: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.reminderId = reminderId
        self.conditionData = conditionData
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
    let historicalData: [WeatherDataTransfer] // Changed to Sendable version
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

// MARK: - Import Sendable Data Types
// ReminderEvaluationData is now defined in WeatherModelActor.swift

// MARK: - Main Trigger Engine Actor

actor TriggerEngine {
    
    @MainActor private static var _instances: [ObjectIdentifier: TriggerEngine] = [:]
    
    static func shared(modelContainer: ModelContainer) async -> TriggerEngine {
        let key = ObjectIdentifier(modelContainer)
        
        return await MainActor.run {
            if let existing = _instances[key] {
                return existing
            }
            
            let new = TriggerEngine(modelContainer: modelContainer)
            _instances[key] = new
            return new
        }
    }
    
    internal let modelActor: WeatherModelActor
    let logger = Logger(subsystem: "org.wesley.sunhat", category: "TriggerEngine")
    
    // Evaluation caches
    var evaluationCache: [UUID: TriggerEvaluationResult] = [:]
    var historicalDataCache: [String: HistoricalWeatherContext] = [:]
    var trendAnalysisCache: [String: TrendAnalysis] = [:]
    
    // Performance metrics
    private var evaluationCount = 0
    private var lastEvaluationTime: Date?
    private var averageEvaluationDuration: TimeInterval = 0
    
    private init(modelContainer: ModelContainer) {
        self.modelActor = WeatherModelActor(modelContainer: modelContainer)
        logger.info("TriggerEngine initialized with ModelActor")
    }
    
    // MARK: - Main Evaluation Methods
    
    func evaluateAllActiveReminders() async -> [TriggerEvaluationResult] {
        let startTime = Date()
        evaluationCount += 1
        
        logger.debug("Starting evaluation of all active reminders")
        
        do {
            // Fetch reminder data through ModelActor to avoid concurrency issues
            let reminderData = try await modelActor.fetchActiveRemindersData()
            logger.debug("Found \(reminderData.count) active reminders to evaluate")
            
            // Group reminders by location to optimize weather data fetching
            let locationGroups = Dictionary(grouping: reminderData) { data in
                "\(data.clLocation.coordinate.latitude),\(data.clLocation.coordinate.longitude)"
            }
            
            var allResults: [TriggerEvaluationResult] = []
            
            // Evaluate each location group
            for (_, dataList) in locationGroups {
                guard let firstData = dataList.first else {
                    continue
                }
                
                let location = firstData.clLocation
                let results = await evaluateRemindersForLocation(dataList, at: location)
                allResults.append(contentsOf: results)
            }
            
            // Update performance metrics
            let duration = Date().timeIntervalSince(startTime)
            Task { [weak self] in
                await self?.updatePerformanceMetrics(duration: duration)
            }
            
            logger.info("Completed evaluation of \(reminderData.count) reminders in \(duration)s")
            return allResults
            
        } catch {
            logger.error("Failed to fetch active reminders: \(error)")
            return []
        }
    }
    
    func evaluateReminder(reminderId: UUID) async -> TriggerEvaluationResult? {
        // Use ModelActor to safely access SwiftData properties
        do {
            let reminderData = try await modelActor.fetchReminderEvaluationData(for: reminderId)
            guard let data = reminderData else { return nil }
            
            return await evaluateCondition(
                data.triggerCondition,
                for: data.reminderId,
                at: data.clLocation
            )
        } catch {
            logger.error("Failed to fetch reminder data for evaluation: \(error)")
            return nil
        }
    }
    
    func evaluateRemindersForLocation(_ reminderDataList: [ReminderEvaluationData], at location: CLLocation) async -> [TriggerEvaluationResult] {
        do {
            // Fetch current weather data for the location using Task isolation
            let weatherTransfer = try await Task { @MainActor in
                let weatherData = try await WeatherService.shared.fetchWeatherData(for: location)
                return ModelDataConverter.convertWeatherData(weatherData)
            }.value
            
            var results: [TriggerEvaluationResult] = []
            
            for reminderData in reminderDataList {
                if let result = await evaluateCondition(
                    reminderData.triggerCondition, 
                    for: reminderData.reminderId, 
                    at: location, 
                    with: weatherTransfer
                ) {
                    results.append(result)
                }
            }
            
            return results
            
        } catch {
            logger.warning("Failed to fetch weather data for location \(location.coordinate.latitude),\(location.coordinate.longitude): \(error)")
            return []
        }
    }
    
    // MARK: - Condition Evaluation Logic
    
    private func evaluateCondition(
        _ conditionData: TriggerConditionData,
        for reminderId: UUID,
        at location: CLLocation,
        with weatherData: WeatherDataTransfer? = nil
    ) async -> TriggerEvaluationResult? {
        
        // Check cache first
        if let cachedResult = getCachedResult(for: reminderId) {
            return cachedResult
        }
        
        let currentWeatherData: WeatherDataTransfer
        if let providedData = weatherData {
            currentWeatherData = providedData
        } else {
            do {
                currentWeatherData = try await Task { @MainActor in
                    let weather = try await WeatherService.shared.fetchWeatherData(for: location)
                    return ModelDataConverter.convertWeatherData(weather)
                }.value
            } catch {
                logger.warning("Failed to fetch weather data for evaluation: \(error)")
                return nil
            }
        }
        
        var result: TriggerEvaluationResult

        switch conditionData.triggerType {
        case .exactTemperature:
            result = await evaluateExactTemperature(conditionData, reminderId: reminderId, weatherData: currentWeatherData)

        case .temperatureRange:
            result = await evaluateTemperatureRange(conditionData, reminderId: reminderId, weatherData: currentWeatherData)

        case .consecutiveDays:
            result = await evaluateConsecutiveDays(conditionData, reminderId: reminderId, location: location, currentWeather: currentWeatherData)

        case .averageTemperature:
            result = await evaluateAverageTemperature(conditionData, reminderId: reminderId, location: location, currentWeather: currentWeatherData)

        case .seasonalMarker:
            result = await evaluateSeasonalMarker(conditionData, reminderId: reminderId, location: location, currentWeather: currentWeatherData)

        case .composite:
            result = await evaluateComposite(conditionData, reminderId: reminderId, location: location, weatherData: currentWeatherData)

        case .historicalComparison:
            result = await evaluateHistoricalComparison(conditionData, reminderId: reminderId, location: location, currentWeather: currentWeatherData)
        }

        // Apply sky condition filter — only when temperature already matched
        if conditionData.hasSkyConditionFilter && result.triggered {
            let skyMatch = evaluateSkyCondition(conditionData, weatherData: currentWeatherData)
            if !skyMatch {
                result = TriggerEvaluationResult(
                    reminderId: reminderId,
                    conditionData: conditionData,
                    triggered: false,
                    confidence: result.confidence,
                    weatherData: currentWeatherData,
                    triggerReason: "Temperature matched but sky conditions didn't (\(conditionData.conditionModeRaw): \(conditionData.selectedSkyConditionsRaw))"
                )
            }
        }

        // Cache the result
        setCachedResult(result, for: reminderId)

        return result
    }
    
    // MARK: - Cache Helper Methods
    
    private func getCachedResult(for reminderId: UUID) -> TriggerEvaluationResult? {
        if let cachedResult = evaluationCache[reminderId],
           Date().timeIntervalSince(cachedResult.evaluationTime) < 300 { // 5 min cache
            return cachedResult
        }
        return nil
    }
    
    private func setCachedResult(_ result: TriggerEvaluationResult, for reminderId: UUID) {
        evaluationCache[reminderId] = result
    }

    // MARK: - Sky Condition Evaluation

    /// Evaluates whether the current weather condition matches the sky condition filter
    private func evaluateSkyCondition(
        _ conditionData: TriggerConditionData,
        weatherData: WeatherDataTransfer
    ) -> Bool {
        guard conditionData.hasSkyConditionFilter,
              !conditionData.selectedSkyConditionsRaw.isEmpty else {
            return true // No sky filter = always matches
        }

        // Parse stored sky conditions
        let rawValues = conditionData.selectedSkyConditionsRaw.components(separatedBy: ",")
        let selectedConditions = Set(rawValues.compactMap { SkyCondition(rawValue: $0) })
        guard !selectedConditions.isEmpty else { return true }

        // Map real weather condition to SkyCondition (inline to avoid actor isolation)
        let currentSky: SkyCondition
        switch weatherData.weatherCondition {
        case .clear: currentSky = .sunny
        case .partlyCloudy: currentSky = .partlyCloudy
        case .cloudy, .overcast, .fog: currentSky = .cloudy
        case .rain, .drizzle, .thunderstorm: currentSky = .rainy
        case .snow, .sleet, .hail: currentSky = .snowy
        case .windy, .unknown: currentSky = .sunny
        }

        // Evaluate based on mode
        let mode = ConditionSelectionMode(rawValue: conditionData.conditionModeRaw) ?? .include
        switch mode {
        case .include:
            return selectedConditions.contains(currentSky)
        case .exclude:
            return !selectedConditions.contains(currentSky)
        }
    }
}

// MARK: - Temperature Evaluators Extension

extension TriggerEngine {
    
    private func evaluateExactTemperature(
        _ conditionData: TriggerConditionData,
        reminderId: UUID,
        weatherData: WeatherDataTransfer
    ) async -> TriggerEvaluationResult {
        
        let currentTemp = conditionData.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
        let targetTemp = conditionData.targetTemperature
        let tolerance = conditionData.temperatureTolerance
        
        let triggered: Bool
        let confidence: Double
        let triggerReason: String
        
        switch conditionData.comparisonType {
        case .above:
            triggered = currentTemp > targetTemp
            confidence = min(1.0, max(0.0, (currentTemp - targetTemp) / 10.0))
            triggerReason = triggered ? 
                "Temperature \(String(format: "%.1f", currentTemp))° is above target \(String(format: "%.1f", targetTemp))°" :
                "Temperature \(String(format: "%.1f", currentTemp))° is below target \(String(format: "%.1f", targetTemp))°"
            
        case .below:
            triggered = currentTemp < targetTemp
            confidence = min(1.0, max(0.0, (targetTemp - currentTemp) / 10.0))
            triggerReason = triggered ?
                "Temperature \(String(format: "%.1f", currentTemp))° is below target \(String(format: "%.1f", targetTemp))°" :
                "Temperature \(String(format: "%.1f", currentTemp))° is above target \(String(format: "%.1f", targetTemp))°"
            
        case .equals:
            let difference = abs(currentTemp - targetTemp)
            triggered = difference <= tolerance
            confidence = max(0.0, 1.0 - (difference / tolerance))
            triggerReason = triggered ?
                "Temperature \(String(format: "%.1f", currentTemp))° matches target \(String(format: "%.1f", targetTemp))° (±\(String(format: "%.1f", tolerance))°)" :
                "Temperature \(String(format: "%.1f", currentTemp))° differs from target \(String(format: "%.1f", targetTemp))° by \(String(format: "%.1f", difference))°"
            
        case .between:
            if let minTemp = conditionData.minTemperature, let maxTemp = conditionData.maxTemperature {
                triggered = currentTemp >= minTemp && currentTemp <= maxTemp
                confidence = triggered ? 1.0 : 0.0
                triggerReason = triggered ?
                    "Temperature \(String(format: "%.1f", currentTemp))° is within range \(String(format: "%.1f", minTemp))° - \(String(format: "%.1f", maxTemp))°" :
                    "Temperature \(String(format: "%.1f", currentTemp))° is outside range \(String(format: "%.1f", minTemp))° - \(String(format: "%.1f", maxTemp))°"
            } else {
                triggered = false
                confidence = 0.0
                triggerReason = "Invalid temperature range configuration"
            }
        }
        
        let metadata = [
            "current_temperature": String(currentTemp),
            "target_temperature": String(targetTemp),
            "comparison_type": conditionData.comparisonType.rawValue,
            "uses_feels_like": String(conditionData.useFeelsLike)
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            conditionData: conditionData,
            triggered: triggered,
            confidence: confidence,
            weatherData: weatherData,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
    
    private func evaluateTemperatureRange(
        _ conditionData: TriggerConditionData,
        reminderId: UUID,
        weatherData: WeatherDataTransfer
    ) async -> TriggerEvaluationResult {
        
        guard let minTemp = conditionData.minTemperature,
              let maxTemp = conditionData.maxTemperature else {
            return TriggerEvaluationResult(
                reminderId: reminderId,
                conditionData: conditionData,
                triggered: false,
                confidence: 0.0,
                weatherData: weatherData,
                triggerReason: "Invalid temperature range - missing min or max temperature"
            )
        }
        
        let currentTemp = conditionData.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
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
            "Temperature \(String(format: "%.1f", currentTemp))° is within range \(String(format: "%.1f", minTemp))° - \(String(format: "%.1f", maxTemp))°" :
            "Temperature \(String(format: "%.1f", currentTemp))° is outside range \(String(format: "%.1f", minTemp))° - \(String(format: "%.1f", maxTemp))°"
        
        let metadata = [
            "current_temperature": String(currentTemp),
            "min_temperature": String(minTemp),
            "max_temperature": String(maxTemp),
            "uses_feels_like": String(conditionData.useFeelsLike)
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            conditionData: conditionData,
            triggered: triggered,
            confidence: confidence,
            weatherData: weatherData,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
    
    // MARK: - Additional Evaluation Methods
    // Note: evaluateConsecutiveDays and evaluateAverageTemperature are implemented in TriggerEngine+TrendAnalysis.swift
    

    
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
        
        logger.debug("Evaluation #\(self.evaluationCount) completed in \(duration)s (avg: \(self.averageEvaluationDuration)s)")
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
