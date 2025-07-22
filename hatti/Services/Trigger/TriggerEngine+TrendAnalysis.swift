//
//  TriggerEngine+TrendAnalysis.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Trend Analysis Extension

extension TriggerEngine {
    
    func evaluateConsecutiveDays(
        _ condition: TriggerCondition,
        reminderId: UUID,
        location: CLLocation,
        currentWeather: WeatherData
    ) async -> TriggerEvaluationResult {
        
        let requiredConsecutiveDays = condition.consecutiveDays
        let targetTemperature = condition.targetTemperature
        let comparisonType = condition.comparisonType
        let useFeelsLike = condition.useFeelsLike
        
        // Get historical weather data for trend analysis
        let trendAnalysis = await getTrendAnalysis(
            for: location,
            days: requiredConsecutiveDays + 3, // Get extra days for context
            useFeelsLike: useFeelsLike
        )
        
        let triggered: Bool
        let confidence: Double
        let triggerReason: String
        let metadata: [String: String]
        
        switch comparisonType {
        case .above:
            triggered = trendAnalysis.consecutiveDaysAbove >= requiredConsecutiveDays
            confidence = calculateConsecutiveDaysConfidence(
                actual: trendAnalysis.consecutiveDaysAbove,
                required: requiredConsecutiveDays,
                currentTemp: useFeelsLike ? currentWeather.apparentTemperature : currentWeather.temperature,
                targetTemp: targetTemperature,
                isAbove: true
            )
            triggerReason = triggered ?
                "Temperature has been above \(targetTemperature, specifier: "%.1f")° for \(trendAnalysis.consecutiveDaysAbove) consecutive days (required: \(requiredConsecutiveDays))" :
                "Temperature has been above \(targetTemperature, specifier: "%.1f")° for only \(trendAnalysis.consecutiveDaysAbove) consecutive days (required: \(requiredConsecutiveDays))"
            
        case .below:
            triggered = trendAnalysis.consecutiveDaysBelow >= requiredConsecutiveDays
            confidence = calculateConsecutiveDaysConfidence(
                actual: trendAnalysis.consecutiveDaysBelow,
                required: requiredConsecutiveDays,
                currentTemp: useFeelsLike ? currentWeather.apparentTemperature : currentWeather.temperature,
                targetTemp: targetTemperature,
                isAbove: false
            )
            triggerReason = triggered ?
                "Temperature has been below \(targetTemperature, specifier: "%.1f")° for \(trendAnalysis.consecutiveDaysBelow) consecutive days (required: \(requiredConsecutiveDays))" :
                "Temperature has been below \(targetTemperature, specifier: "%.1f")° for only \(trendAnalysis.consecutiveDaysBelow) consecutive days (required: \(requiredConsecutiveDays))"
            
        case .equals, .between:
            // For equals/between, we need custom logic for consecutive days
            let consecutiveDaysInRange = await calculateConsecutiveDaysInRange(
                location: location,
                condition: condition,
                days: requiredConsecutiveDays + 3
            )
            
            triggered = consecutiveDaysInRange >= requiredConsecutiveDays
            confidence = Double(consecutiveDaysInRange) / Double(requiredConsecutiveDays)
            triggerReason = triggered ?
                "Temperature has been in target range for \(consecutiveDaysInRange) consecutive days (required: \(requiredConsecutiveDays))" :
                "Temperature has been in target range for only \(consecutiveDaysInRange) consecutive days (required: \(requiredConsecutiveDays))"
        }
        
        metadata = [
            "required_consecutive_days": String(requiredConsecutiveDays),
            "consecutive_days_above": String(trendAnalysis.consecutiveDaysAbove),
            "consecutive_days_below": String(trendAnalysis.consecutiveDaysBelow),
            "trend_direction": String(describing: trendAnalysis.trendDirection),
            "average_over_period": String(trendAnalysis.averageOverPeriod),
            "volatility": String(trendAnalysis.volatility),
            "uses_feels_like": String(useFeelsLike)
        ]
        
        // Calculate next evaluation time based on trend
        let nextEvaluationTime = calculateNextEvaluationTime(
            triggered: triggered,
            trendAnalysis: trendAnalysis,
            condition: condition
        )
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            condition: condition,
            triggered: triggered,
            confidence: confidence,
            weatherData: currentWeather,
            triggerReason: triggerReason,
            nextEvaluationTime: nextEvaluationTime,
            metadata: metadata
        )
    }
    
    func evaluateAverageTemperature(
        _ condition: TriggerCondition,
        reminderId: UUID,
        location: CLLocation,
        currentWeather: WeatherData
    ) async -> TriggerEvaluationResult {
        
        let averagingPeriod = condition.averagingPeriod
        let targetTemperature = condition.targetTemperature
        let comparisonType = condition.comparisonType
        let useFeelsLike = condition.useFeelsLike
        
        // Get trend analysis for the averaging period
        let trendAnalysis = await getTrendAnalysis(
            for: location,
            days: averagingPeriod,
            useFeelsLike: useFeelsLike
        )
        
        let averageTemp = trendAnalysis.averageOverPeriod
        let triggered: Bool
        let confidence: Double
        let triggerReason: String
        
        switch comparisonType {
        case .above:
            triggered = averageTemp > targetTemperature
            confidence = min(1.0, max(0.0, (averageTemp - targetTemperature) / 5.0))
            triggerReason = triggered ?
                "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days is above target \(targetTemperature, specifier: "%.1f")°" :
                "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days is below target \(targetTemperature, specifier: "%.1f")°"
            
        case .below:
            triggered = averageTemp < targetTemperature
            confidence = min(1.0, max(0.0, (targetTemperature - averageTemp) / 5.0))
            triggerReason = triggered ?
                "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days is below target \(targetTemperature, specifier: "%.1f")°" :
                "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days is above target \(targetTemperature, specifier: "%.1f")°"
            
        case .equals:
            let difference = abs(averageTemp - targetTemperature)
            let tolerance = condition.temperatureTolerance
            triggered = difference <= tolerance
            confidence = max(0.0, 1.0 - (difference / tolerance))
            triggerReason = triggered ?
                "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days matches target \(targetTemperature, specifier: "%.1f")° (±\(tolerance, specifier: "%.1f")°)" :
                "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days differs from target by \(difference, specifier: "%.1f")°"
            
        case .between:
            if let minTemp = condition.minTemperature, let maxTemp = condition.maxTemperature {
                triggered = averageTemp >= minTemp && averageTemp <= maxTemp
                confidence = triggered ? 1.0 : 0.0
                triggerReason = triggered ?
                    "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days is within range \(minTemp, specifier: "%.1f")° - \(maxTemp, specifier: "%.1f")°" :
                    "Average temperature \(averageTemp, specifier: "%.1f")° over \(averagingPeriod) days is outside range \(minTemp, specifier: "%.1f")° - \(maxTemp, specifier: "%.1f")°"
            } else {
                triggered = false
                confidence = 0.0
                triggerReason = "Invalid temperature range configuration"
            }
        }
        
        let metadata = [
            "averaging_period": String(averagingPeriod),
            "average_temperature": String(averageTemp),
            "target_temperature": String(targetTemperature),
            "trend_direction": String(describing: trendAnalysis.trendDirection),
            "volatility": String(trendAnalysis.volatility),
            "uses_feels_like": String(useFeelsLike)
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            condition: condition,
            triggered: triggered,
            confidence: confidence,
            weatherData: currentWeather,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
    
    // MARK: - Helper Methods
    
    func getTrendAnalysis(
        for location: CLLocation,
        days: Int,
        useFeelsLike: Bool = false
    ) async -> TrendAnalysis {
        
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)_\(days)_\(useFeelsLike)"
        
        // Check cache first
        if let cachedAnalysis = trendAnalysisCache[cacheKey] {
            return cachedAnalysis
        }
        
        guard let modelContext = modelContext else {
            return createEmptyTrendAnalysis()
        }
        
        // Fetch historical weather data
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let searchRadius: CLLocationDistance = 10000 // 10km radius
        let minLat = location.coordinate.latitude - (searchRadius / 111000)
        let maxLat = location.coordinate.latitude + (searchRadius / 111000)
        let minLon = location.coordinate.longitude - (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        let maxLon = location.coordinate.longitude + (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        
        let predicate = #Predicate<WeatherData> { weather in
            weather.timestamp >= startDate &&
            weather.timestamp <= endDate &&
            weather.location?.latitude != nil &&
            weather.location?.longitude != nil &&
            weather.location!.latitude >= minLat &&
            weather.location!.latitude <= maxLat &&
            weather.location!.longitude >= minLon &&
            weather.location!.longitude <= maxLon
        }
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .forward)]
        )
        
        do {
            let weatherData = try modelContext.fetch(descriptor)
            let analysis = analyzeTrend(weatherData: weatherData, useFeelsLike: useFeelsLike)
            
            // Cache the result
            trendAnalysisCache[cacheKey] = analysis
            
            return analysis
            
        } catch {
            logger.error("Failed to fetch weather data for trend analysis: \(error)")
            return createEmptyTrendAnalysis()
        }
    }
    
    private func analyzeTrend(weatherData: [WeatherData], useFeelsLike: Bool) -> TrendAnalysis {
        guard !weatherData.isEmpty else {
            return createEmptyTrendAnalysis()
        }
        
        let temperatures = weatherData.map { useFeelsLike ? $0.apparentTemperature : $0.temperature }
        
        // Calculate basic statistics
        let average = temperatures.reduce(0, +) / Double(temperatures.count)
        let peak = temperatures.max() ?? 0
        let low = temperatures.min() ?? 0
        
        // Calculate volatility (standard deviation)
        let variance = temperatures.map { pow($0 - average, 2) }.reduce(0, +) / Double(temperatures.count)
        let volatility = sqrt(variance)
        
        // Determine trend direction
        let trendDirection = calculateTrendDirection(temperatures: temperatures)
        
        // Calculate consecutive days above/below average
        let consecutiveAbove = calculateConsecutiveDays(temperatures: temperatures, threshold: average, above: true)
        let consecutiveBelow = calculateConsecutiveDays(temperatures: temperatures, threshold: average, above: false)
        
        return TrendAnalysis(
            consecutiveDaysAbove: consecutiveAbove,
            consecutiveDaysBelow: consecutiveBelow,
            averageOverPeriod: average,
            trendDirection: trendDirection,
            volatility: volatility,
            peakTemperature: peak,
            lowTemperature: low
        )
    }
    
    private func calculateTrendDirection(temperatures: [Double]) -> TrendAnalysis.TrendDirection {
        guard temperatures.count >= 3 else { return .stable }
        
        // Simple linear regression to determine trend
        let n = Double(temperatures.count)
        let x = Array(0..<temperatures.count).map(Double.init)
        let y = temperatures
        
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        
        // Calculate volatility as measure of stability
        let average = sumY / n
        let variance = y.map { pow($0 - average, 2) }.reduce(0, +) / n
        let volatilityThreshold = sqrt(variance) / average
        
        if volatilityThreshold > 0.15 { // 15% coefficient of variation
            return .volatile
        } else if abs(slope) < 0.1 {
            return .stable
        } else if slope > 0 {
            return .rising
        } else {
            return .falling
        }
    }
    
    private func calculateConsecutiveDays(temperatures: [Double], threshold: Double, above: Bool) -> Int {
        var maxConsecutive = 0
        var currentConsecutive = 0
        
        for temp in temperatures.reversed() { // Start from most recent
            let meetsCondition = above ? (temp > threshold) : (temp < threshold)
            
            if meetsCondition {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                break // Stop at first non-matching day (since we want consecutive from today)
            }
        }
        
        return currentConsecutive // Return current consecutive streak
    }
    
    private func calculateConsecutiveDaysInRange(
        location: CLLocation,
        condition: TriggerCondition,
        days: Int
    ) async -> Int {
        
        guard let modelContext = modelContext,
              let minTemp = condition.minTemperature,
              let maxTemp = condition.maxTemperature else {
            return 0
        }
        
        // Similar to getTrendAnalysis but specifically for range checking
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let searchRadius: CLLocationDistance = 10000
        let minLat = location.coordinate.latitude - (searchRadius / 111000)
        let maxLat = location.coordinate.latitude + (searchRadius / 111000)
        let minLon = location.coordinate.longitude - (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        let maxLon = location.coordinate.longitude + (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        
        let predicate = #Predicate<WeatherData> { weather in
            weather.timestamp >= startDate &&
            weather.timestamp <= endDate &&
            weather.location?.latitude != nil &&
            weather.location?.longitude != nil &&
            weather.location!.latitude >= minLat &&
            weather.location!.latitude <= maxLat &&
            weather.location!.longitude >= minLon &&
            weather.location!.longitude <= maxLon
        }
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .reverse)]
        )
        
        do {
            let weatherData = try modelContext.fetch(descriptor)
            var consecutiveDays = 0
            
            for data in weatherData {
                let temp = condition.useFeelsLike ? data.apparentTemperature : data.temperature
                
                if temp >= minTemp && temp <= maxTemp {
                    consecutiveDays += 1
                } else {
                    break // Stop at first day outside range
                }
            }
            
            return consecutiveDays
            
        } catch {
            logger.error("Failed to calculate consecutive days in range: \(error)")
            return 0
        }
    }
    
    private func calculateConsecutiveDaysConfidence(
        actual: Int,
        required: Int,
        currentTemp: Double,
        targetTemp: Double,
        isAbove: Bool
    ) -> Double {
        
        if actual >= required {
            return 1.0
        }
        
        // Base confidence on how close we are to the requirement
        let progressConfidence = Double(actual) / Double(required)
        
        // Bonus confidence if current temperature strongly supports the condition
        let tempDifference = abs(currentTemp - targetTemp)
        let tempConfidence: Double
        
        if isAbove {
            tempConfidence = currentTemp > targetTemp ? min(1.0, (currentTemp - targetTemp) / 10.0) : 0.0
        } else {
            tempConfidence = currentTemp < targetTemp ? min(1.0, (targetTemp - currentTemp) / 10.0) : 0.0
        }
        
        // Combine both confidence factors
        return (progressConfidence * 0.7) + (tempConfidence * 0.3)
    }
    
    private func calculateNextEvaluationTime(
        triggered: Bool,
        trendAnalysis: TrendAnalysis,
        condition: TriggerCondition
    ) -> Date? {
        
        let calendar = Calendar.current
        let baseInterval: TimeInterval
        
        if triggered {
            // If already triggered, check less frequently
            baseInterval = 6 * 3600 // 6 hours
        } else {
            // Adjust check frequency based on how close we are
            switch trendAnalysis.trendDirection {
            case .rising, .falling:
                baseInterval = 2 * 3600 // 2 hours for trending temperatures
            case .stable:
                baseInterval = 4 * 3600 // 4 hours for stable temperatures
            case .volatile:
                baseInterval = 1 * 3600 // 1 hour for volatile conditions
            }
        }
        
        return calendar.date(byAdding: .second, value: Int(baseInterval), to: Date())
    }
    
    private func createEmptyTrendAnalysis() -> TrendAnalysis {
        return TrendAnalysis(
            consecutiveDaysAbove: 0,
            consecutiveDaysBelow: 0,
            averageOverPeriod: 0.0,
            trendDirection: .stable,
            volatility: 0.0,
            peakTemperature: 0.0,
            lowTemperature: 0.0
        )
    }
}
