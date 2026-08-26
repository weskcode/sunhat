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
        
        if conditionData.requiresHumidity {
            let humidityResult = evaluateHumidityComponent(conditionData, humidity: weatherData.humidity)
            if humidityResult.met {
                conditionsMet.append(humidityResult.description)
            } else {
                conditionsFailed.append(humidityResult.description)
            }
            totalConfidence += humidityResult.confidence
            conditionCount += 1
        }

        if conditionData.requiresWindSpeed {
            let windResult = evaluateWindComponent(conditionData, windSpeed: weatherData.windSpeed)
            if windResult.met {
                conditionsMet.append(windResult.description)
            } else {
                conditionsFailed.append(windResult.description)
            }
            totalConfidence += windResult.confidence
            conditionCount += 1
        }

        if conditionData.requiresPrecipitation {
            let precipitationResult = evaluatePrecipitationComponent(
                conditionData.precipitationRequirement,
                amount: weatherData.precipitationAmount,
                probability: weatherData.precipitationProbability,
                type: weatherData.weatherCondition,
                forecastDays: weatherData.forecastDays
            )
            if precipitationResult.met {
                conditionsMet.append(precipitationResult.description)
            } else {
                conditionsFailed.append(precipitationResult.description)
            }
            totalConfidence += precipitationResult.confidence
            conditionCount += 1
        }

        if conditionData.timeOfDayStart != nil || conditionData.timeOfDayEnd != nil {
            let timeResult = evaluateTimeWindowComponent(conditionData, date: weatherData.timestamp)
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
            let weatherDataDTO = try await weatherAPI.fetchWeatherData(for: location)
            
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
                // Current precipitation probability: prefer the provider's current
                // forecast hour, then today's daily forecast — never hard-code 0,
                // which broke rain/dry prediction decisions.
                precipitationProbability: weatherDataDTO.hourly.first?.precipitationChance
                    ?? weatherDataDTO.forecast.first?.precipitationProbability
                    ?? 0,
                cloudCoverage: weatherDataDTO.cloudCover,
                airQualityIndex: nil,
                pm25: nil,
                sunrise: nil,
                sunset: nil,
                weatherCondition: weatherDataDTO.weatherCondition,
                weatherDescription: weatherDataDTO.weatherCondition.rawValue,
                locationLatitude: location.coordinate.latitude,
                locationLongitude: location.coordinate.longitude,
                forecastDays: weatherDataDTO.forecast.map { forecast in
                    ForecastDayTransfer(
                        date: forecast.date,
                        highTemperature: forecast.highTemperature,
                        lowTemperature: forecast.lowTemperature,
                        averageTemperature: (forecast.highTemperature + forecast.lowTemperature) / 2,
                        weatherCondition: forecast.weatherCondition,
                        precipitationProbability: forecast.precipitationProbability,
                        precipitationAmount: forecast.precipitationAmount,
                        precipitationType: forecast.precipitationType,
                        windSpeed: forecast.windSpeed,
                        humidity: forecast.humidity,
                        cloudCover: forecast.cloudCover
                    )
                }
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
            // Guard tolerance == 0: an exact match at zero tolerance is full
            // confidence; dividing by zero would otherwise produce NaN.
            let confidence: Double
            if met {
                confidence = difference == 0 ? 1.0 : max(0.0, 1.0 - (difference / max(tolerance, 0.001)))
            } else {
                confidence = 0.0
            }
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
    
    private func evaluateHumidityComponent(_ conditionData: TriggerConditionData, humidity: Int) -> ComponentEvaluationResult {
        guard let target = conditionData.targetHumidity else {
            return ComponentEvaluationResult(met: false, confidence: 0, description: "humidity target is missing")
        }

        let difference = abs(Double(humidity) - target)
        let met = difference <= conditionData.humidityTolerance
        return ComponentEvaluationResult(
            met: met,
            confidence: met ? max(0, 1 - (difference / max(conditionData.humidityTolerance, 1))) : 0,
            description: "humidity \(humidity)% \(met ? "within" : "outside") \(Int(target))% ±\(Int(conditionData.humidityTolerance))%"
        )
    }

    private func evaluateWindComponent(_ conditionData: TriggerConditionData, windSpeed: Double) -> ComponentEvaluationResult {
        guard let maxWindSpeed = conditionData.maxWindSpeed else {
            return ComponentEvaluationResult(met: false, confidence: 0, description: "wind limit is missing")
        }

        let met = windSpeed <= maxWindSpeed
        return ComponentEvaluationResult(
            met: met,
            confidence: met ? 1 : max(0, 1 - ((windSpeed - maxWindSpeed) / max(maxWindSpeed, 1))),
            description: "wind \(Int(windSpeed)) mph \(met ? "at or below" : "above") \(Int(maxWindSpeed)) mph"
        )
    }

    private func evaluatePrecipitationComponent(
        _ requirement: PrecipitationRequirement,
        amount: Double,
        probability: Int,
        type: WeatherCondition,
        forecastDays: [ForecastDayTransfer] = [],
        referenceDate: Date = Date()
    ) -> ComponentEvaluationResult {
        let wetConditions: Set<WeatherCondition> = [.rain, .drizzle, .snow, .sleet, .hail, .thunderstorm]
        let isWet = amount > 0 || probability >= 40 || wetConditions.contains(type)

        switch requirement {
        case .none:
            return ComponentEvaluationResult(met: true, confidence: 1, description: "no precipitation requirement")
        case .dry:
            return ComponentEvaluationResult(met: !isWet, confidence: isWet ? 0 : 1, description: isWet ? "precipitation expected" : "dry conditions expected")
        case .anyPrecipitation:
            return ComponentEvaluationResult(met: isWet, confidence: isWet ? max(0.5, Double(probability) / 100) : 0, description: isWet ? "precipitation expected" : "no precipitation expected")
        case .rain:
            let met = [.rain, .drizzle, .thunderstorm].contains(type)
            return ComponentEvaluationResult(met: met, confidence: met ? max(0.5, Double(probability) / 100) : 0, description: met ? "rain expected" : "rain not expected")
        case .snow:
            let met = [.snow, .sleet, .hail].contains(type)
            return ComponentEvaluationResult(met: met, confidence: met ? max(0.5, Double(probability) / 100) : 0, description: met ? "snow expected" : "snow not expected")
        case .noPrecipitationFor24Hours, .noPrecipitationFor48Hours:
            return evaluateDryPeriod(
                hoursRequired: requirement == .noPrecipitationFor24Hours ? 24 : 48,
                currentIsWet: isWet,
                forecastDays: forecastDays,
                wetConditions: wetConditions,
                startingAt: referenceDate
            )
        }
    }

    /// Evaluates a 24/48-hour dry requirement across every forecast day covering the
    /// requested period — a single current-conditions sample is not enough, because
    /// rain later in the window must fail the requirement. Requires forecast coverage
    /// of the whole window; without it the requirement is not met.
    // Internal (not private) so regression tests can drive it with a fixed `startingAt`
    // instead of the real wall clock — see TriggerEngineForecastAnalysisTests.
    func evaluateDryPeriod(
        hoursRequired: Int,
        currentIsWet: Bool,
        forecastDays: [ForecastDayTransfer],
        wetConditions: Set<WeatherCondition>,
        startingAt: Date = Date()
    ) -> ComponentEvaluationResult {
        if currentIsWet {
            return ComponentEvaluationResult(met: false, confidence: 0, description: "precipitation now — \(hoursRequired)h dry requirement not met")
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: startingAt)
        let daysNeeded = Int((Double(hoursRequired) / 24.0).rounded(.up)) + 1 // include today

        // Bucket by calendar day rather than comparing raw timestamps against a
        // windowEnd cutoff: providers don't guarantee `date` is midnight (WeatherAPI's
        // own hourly-aggregate lookup already normalizes via startOfDay for the same
        // reason), so a day stamped at e.g. 07:00 could fall just outside a raw
        // now+Nh cutoff and be miscounted as missing coverage.
        let dayBuckets = Dictionary(grouping: forecastDays) { calendar.startOfDay(for: $0.date) }
        let coveringDays = (0..<daysNeeded).compactMap { offset -> ForecastDayTransfer? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart) else { return nil }
            return dayBuckets[dayStart]?.first
        }

        guard coveringDays.count >= daysNeeded else {
            return ComponentEvaluationResult(
                met: false,
                confidence: 0,
                description: "forecast doesn't cover the full \(hoursRequired)h dry window"
            )
        }

        for day in coveringDays {
            let dayIsWet = day.precipitationAmount > 0
                || day.precipitationProbability >= 40
                || wetConditions.contains(day.weatherCondition)
            if dayIsWet {
                return ComponentEvaluationResult(
                    met: false,
                    confidence: 0,
                    description: "precipitation expected within the \(hoursRequired)h window"
                )
            }
        }

        let lowestDryConfidence = coveringDays
            .map { 1.0 - Double($0.precipitationProbability) / 100.0 }
            .min() ?? 0.8
        return ComponentEvaluationResult(
            met: true,
            confidence: max(0.5, lowestDryConfidence),
            description: "no precipitation expected for the next \(hoursRequired)h"
        )
    }

    private func evaluateTimeWindowComponent(_ conditionData: TriggerConditionData, date: Date) -> ComponentEvaluationResult {
        guard let start = conditionData.timeOfDayStart ?? conditionData.timeOfDayEnd,
              let end = conditionData.timeOfDayEnd ?? conditionData.timeOfDayStart else {
            return ComponentEvaluationResult(met: true, confidence: 1, description: "no time window")
        }

        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: date)
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let met = startMinutes <= endMinutes
            ? currentMinutes >= startMinutes && currentMinutes <= endMinutes
            : currentMinutes >= startMinutes || currentMinutes <= endMinutes

        return ComponentEvaluationResult(
            met: met,
            confidence: met ? 1 : 0,
            description: met ? "inside notification time window" : "outside notification time window"
        )
    }
    
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
        let cutoff = Date().addingTimeInterval(TimeInterval(advanceHours * 3600))
        let forecastDays = weatherData.forecastDays
            .filter { $0.date <= cutoff }
            .sorted { $0.date < $1.date }

        guard !forecastDays.isEmpty else {
            let currentResult = await evaluateComposite(
                conditionData,
                reminderId: conditionData.id,
                location: CLLocation(latitude: weatherData.locationLatitude, longitude: weatherData.locationLongitude),
                weatherData: weatherData
            )

            return ForecastAnalysis(
                willTriggerInAdvancePeriod: currentResult.triggered,
                confidence: currentResult.confidence,
                description: currentResult.triggerReason,
                daysAnalyzed: 0,
                triggerProbability: currentResult.triggered ? currentResult.confidence : 0.0,
                earliestTriggerTime: currentResult.triggered ? Date() : nil,
                forecastConfidence: currentResult.confidence,
                weatherPattern: weatherData.weatherCondition.rawValue
            )
        }

        let evaluations = forecastDays.map { day in
            (day, evaluateForecastDay(day, conditionData: conditionData, allForecastDays: weatherData.forecastDays))
        }
        let matches = evaluations.filter { $0.1.met }
        let averageConfidence = evaluations.map(\.1.confidence).average()
        let earliestMatch = matches.first

        return ForecastAnalysis(
            willTriggerInAdvancePeriod: earliestMatch != nil,
            confidence: earliestMatch?.1.confidence ?? averageConfidence,
            description: earliestMatch?.1.description ?? "No forecast day matches this reminder condition",
            daysAnalyzed: forecastDays.count,
            triggerProbability: earliestMatch == nil ? averageConfidence : max(averageConfidence, earliestMatch?.1.confidence ?? 0),
            earliestTriggerTime: earliestMatch?.0.date,
            forecastConfidence: averageConfidence,
            weatherPattern: forecastDays.map(\.weatherCondition).mostFrequent()?.rawValue ?? "unknown"
        )
    }

    private func evaluateForecastDay(
        _ day: ForecastDayTransfer,
        conditionData: TriggerConditionData,
        allForecastDays: [ForecastDayTransfer] = []
    ) -> ComponentEvaluationResult {
        let checks = [
            evaluateTemperatureForecastComponent(conditionData, day: day),
            conditionData.requiresHumidity ? evaluateHumidityComponent(conditionData, humidity: day.humidity) : nil,
            conditionData.requiresWindSpeed ? evaluateWindComponent(conditionData, windSpeed: day.windSpeed) : nil,
            conditionData.requiresPrecipitation ? evaluatePrecipitationComponent(
                conditionData.precipitationRequirement,
                amount: day.precipitationAmount,
                probability: day.precipitationProbability,
                type: day.weatherCondition,
                forecastDays: allForecastDays,
                referenceDate: day.date
            ) : nil,
            (conditionData.timeOfDayStart != nil || conditionData.timeOfDayEnd != nil) ? evaluateTimeWindowComponent(conditionData, date: day.date) : nil,
            conditionData.hasSkyConditionFilter ? evaluateSkyConditionComponent(conditionData, weatherCondition: day.weatherCondition) : nil
        ].compactMap { $0 }

        let failed = checks.filter { !$0.met }
        let confidence = checks.isEmpty ? 0 : checks.map(\.confidence).average()
        let dateLabel = day.date.formatted(.dateTime.month(.abbreviated).day())

        if failed.isEmpty {
            return ComponentEvaluationResult(
                met: true,
                confidence: confidence,
                description: "Forecast matches on \(dateLabel): " + checks.map(\.description).joined(separator: ", ")
            )
        }

        return ComponentEvaluationResult(
            met: false,
            confidence: confidence,
            description: "Forecast does not match on \(dateLabel): " + failed.map(\.description).joined(separator: ", ")
        )
    }

    private func evaluateTemperatureForecastComponent(
        _ conditionData: TriggerConditionData,
        day: ForecastDayTransfer
    ) -> ComponentEvaluationResult {
        let target = conditionData.targetTemperature

        switch conditionData.comparisonType {
        case .above:
            let met = day.highTemperature > target
            let confidence = met ? min(1, (day.highTemperature - target) / 10) : max(0, 1 - ((target - day.highTemperature) / 10))
            return ComponentEvaluationResult(met: met, confidence: confidence, description: "high \(Int(day.highTemperature))° above \(Int(target))°")
        case .below:
            let met = day.lowTemperature < target
            let confidence = met ? min(1, (target - day.lowTemperature) / 10) : max(0, 1 - ((day.lowTemperature - target) / 10))
            return ComponentEvaluationResult(met: met, confidence: confidence, description: "low \(Int(day.lowTemperature))° below \(Int(target))°")
        case .equals:
            let difference = abs(day.averageTemperature - target)
            let tolerance = max(conditionData.temperatureTolerance, 0.1)
            let met = difference <= tolerance
            return ComponentEvaluationResult(met: met, confidence: met ? max(0, 1 - (difference / tolerance)) : 0, description: "average \(Int(day.averageTemperature))° near \(Int(target))°")
        case .between:
            guard let minTemp = conditionData.minTemperature, let maxTemp = conditionData.maxTemperature else {
                return ComponentEvaluationResult(met: false, confidence: 0, description: "invalid forecast temperature range")
            }
            let met = day.highTemperature >= minTemp && day.lowTemperature <= maxTemp
            return ComponentEvaluationResult(met: met, confidence: met ? 1 : 0, description: "forecast overlaps \(Int(minTemp))°-\(Int(maxTemp))°")
        }
    }

    private func evaluateSkyConditionComponent(
        _ conditionData: TriggerConditionData,
        weatherCondition: WeatherCondition
    ) -> ComponentEvaluationResult {
        let selectedConditions = Set(
            conditionData.selectedSkyConditionsRaw
                .components(separatedBy: ",")
                .compactMap { SkyCondition(rawValue: $0) }
        )
        guard !selectedConditions.isEmpty else {
            return ComponentEvaluationResult(met: true, confidence: 1, description: "no sky condition filter")
        }

        let currentSky: SkyCondition
        switch weatherCondition {
        case .clear: currentSky = .sunny
        case .partlyCloudy: currentSky = .partlyCloudy
        case .cloudy, .overcast, .fog: currentSky = .cloudy
        case .rain, .drizzle, .thunderstorm: currentSky = .rainy
        case .snow, .sleet, .hail: currentSky = .snowy
        case .windy, .unknown: currentSky = .sunny
        }

        let mode = ConditionSelectionMode(rawValue: conditionData.conditionModeRaw) ?? .include
        let met = mode == .include ? selectedConditions.contains(currentSky) : !selectedConditions.contains(currentSky)
        return ComponentEvaluationResult(
            met: met,
            confidence: met ? 1 : 0,
            description: "sky condition \(currentSky.rawValue) \(met ? "matches" : "does not match")"
        )
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
    nonisolated func mostFrequent() -> Element? {
        let counts = Dictionary(grouping: self) { $0 }.mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }
}

private extension Array where Element == Double {
    nonisolated func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
