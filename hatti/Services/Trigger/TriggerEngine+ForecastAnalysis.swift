//
//  TriggerEngine+ForecastAnalysis.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation
import os

// MARK: - Forecast Analysis Extension

extension TriggerEngine {
    
    func evaluateComposite(
        _ condition: TriggerCondition,
        reminderId: UUID,
        location: CLLocation,
        weatherData: WeatherData
    ) async -> TriggerEvaluationResult {
        
        var conditionsMet: [String] = []
        var conditionsFailed: [String] = []
        var totalConfidence = 0.0
        var conditionCount = 0
        
        // 1. Temperature condition (always present in composite)
        let tempResult = await evaluateTemperatureComponent(condition, weatherData: weatherData)
        if tempResult.met {
            conditionsMet.append(tempResult.description)
        } else {
            conditionsFailed.append(tempResult.description)
        }
        totalConfidence += tempResult.confidence
        conditionCount += 1
        
        // 2. Humidity condition (if required)
        if condition.requiresHumidity {
            let humidityResult = evaluateHumidityComponent(condition, weatherData: weatherData)
            if humidityResult.met {
                conditionsMet.append(humidityResult.description)
            } else {
                conditionsFailed.append(humidityResult.description)
            }
            totalConfidence += humidityResult.confidence
            conditionCount += 1
        }
        
        // 3. Wind speed condition (if required)
        if condition.requiresWindSpeed {
            let windResult = evaluateWindSpeedComponent(condition, weatherData: weatherData)
            if windResult.met {
                conditionsMet.append(windResult.description)
            } else {
                conditionsFailed.append(windResult.description)
            }
            totalConfidence += windResult.confidence
            conditionCount += 1
        }
        
        // 4. Precipitation condition (if required)
        if condition.requiresPrecipitation {
            let precipResult = await evaluatePrecipitationComponent(condition, location: location, weatherData: weatherData)
            if precipResult.met {
                conditionsMet.append(precipResult.description)
            } else {
                conditionsFailed.append(precipResult.description)
            }
            totalConfidence += precipResult.confidence
            conditionCount += 1
        }
        
        // 5. Time constraints (if specified)
        if condition.timeOfDayStart != nil || condition.timeOfDayEnd != nil {
            let timeResult = evaluateTimeConstraints(condition)
            if timeResult.met {
                conditionsMet.append(timeResult.description)
            } else {
                conditionsFailed.append(timeResult.description)
            }
            totalConfidence += timeResult.confidence
            conditionCount += 1
        }
        
        // Calculate overall result
        let allConditionsMet = conditionsFailed.isEmpty
        let averageConfidence = conditionCount > 0 ? totalConfidence / Double(conditionCount) : 0.0
        
        let triggerReason: String
        if allConditionsMet {
            triggerReason = "All composite conditions met: " + conditionsMet.joined(separator: ", ")
        } else {
            triggerReason = "Composite conditions not fully met. Met: [\(conditionsMet.joined(separator: ", "))]. Failed: [\(conditionsFailed.joined(separator: ", "))]"
        }
        
        let metadata = [
            "total_conditions": String(conditionCount),
            "conditions_met": String(conditionsMet.count),
            "conditions_failed": String(conditionsFailed.count),
            "temperature_included": "true",
            "humidity_required": String(condition.requiresHumidity),
            "wind_required": String(condition.requiresWindSpeed),
            "precipitation_required": String(condition.requiresPrecipitation),
            "time_constraints": String(condition.timeOfDayStart != nil || condition.timeOfDayEnd != nil)
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            condition: condition,
            triggered: allConditionsMet,
            confidence: averageConfidence,
            weatherData: weatherData,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
    
    // MARK: - Forecast-Based Predictions
    
    func evaluateForecastPrediction(
        _ condition: TriggerCondition,
        reminderId: UUID,
        location: CLLocation,
        advanceHours: Int = 24
    ) async -> TriggerEvaluationResult {
        
        do {
            let weatherData = try await WeatherService.shared.fetchWeatherData(for: location)
            let forecastAnalysis = analyzeForecastForCondition(
                condition: condition,
                weatherData: weatherData,
                advanceHours: advanceHours
            )
            
            let triggered = forecastAnalysis.willTriggerInAdvancePeriod
            let confidence = forecastAnalysis.confidence
            let triggerReason = forecastAnalysis.description
            
            let metadata: [String: String] = [
                "advance_hours": String(advanceHours),
                "forecast_days_analyzed": String(forecastAnalysis.daysAnalyzed),
                "trigger_probability": String(forecastAnalysis.triggerProbability),
                "earliest_trigger_time": forecastAnalysis.earliestTriggerTime?.ISO8601Format() ?? "none",
                "forecast_confidence": String(forecastAnalysis.forecastConfidence),
                "weather_pattern": forecastAnalysis.weatherPattern
            ]
            
            let nextEvaluationTime = calculateForecastEvaluationTime(
                triggered: triggered,
                forecastAnalysis: forecastAnalysis
            )
            
            return TriggerEvaluationResult(
                reminderId: reminderId,
                condition: condition,
                triggered: triggered,
                confidence: confidence,
                weatherData: weatherData,
                triggerReason: triggerReason,
                nextEvaluationTime: nextEvaluationTime,
                metadata: metadata
            )
            
        } catch {
            self.logger.error("Failed to fetch weather data for forecast prediction: \(error)")
            return TriggerEvaluationResult(
                reminderId: reminderId,
                condition: condition,
                triggered: false,
                confidence: 0.0,
                triggerReason: "Unable to fetch forecast data: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Component Evaluators
    
    private func evaluateTemperatureComponent(
        _ condition: TriggerCondition,
        weatherData: WeatherData
    ) async -> ComponentEvaluationResult {
        
        let currentTemp = condition.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
        let targetTemp = condition.targetTemperature
        
        switch condition.comparisonType {
        case .above:
            let met = currentTemp > targetTemp
            let confidence = met ? min(1.0, (currentTemp - targetTemp) / 10.0) : max(0.0, 1.0 - (targetTemp - currentTemp) / 10.0)
            return ComponentEvaluationResult(
                met: met,
                confidence: confidence,
                description: "Temperature \(String(format: "%.1f", currentTemp))° \(met ? "above" : "below") target \(String(format: "%.1f", targetTemp))°"
            )
            
        case .below:
            let met = currentTemp < targetTemp
            let confidence = met ? min(1.0, (targetTemp - currentTemp) / 10.0) : max(0.0, 1.0 - (currentTemp - targetTemp) / 10.0)
            return ComponentEvaluationResult(
                met: met,
                confidence: confidence,
                description: "Temperature \(String(format: "%.1f", currentTemp))° \(met ? "below" : "above") target \(String(format: "%.1f", targetTemp))°"
            )
            
        case .equals:
            let difference = abs(currentTemp - targetTemp)
            let tolerance = condition.temperatureTolerance
            let met = difference <= tolerance
            let confidence = met ? max(0.0, 1.0 - (difference / tolerance)) : 0.0
            return ComponentEvaluationResult(
                met: met,
                confidence: confidence,
                description: "Temperature \(String(format: "%.1f", currentTemp))° \(met ? "matches" : "differs from") target \(String(format: "%.1f", targetTemp))° (±\(String(format: "%.1f", tolerance))°)"
            )
            
        case .between:
            guard let minTemp = condition.minTemperature, let maxTemp = condition.maxTemperature else {
                return ComponentEvaluationResult(
                    met: false,
                    confidence: 0.0,
                    description: "Invalid temperature range configuration"
                )
            }
            
            let met = currentTemp >= minTemp && currentTemp <= maxTemp
            let confidence = met ? 1.0 : 0.0
            return ComponentEvaluationResult(
                met: met,
                confidence: confidence,
                description: "Temperature \(String(format: "%.1f", currentTemp))° \(met ? "within" : "outside") range \(String(format: "%.1f", minTemp))°-\(String(format: "%.1f", maxTemp))°"
            )
        }
    }
    
    private func evaluateHumidityComponent(
        _ condition: TriggerCondition,
        weatherData: WeatherData
    ) -> ComponentEvaluationResult {
        
        guard let targetHumidity = condition.targetHumidity else {
            return ComponentEvaluationResult(
                met: false,
                confidence: 0.0,
                description: "No target humidity specified"
            )
        }
        
        let currentHumidity = Double(weatherData.humidity)
        let tolerance = condition.humidityTolerance
        let difference = abs(currentHumidity - targetHumidity)
        let met = difference <= tolerance
        let confidence = met ? max(0.0, 1.0 - (difference / tolerance)) : 0.0
        
        return ComponentEvaluationResult(
            met: met,
            confidence: confidence,
            description: "Humidity \(String(format: "%.0f", currentHumidity))% \(met ? "matches" : "differs from") target \(String(format: "%.0f", targetHumidity))% (±\(String(format: "%.0f", tolerance))%)"
        )
    }
    
    private func evaluateWindSpeedComponent(
        _ condition: TriggerCondition,
        weatherData: WeatherData
    ) -> ComponentEvaluationResult {
        
        guard let maxWindSpeed = condition.maxWindSpeed else {
            return ComponentEvaluationResult(
                met: false,
                confidence: 0.0,
                description: "No maximum wind speed specified"
            )
        }
        
        let currentWindSpeed = weatherData.windSpeed
        let met = currentWindSpeed <= maxWindSpeed
        let confidence = met ? min(1.0, (maxWindSpeed - currentWindSpeed) / maxWindSpeed) : 0.0
        
        return ComponentEvaluationResult(
            met: met,
            confidence: confidence,
            description: "Wind speed \(String(format: "%.1f", currentWindSpeed)) mph \(met ? "below" : "above") maximum \(String(format: "%.1f", maxWindSpeed)) mph"
        )
    }
    
    private func evaluatePrecipitationComponent(
        _ condition: TriggerCondition,
        location: CLLocation,
        weatherData: WeatherData
    ) async -> ComponentEvaluationResult {
        
        let precipitationRequirement = condition.precipitationRequirement
        
        switch precipitationRequirement {
        case .none:
            return ComponentEvaluationResult(
                met: true,
                confidence: 1.0,
                description: "No precipitation requirement"
            )
            
        case .dry:
            let met = weatherData.precipitationAmount == 0 && weatherData.precipitationType == .none
            return ComponentEvaluationResult(
                met: met,
                confidence: met ? 1.0 : 0.0,
                description: "Weather is \(met ? "dry" : "wet") (precipitation: \(String(format: "%.2f", weatherData.precipitationAmount)))"
            )
            
        case .anyPrecipitation:
            let met = weatherData.precipitationAmount > 0 || weatherData.precipitationType != .none
            return ComponentEvaluationResult(
                met: met,
                confidence: met ? 1.0 : 0.0,
                description: "\(met ? "Precipitation detected" : "No precipitation") (amount: \(String(format: "%.2f", weatherData.precipitationAmount)))"
            )
            
        case .rain:
            let met = weatherData.precipitationType == .rain && weatherData.precipitationAmount > 0
            return ComponentEvaluationResult(
                met: met,
                confidence: met ? 1.0 : 0.0,
                description: "\(met ? "Rain detected" : "No rain") (type: \(weatherData.precipitationType.rawValue))"
            )
            
        case .snow:
            let met = weatherData.precipitationType == .snow && weatherData.precipitationAmount > 0
            return ComponentEvaluationResult(
                met: met,
                confidence: met ? 1.0 : 0.0,
                description: "\(met ? "Snow detected" : "No snow") (type: \(weatherData.precipitationType.rawValue))"
            )
            
        case .noPrecipitationFor24Hours, .noPrecipitationFor48Hours:
            let hours = precipitationRequirement == .noPrecipitationFor24Hours ? 24 : 48
            let dryPeriodMet = await checkDryPeriod(location: location, hours: hours)
            return ComponentEvaluationResult(
                met: dryPeriodMet.isDry,
                confidence: dryPeriodMet.confidence,
                description: "No precipitation for \(hours) hours: \(dryPeriodMet.isDry ? "met" : "not met") (\(dryPeriodMet.dryHours) dry hours)"
            )
        }
    }
    
    private func evaluateTimeConstraints(_ condition: TriggerCondition) -> ComponentEvaluationResult {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        var startTimeInMinutes: Int?
        var endTimeInMinutes: Int?
        
        if let startTime = condition.timeOfDayStart {
            let startHour = calendar.component(.hour, from: startTime)
            let startMinute = calendar.component(.minute, from: startTime)
            startTimeInMinutes = startHour * 60 + startMinute
        }
        
        if let endTime = condition.timeOfDayEnd {
            let endHour = calendar.component(.hour, from: endTime)
            let endMinute = calendar.component(.minute, from: endTime)
            endTimeInMinutes = endHour * 60 + endMinute
        }
        
        let met: Bool
        let description: String
        
        if let startTime = startTimeInMinutes, let endTime = endTimeInMinutes {
            if startTime <= endTime {
                // Same day range
                met = currentTimeInMinutes >= startTime && currentTimeInMinutes <= endTime
            } else {
                // Overnight range (e.g., 22:00 to 06:00)
                met = currentTimeInMinutes >= startTime || currentTimeInMinutes <= endTime
            }
            description = "Time \(currentHour):\(String(format: "%02d", currentMinute)) \(met ? "within" : "outside") allowed window"
        } else if let startTime = startTimeInMinutes {
            met = currentTimeInMinutes >= startTime
            description = "Time \(currentHour):\(String(format: "%02d", currentMinute)) \(met ? "after" : "before") start time"
        } else if let endTime = endTimeInMinutes {
            met = currentTimeInMinutes <= endTime
            description = "Time \(currentHour):\(String(format: "%02d", currentMinute)) \(met ? "before" : "after") end time"
        } else {
            met = true
            description = "No time constraints"
        }
        
        return ComponentEvaluationResult(
            met: met,
            confidence: met ? 1.0 : 0.0,
            description: description
        )
    }
    
    // MARK: - Helper Methods
    
    private func checkDryPeriod(location: CLLocation, hours: Int) async -> (isDry: Bool, confidence: Double, dryHours: Int) {
        guard let modelContext = self.modelContext else {
            return (isDry: false, confidence: 0.0, dryHours: 0)
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: endDate) ?? endDate
        
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
            let wetHours = weatherData.filter { $0.precipitationAmount > 0 || $0.precipitationType != .none }.count
            let dryHours = weatherData.count - wetHours
            let isDry = wetHours == 0 && weatherData.count > 0
            let confidence = weatherData.count > 0 ? Double(dryHours) / Double(weatherData.count) : 0.0
            
            return (isDry: isDry, confidence: confidence, dryHours: dryHours)
            
        } catch {
            self.logger.error("Failed to check dry period: \(error)")
            return (isDry: false, confidence: 0.0, dryHours: 0)
        }
    }
    
    private func analyzeForecastForCondition(
        condition: TriggerCondition,
        weatherData: WeatherData,
        advanceHours: Int
    ) -> ForecastAnalysis {
        
        let forecast = weatherData.forecastDays
        let daysToAnalyze = min(forecast.count, (advanceHours / 24) + 1)
        
        guard daysToAnalyze > 0 else {
            return ForecastAnalysis(
                willTriggerInAdvancePeriod: false,
                confidence: 0.0,
                description: "No forecast data available",
                daysAnalyzed: 0,
                triggerProbability: 0.0,
                earliestTriggerTime: nil,
                forecastConfidence: 0.0,
                weatherPattern: "unknown"
            )
        }
        
        let relevantForecast = Array(forecast.prefix(daysToAnalyze))
        var triggerDays = 0
        var totalConfidence = 0.0
        var earliestTriggerTime: Date?
        
        for forecastDay in relevantForecast {
            let dayTriggers = evaluateForecastDayAgainstCondition(forecastDay: forecastDay, condition: condition)
            
            if dayTriggers.willTrigger {
                triggerDays += 1
                totalConfidence += dayTriggers.confidence
                
                if earliestTriggerTime == nil {
                    earliestTriggerTime = forecastDay.date
                }
            }
        }
        
        let triggerProbability = Double(triggerDays) / Double(daysToAnalyze)
        let willTrigger = triggerProbability > 0.5 || triggerDays > 0
        let averageConfidence = triggerDays > 0 ? totalConfidence / Double(triggerDays) : 0.0
        
        let description = willTrigger ?
            "Forecast indicates conditions will be met in \(triggerDays) of \(daysToAnalyze) days (probability: \(String(format: "%.0f", triggerProbability * 100))%)" :
            "Forecast indicates conditions unlikely to be met in next \(daysToAnalyze) days"
        
        let weatherPattern = analyzeWeatherPattern(forecast: relevantForecast)
        
        return ForecastAnalysis(
            willTriggerInAdvancePeriod: willTrigger,
            confidence: averageConfidence,
            description: description,
            daysAnalyzed: daysToAnalyze,
            triggerProbability: triggerProbability,
            earliestTriggerTime: earliestTriggerTime,
            forecastConfidence: calculateForecastConfidence(forecast: relevantForecast),
            weatherPattern: weatherPattern
        )
    }
    
    private func evaluateForecastDayAgainstCondition(
        forecastDay: ForecastDay,
        condition: TriggerCondition
    ) -> (willTrigger: Bool, confidence: Double) {
        
        let targetTemp = condition.targetTemperature
        let useFeelsLike = condition.useFeelsLike
        
        // For forecast, we use average temperature
        let dayTemp = forecastDay.averageTemperature
        
        switch condition.comparisonType {
        case .above:
            let willTrigger = dayTemp > targetTemp
            let confidence = willTrigger ? min(1.0, (dayTemp - targetTemp) / 10.0) : 0.0
            return (willTrigger, confidence)
            
        case .below:
            let willTrigger = dayTemp < targetTemp
            let confidence = willTrigger ? min(1.0, (targetTemp - dayTemp) / 10.0) : 0.0
            return (willTrigger, confidence)
            
        case .equals:
            let difference = abs(dayTemp - targetTemp)
            let tolerance = condition.temperatureTolerance
            let willTrigger = difference <= tolerance
            let confidence = willTrigger ? max(0.0, 1.0 - (difference / tolerance)) : 0.0
            return (willTrigger, confidence)
            
        case .between:
            guard let minTemp = condition.minTemperature, let maxTemp = condition.maxTemperature else {
                return (false, 0.0)
            }
            
            let willTrigger = dayTemp >= minTemp && dayTemp <= maxTemp
            return (willTrigger, willTrigger ? 1.0 : 0.0)
        }
    }
    
    private func analyzeWeatherPattern(forecast: [ForecastDay]) -> String {
        guard !forecast.isEmpty else { return "unknown" }
        
        let temperatures = forecast.map { $0.averageTemperature }
        let conditions = forecast.map { $0.weatherCondition }
        
        // Analyze temperature trend
        let tempTrend: String
        if temperatures.count >= 2 {
            let firstHalf = Array(temperatures.prefix(temperatures.count / 2))
            let secondHalf = Array(temperatures.suffix(temperatures.count / 2))
            
            let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
            
            if secondAvg > firstAvg + 5 {
                tempTrend = "warming"
            } else if secondAvg < firstAvg - 5 {
                tempTrend = "cooling"
            } else {
                tempTrend = "stable"
            }
        } else {
            tempTrend = "stable"
        }
        
        // Analyze weather conditions
        let mostCommonCondition = conditions.mostFrequent()?.rawValue ?? "mixed"
        
        return "\(tempTrend)_\(mostCommonCondition)"
    }
    
    private func calculateForecastConfidence(forecast: [ForecastDay]) -> Double {
        // Forecast confidence decreases with time
        var totalConfidence = 0.0
        
        for (index, day) in forecast.enumerated() {
            let dayConfidence = day.confidence == .high ? 0.9 : (day.confidence == .medium ? 0.7 : 0.5)
            let timeDecay = 1.0 - (Double(index) * 0.1) // 10% decay per day
            totalConfidence += dayConfidence * max(0.1, timeDecay)
        }
        
        return forecast.count > 0 ? totalConfidence / Double(forecast.count) : 0.0
    }
    
    private func calculateForecastEvaluationTime(
        triggered: Bool,
        forecastAnalysis: ForecastAnalysis
    ) -> Date? {
        
        let calendar = Calendar.current
        let baseInterval: TimeInterval
        
        if triggered {
            // If forecast indicates triggering, check more frequently as we approach
            if let earliestTrigger = forecastAnalysis.earliestTriggerTime {
                let timeUntilTrigger = earliestTrigger.timeIntervalSince(Date())
                if timeUntilTrigger < 12 * 3600 { // Less than 12 hours
                    baseInterval = 2 * 3600 // Check every 2 hours
                } else if timeUntilTrigger < 48 * 3600 { // Less than 48 hours
                    baseInterval = 6 * 3600 // Check every 6 hours
                } else {
                    baseInterval = 12 * 3600 // Check every 12 hours
                }
            } else {
                baseInterval = 6 * 3600
            }
        } else {
            // No triggering forecast, check less frequently
            baseInterval = 24 * 3600 // Check daily
        }
        
        return calendar.date(byAdding: .second, value: Int(baseInterval), to: Date())
    }
}

// MARK: - Support Structures

struct ComponentEvaluationResult: Sendable {
    let met: Bool
    let confidence: Double
    let description: String
}

struct ForecastAnalysis: Sendable {
    let willTriggerInAdvancePeriod: Bool
    let confidence: Double
    let description: String
    let daysAnalyzed: Int
    let triggerProbability: Double
    let earliestTriggerTime: Date?
    let forecastConfidence: Double
    let weatherPattern: String
}

// MARK: - Array Extensions

private extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = Dictionary(grouping: self) { $0 }.mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }
}
