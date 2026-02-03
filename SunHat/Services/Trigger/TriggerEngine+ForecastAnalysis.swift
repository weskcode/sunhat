//
//  TriggerEngine+ForecastAnalysis.swift
//  SunHat
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
        _ conditionData: TriggerConditionData,
        reminderId: UUID,
        location: CLLocation,
        weatherData: WeatherDataTransfer
    ) async -> TriggerEvaluationResult {
        
        var conditionsMet: [String] = []
        var conditionsFailed: [String] = []
        var totalConfidence = 0.0
        var conditionCount = 0
        
        // 1. Temperature condition (always present in composite)
        let tempResult = await evaluateTemperatureComponent(conditionData, weatherData: weatherData)
        if tempResult.met {
            conditionsMet.append(tempResult.description)
        } else {
            conditionsFailed.append(tempResult.description)
        }
        totalConfidence += tempResult.confidence
        conditionCount += 1
        
        // 2. Humidity condition (if required)
        // Note: Humidity conditions not yet implemented in TriggerConditionData
        // This would need to be added to the Sendable data structure
        
        // 3. Wind speed condition (if required)
        // Note: Wind speed conditions not yet implemented in TriggerConditionData
        // This would need to be added to the Sendable data structure
        
        // 4. Precipitation condition (if required)
        // Note: Precipitation conditions not yet implemented in TriggerConditionData
        // This would need to be added to the Sendable data structure
        
        // 5. Time constraints (if specified)
        // Note: Time constraints not yet implemented in TriggerConditionData
        // This would need to be added to the Sendable data structure
        
        // Calculate overall result
        let allConditionsMet = conditionsFailed.isEmpty
        // Note: conditionCount is always >= 1 since temperature condition is always evaluated
        let averageConfidence = totalConfidence / Double(conditionCount)
        
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
            "temperature_included": "true"
        ]
        
        return TriggerEvaluationResult(
            reminderId: reminderId,
            conditionData: conditionData,
            triggered: allConditionsMet,
            confidence: averageConfidence,
            weatherData: weatherData,
            triggerReason: triggerReason,
            metadata: metadata
        )
    }
    
    // MARK: - Forecast-Based Predictions
    
    func evaluateForecastPrediction(
        _ conditionData: TriggerConditionData,
        reminderId: UUID,
        location: CLLocation,
        advanceHours: Int = 24
    ) async -> TriggerEvaluationResult {
        
        do {
            // Use Apple WeatherKit API directly to avoid non-Sendable WeatherData
            let appleWeatherKitAPI = AppleWeatherKitAPI()
            let weatherDataDTO = try await appleWeatherKitAPI.fetchWeatherData(for: location)
            
            // Convert DTO to WeatherDataTransfer inline
            let weatherTransfer = WeatherDataTransfer(
                timestamp: Date(),
                temperature: weatherDataDTO.temperature,
                apparentTemperature: weatherDataDTO.feelsLike,
                humidity: weatherDataDTO.humidity,
                windSpeed: weatherDataDTO.windSpeed,
                pressure: weatherDataDTO.pressure,
                visibility: weatherDataDTO.visibility,
                uvIndex: weatherDataDTO.uvIndex,
                dewPoint: weatherDataDTO.dewPoint,
                windDirectionDegrees: Double(weatherDataDTO.windDirection),
                windGust: nil,
                precipitationAmount: weatherDataDTO.precipitationAmount,
                precipitationProbability: 0,
                cloudCoverage: weatherDataDTO.cloudCover,
                airQualityIndex: nil,
                pm25: nil,
                sunrise: nil,
                sunset: nil,
                weatherCondition: weatherDataDTO.weatherCondition,
                weatherDescription: weatherDataDTO.weatherCondition.rawValue,
                locationLatitude: 0,
                locationLongitude: 0
            )
            
            let forecastAnalysis = await analyzeForecastForCondition(
                conditionData: conditionData,
                weatherData: weatherTransfer,
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
                conditionData: conditionData,
                triggered: triggered,
                confidence: confidence,
                weatherData: weatherTransfer,
                triggerReason: triggerReason,
                nextEvaluationTime: nextEvaluationTime,
                metadata: metadata
            )
            
        } catch {
            self.logger.error("Failed to fetch weather data for forecast prediction: \(error)")
            return TriggerEvaluationResult(
                reminderId: reminderId,
                conditionData: conditionData,
                triggered: false,
                confidence: 0.0,
                triggerReason: "Unable to fetch forecast data: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Component Evaluators
    
    private func evaluateTemperatureComponent(
        _ conditionData: TriggerConditionData,
        weatherData: WeatherDataTransfer
    ) async -> ComponentEvaluationResult {
        
        let currentTemp = conditionData.useFeelsLike ? weatherData.apparentTemperature : weatherData.temperature
        let targetTemp = conditionData.targetTemperature
        
        switch conditionData.comparisonType {
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
            let tolerance = conditionData.temperatureTolerance
            let met = difference <= tolerance
            let confidence = met ? max(0.0, 1.0 - (difference / tolerance)) : 0.0
            return ComponentEvaluationResult(
                met: met,
                confidence: confidence,
                description: "Temperature \(String(format: "%.1f", currentTemp))° \(met ? "matches" : "differs from") target \(String(format: "%.1f", targetTemp))° (±\(String(format: "%.1f", tolerance))°)"
            )
            
        case .between:
            guard let minTemp = conditionData.minTemperature, let maxTemp = conditionData.maxTemperature else {
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
    
    // Note: Humidity evaluation temporarily disabled due to missing fields in TriggerConditionData
    // This would need targetHumidity and humidityTolerance fields added to the Sendable data structure
    
    // Note: Wind speed evaluation temporarily disabled due to missing fields in TriggerConditionData
    // This would need maxWindSpeed field added to the Sendable data structure
    
    // Note: Precipitation evaluation temporarily disabled due to missing fields in TriggerConditionData
    // This would need precipitationRequirement field added to the Sendable data structure
    
    // Note: Time constraints evaluation temporarily disabled due to missing fields in TriggerConditionData
    // This would need timeOfDayStart and timeOfDayEnd fields added to the Sendable data structure
    
    // MARK: - Helper Methods
    
    private func checkDryPeriod(location: CLLocation, hours: Int) async -> (isDry: Bool, confidence: Double, dryHours: Int) {
        do {
            let historicalData = try await modelActor.fetchHistoricalWeatherData(for: location, daysBack: max(1, hours / 24))
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: endDate) ?? endDate
            
            let relevantData = historicalData.filter { data in
                data.timestamp >= startDate && data.timestamp <= endDate
            }
            
            let wetHours = relevantData.filter { $0.precipitationAmount > 0 }.count
            let dryHours = relevantData.count - wetHours
            let isDry = wetHours == 0 && relevantData.count > 0
            let confidence = relevantData.count > 0 ? Double(dryHours) / Double(relevantData.count) : 0.0
            
            return (isDry: isDry, confidence: confidence, dryHours: dryHours)
            
        } catch {
            self.logger.error("Failed to check dry period: \(error)")
            return (isDry: false, confidence: 0.0, dryHours: 0)
        }
    }
    
    private func analyzeForecastForCondition(
        conditionData: TriggerConditionData,
        weatherData: WeatherDataTransfer,
        advanceHours: Int
    ) async -> ForecastAnalysis {
        
        // Note: Forecast analysis temporarily simplified due to missing forecast data in WeatherDataTransfer
        // This would need forecastDays field added to the Sendable data structure
        
        return ForecastAnalysis(
            willTriggerInAdvancePeriod: false,
            confidence: 0.0,
            description: "Forecast analysis not yet implemented for Sendable data structures",
            daysAnalyzed: 0,
            triggerProbability: 0.0,
            earliestTriggerTime: nil,
            forecastConfidence: 0.0,
            weatherPattern: "unknown"
        )
    }
    
    // Note: Forecast day evaluation temporarily disabled due to missing ForecastDay in Sendable data structures
    
    // Note: Weather pattern analysis temporarily disabled due to missing ForecastDay in Sendable data structures
    
    // Note: Forecast confidence calculation temporarily disabled due to missing ForecastDay in Sendable data structures
    
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
    
    // MARK: - Additional Evaluation Methods
    // Note: evaluateSeasonalMarker and evaluateHistoricalComparison are implemented in TriggerEngine+SeasonalAnalysis.swift
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
