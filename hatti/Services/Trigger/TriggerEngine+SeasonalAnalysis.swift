//
//  TriggerEngine+SeasonalAnalysis.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Seasonal Analysis Extension

extension TriggerEngine {
    
    func evaluateSeasonalMarker(
        _ condition: TriggerCondition,
        reminderId: UUID,
        location: CLLocation,
        currentWeather: WeatherData
    ) async -> TriggerEvaluationResult {
        
        guard let seasonalType = condition.seasonalType else {
            return TriggerEvaluationResult(
                reminderId: reminderId,
                condition: condition,
                triggered: false,
                confidence: 0.0,
                weatherData: currentWeather,
                triggerReason: "No seasonal type specified"
            )
        }
        
        let historicalContext = await getHistoricalWeatherContext(for: location)
        let seasonalAnalysis = analyzeSeasonalTransition(
            currentWeather: currentWeather,
            historicalContext: historicalContext,
            seasonalType: seasonalType
        )
        
        let triggered = seasonalAnalysis.isTransitionDetected
        let confidence = seasonalAnalysis.confidence
        let triggerReason = seasonalAnalysis.description
        
        let metadata = [
            "seasonal_type": seasonalType.rawValue,
            "transition_detected": String(triggered),
            "days_since_transition": String(seasonalAnalysis.daysSinceTransition),
            "expected_date": seasonalAnalysis.expectedDate?.ISO8601Format() ?? "unknown",
            "historical_average": seasonalAnalysis.historicalAverage?.ISO8601Format() ?? "unknown",
            "temperature_trend": String(describing: seasonalAnalysis.temperatureTrend)
        ]
        
        // Calculate next evaluation based on seasonal progression
        let nextEvaluationTime = calculateSeasonalEvaluationTime(
            seasonalType: seasonalType,
            currentAnalysis: seasonalAnalysis
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
    
    func evaluateHistoricalComparison(
        _ condition: TriggerCondition,
        reminderId: UUID,
        location: CLLocation,
        currentWeather: WeatherData
    ) async -> TriggerEvaluationResult {
        
        let comparisonDays = condition.historicalComparisonDays
        let targetTemperature = condition.targetTemperature
        let comparisonType = condition.comparisonType
        let useFeelsLike = condition.useFeelsLike
        
        let historicalComparison = await performHistoricalComparison(
            location: location,
            currentWeather: currentWeather,
            comparisonDays: comparisonDays,
            useFeelsLike: useFeelsLike
        )
        
        let currentTemp = useFeelsLike ? currentWeather.apparentTemperature : currentWeather.temperature
        let triggered: Bool
        let confidence: Double
        let triggerReason: String
        
        switch comparisonType {
        case .above:
            triggered = historicalComparison.isWarmerThanHistorical
            confidence = historicalComparison.temperatureDifferenceConfidence
            triggerReason = triggered ?
                "Current temperature \(currentTemp, specifier: "%.1f")° is \(historicalComparison.temperatureDifference, specifier: "%.1f")° warmer than historical average \(historicalComparison.historicalAverage, specifier: "%.1f")° for this date" :
                "Current temperature \(currentTemp, specifier: "%.1f")° is \(abs(historicalComparison.temperatureDifference), specifier: "%.1f")° cooler than historical average \(historicalComparison.historicalAverage, specifier: "%.1f")° for this date"
            
        case .below:
            triggered = !historicalComparison.isWarmerThanHistorical
            confidence = historicalComparison.temperatureDifferenceConfidence
            triggerReason = triggered ?
                "Current temperature \(currentTemp, specifier: "%.1f")° is \(abs(historicalComparison.temperatureDifference), specifier: "%.1f")° cooler than historical average \(historicalComparison.historicalAverage, specifier: "%.1f")° for this date" :
                "Current temperature \(currentTemp, specifier: "%.1f")° is \(historicalComparison.temperatureDifference, specifier: "%.1f")° warmer than historical average \(historicalComparison.historicalAverage, specifier: "%.1f")° for this date"
            
        case .equals:
            let difference = abs(historicalComparison.temperatureDifference)
            let tolerance = condition.temperatureTolerance
            triggered = difference <= tolerance
            confidence = max(0.0, 1.0 - (difference / (tolerance * 2)))
            triggerReason = triggered ?
                "Current temperature \(currentTemp, specifier: "%.1f")° matches historical average \(historicalComparison.historicalAverage, specifier: "%.1f")° within \(tolerance, specifier: "%.1f")°" :
                "Current temperature \(currentTemp, specifier: "%.1f")° differs from historical average by \(difference, specifier: "%.1f")° (tolerance: \(tolerance, specifier: "%.1f")°)"
            
        case .between:
            // For historical comparison, "between" means within a certain percentile range
            let percentileRange = historicalComparison.percentileRange
            triggered = percentileRange.0 <= 0.25 && percentileRange.1 >= 0.75 // Middle 50%
            confidence = triggered ? 1.0 : 0.0
            triggerReason = triggered ?
                "Current temperature is within typical range for this date (percentile: \(percentileRange.0 * 100, specifier: "%.0f")-\(percentileRange.1 * 100, specifier: "%.0f")%)" :
                "Current temperature is outside typical range for this date (percentile: \(percentileRange.0 * 100, specifier: "%.0f")-\(percentileRange.1 * 100, specifier: "%.0f")%)"
        }
        
        let metadata = [
            "comparison_days": String(comparisonDays),
            "historical_average": String(historicalComparison.historicalAverage),
            "temperature_difference": String(historicalComparison.temperatureDifference),
            "percentile_rank": String(historicalComparison.percentileRank),
            "data_points": String(historicalComparison.dataPoints),
            "warmest_on_record": String(historicalComparison.isWarmestOnRecord),
            "coldest_on_record": String(historicalComparison.isColdestOnRecord),
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
    
    // MARK: - Seasonal Analysis Helper Methods
    
    private func getHistoricalWeatherContext(for location: CLLocation) async -> HistoricalWeatherContext {
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)_historical"
        
        // Check cache first
        if let cachedContext = historicalDataCache[cacheKey] {
            return cachedContext
        }
        
        guard let modelContext = modelContext else {
            return createEmptyHistoricalContext(location: location)
        }
        
        // Fetch historical data for the past few years
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -3, to: endDate) ?? endDate
        
        let searchRadius: CLLocationDistance = 25000 // 25km for historical context
        let minLat = location.coordinate.latitude - (searchRadius / 111000)
        let maxLat = location.coordinate.latitude + (searchRadius / 111000)
        let minLon = location.coordinate.longitude - (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        let maxLon = location.coordinate.longitude + (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        
        let predicate = #Predicate<WeatherData> { weather in
            weather.timestamp >= startDate &&
            weather.timestamp <= endDate &&
            weather.location?.latitude >= minLat &&
            weather.location?.latitude <= maxLat &&
            weather.location?.longitude >= minLon &&
            weather.location?.longitude <= maxLon
        }
        
        let descriptor = FetchDescriptor<WeatherData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\WeatherData.timestamp, order: .forward)]
        )
        
        do {
            let historicalData = try modelContext.fetch(descriptor)
            let context = buildHistoricalContext(
                location: location,
                historicalData: historicalData
            )
            
            // Cache the result
            historicalDataCache[cacheKey] = context
            
            return context
            
        } catch {
            logger.error("Failed to fetch historical weather data: \(error)")
            return createEmptyHistoricalContext(location: location)
        }
    }
    
    private func buildHistoricalContext(
        location: CLLocation,
        historicalData: [WeatherData]
    ) -> HistoricalWeatherContext {
        
        let calendar = Calendar.current
        var yearlyAverages: [String: Double] = [:]
        var yearlyData: [Int: [WeatherData]] = [:]
        
        // Group data by year and calculate averages
        for data in historicalData {
            let year = calendar.component(.year, from: data.timestamp)
            yearlyData[year, default: []].append(data)
            
            // Create month-day key
            let monthDay = calendar.dateComponents([.month, .day], from: data.timestamp)
            let key = "\(monthDay.month!)-\(monthDay.day!)"
            
            if yearlyAverages[key] == nil {
                yearlyAverages[key] = data.temperature
            } else {
                yearlyAverages[key] = (yearlyAverages[key]! + data.temperature) / 2
            }
        }
        
        // Analyze seasonal patterns
        let seasonalPatterns = analyzeSeasonalPatterns(yearlyData: yearlyData)
        
        return HistoricalWeatherContext(
            location: location,
            currentDate: Date(),
            historicalData: historicalData,
            yearlyAverages: yearlyAverages,
            seasonalPatterns: seasonalPatterns
        )
    }
    
    private func analyzeSeasonalPatterns(yearlyData: [Int: [WeatherData]]) -> HistoricalWeatherContext.SeasonalPatterns {
        let calendar = Calendar.current
        
        var firstFrostDates: [Date] = []
        var lastFrostDates: [Date] = []
        var springTransitions: [Date] = []
        var fallTransitions: [Date] = []
        
        for (year, data) in yearlyData {
            let sortedData = data.sorted { $0.timestamp < $1.timestamp }
            
            // Find first frost (first day below 32°F in fall/winter)
            if let firstFrost = findFirstFrost(in: sortedData, year: year) {
                firstFrostDates.append(firstFrost)
            }
            
            // Find last frost (last day below 32°F in winter/spring)
            if let lastFrost = findLastFrost(in: sortedData, year: year) {
                lastFrostDates.append(lastFrost)
            }
            
            // Find seasonal transitions based on temperature patterns
            if let springTransition = findSpringTransition(in: sortedData, year: year) {
                springTransitions.append(springTransition)
            }
            
            if let fallTransition = findFallTransition(in: sortedData, year: year) {
                fallTransitions.append(fallTransition)
            }
        }
        
        return HistoricalWeatherContext.SeasonalPatterns(
            averageFirstFrost: calculateAverageDate(firstFrostDates),
            averageLastFrost: calculateAverageDate(lastFrostDates),
            averageSpringTransition: calculateAverageDate(springTransitions),
            averageFallTransition: calculateAverageDate(fallTransitions),
            growingSeasonStart: calculateAverageDate(lastFrostDates),
            growingSeasonEnd: calculateAverageDate(firstFrostDates)
        )
    }
    
    private func findFirstFrost(in data: [WeatherData], year: Int) -> Date? {
        let calendar = Calendar.current
        let fallStart = calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? Date()
        
        for weatherData in data {
            if weatherData.timestamp >= fallStart && weatherData.temperature <= 32.0 {
                return weatherData.timestamp
            }
        }
        return nil
    }
    
    private func findLastFrost(in data: [WeatherData], year: Int) -> Date? {
        let calendar = Calendar.current
        let springEnd = calendar.date(from: DateComponents(year: year, month: 6, day: 1)) ?? Date()
        
        for weatherData in data.reversed() {
            if weatherData.timestamp <= springEnd && weatherData.temperature <= 32.0 {
                return weatherData.timestamp
            }
        }
        return nil
    }
    
    private func findSpringTransition(in data: [WeatherData], year: Int) -> Date? {
        // Spring transition: 7 consecutive days above 50°F after March 1
        let calendar = Calendar.current
        let springStart = calendar.date(from: DateComponents(year: year, month: 3, day: 1)) ?? Date()
        
        var consecutiveDays = 0
        for weatherData in data {
            if weatherData.timestamp >= springStart {
                if weatherData.temperature > 50.0 {
                    consecutiveDays += 1
                    if consecutiveDays >= 7 {
                        return calendar.date(byAdding: .day, value: -6, to: weatherData.timestamp)
                    }
                } else {
                    consecutiveDays = 0
                }
            }
        }
        return nil
    }
    
    private func findFallTransition(in data: [WeatherData], year: Int) -> Date? {
        // Fall transition: 7 consecutive days below 60°F after August 1
        let calendar = Calendar.current
        let fallStart = calendar.date(from: DateComponents(year: year, month: 8, day: 1)) ?? Date()
        
        var consecutiveDays = 0
        for weatherData in data {
            if weatherData.timestamp >= fallStart {
                if weatherData.temperature < 60.0 {
                    consecutiveDays += 1
                    if consecutiveDays >= 7 {
                        return calendar.date(byAdding: .day, value: -6, to: weatherData.timestamp)
                    }
                } else {
                    consecutiveDays = 0
                }
            }
        }
        return nil
    }
    
    private func calculateAverageDate(_ dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var totalDayOfYear = 0
        
        for date in dates {
            totalDayOfYear += calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        }
        
        let averageDayOfYear = totalDayOfYear / dates.count
        let currentYear = calendar.component(.year, from: Date())
        
        return calendar.date(from: DateComponents(year: currentYear, day: averageDayOfYear))
    }
    
    private func createEmptyHistoricalContext(location: CLLocation) -> HistoricalWeatherContext {
        return HistoricalWeatherContext(
            location: location,
            currentDate: Date(),
            historicalData: [],
            yearlyAverages: [:],
            seasonalPatterns: HistoricalWeatherContext.SeasonalPatterns(
                averageFirstFrost: nil,
                averageLastFrost: nil,
                averageSpringTransition: nil,
                averageFallTransition: nil,
                growingSeasonStart: nil,
                growingSeasonEnd: nil
            )
        )
    }
}

// MARK: - Seasonal Analysis Results

struct SeasonalTransitionAnalysis: Sendable {
    let isTransitionDetected: Bool
    let confidence: Double
    let description: String
    let daysSinceTransition: Int
    let expectedDate: Date?
    let historicalAverage: Date?
    let temperatureTrend: TrendAnalysis.TrendDirection
}

struct HistoricalComparisonResult: Sendable {
    let historicalAverage: Double
    let temperatureDifference: Double
    let isWarmerThanHistorical: Bool
    let percentileRank: Double
    let percentileRange: (Double, Double)
    let dataPoints: Int
    let isWarmestOnRecord: Bool
    let isColdestOnRecord: Bool
    let temperatureDifferenceConfidence: Double
}

// MARK: - Analysis Implementation

extension TriggerEngine {
    
    private func analyzeSeasonalTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        seasonalType: SeasonalType
    ) -> SeasonalTransitionAnalysis {
        
        let calendar = Calendar.current
        let currentDate = Date()
        
        switch seasonalType {
        case .firstFrost:
            return analyzeFirstFrostTransition(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .lastFrost:
            return analyzeLastFrostTransition(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .springTransition:
            return analyzeSpringTransition(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .fallTransition:
            return analyzeFallTransition(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .summerTransition:
            return analyzeSummerTransition(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .winterTransition:
            return analyzeWinterTransition(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .growingSeasonStart:
            return analyzeGrowingSeasonStart(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        case .growingSeasonEnd:
            return analyzeGrowingSeasonEnd(currentWeather: currentWeather, historicalContext: historicalContext, currentDate: currentDate)
        }
    }
    
    private func analyzeFirstFrostTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        
        // First frost typically occurs in fall (September-December)
        guard currentMonth >= 9 || currentMonth <= 12 else {
            return SeasonalTransitionAnalysis(
                isTransitionDetected: false,
                confidence: 0.0,
                description: "First frost season not active (current month: \(currentMonth))",
                daysSinceTransition: 0,
                expectedDate: historicalContext.seasonalPatterns.averageFirstFrost,
                historicalAverage: historicalContext.seasonalPatterns.averageFirstFrost,
                temperatureTrend: .stable
            )
        }
        
        let isFreezingCondition = currentWeather.temperature <= 32.0
        let confidence = isFreezingCondition ? 1.0 : max(0.0, (40.0 - currentWeather.temperature) / 8.0)
        
        let description = isFreezingCondition ?
            "First frost detected: temperature \(currentWeather.temperature, specifier: "%.1f")°F" :
            "Frost conditions approaching: temperature \(currentWeather.temperature, specifier: "%.1f")°F"
        
        return SeasonalTransitionAnalysis(
            isTransitionDetected: isFreezingCondition,
            confidence: confidence,
            description: description,
            daysSinceTransition: isFreezingCondition ? 0 : -1,
            expectedDate: historicalContext.seasonalPatterns.averageFirstFrost,
            historicalAverage: historicalContext.seasonalPatterns.averageFirstFrost,
            temperatureTrend: .falling
        )
    }
    
    private func analyzeLastFrostTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        
        // Last frost typically occurs in spring (February-May)
        guard currentMonth >= 2 && currentMonth <= 5 else {
            return SeasonalTransitionAnalysis(
                isTransitionDetected: false,
                confidence: 0.0,
                description: "Last frost season not active (current month: \(currentMonth))",
                daysSinceTransition: 0,
                expectedDate: historicalContext.seasonalPatterns.averageLastFrost,
                historicalAverage: historicalContext.seasonalPatterns.averageLastFrost,
                temperatureTrend: .stable
            )
        }
        
        // Check if we've had several days above freezing
        let isAboveFreezing = currentWeather.temperature > 32.0
        let confidence = isAboveFreezing ? min(1.0, (currentWeather.temperature - 32.0) / 15.0) : 0.0
        
        let description = isAboveFreezing ?
            "Last frost may have passed: temperature \(currentWeather.temperature, specifier: "%.1f")°F" :
            "Still in frost risk period: temperature \(currentWeather.temperature, specifier: "%.1f")°F"
        
        return SeasonalTransitionAnalysis(
            isTransitionDetected: isAboveFreezing && currentWeather.temperature > 40.0,
            confidence: confidence,
            description: description,
            daysSinceTransition: isAboveFreezing ? 0 : -1,
            expectedDate: historicalContext.seasonalPatterns.averageLastFrost,
            historicalAverage: historicalContext.seasonalPatterns.averageLastFrost,
            temperatureTrend: .rising
        )
    }
    
    private func analyzeSpringTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        let springTemperatureThreshold = 55.0
        let isSpringLike = currentWeather.temperature > springTemperatureThreshold
        let confidence = isSpringLike ? min(1.0, (currentWeather.temperature - springTemperatureThreshold) / 15.0) : 0.0
        
        let description = isSpringLike ?
            "Spring transition detected: temperature \(currentWeather.temperature, specifier: "%.1f")°F" :
            "Spring transition pending: temperature \(currentWeather.temperature, specifier: "%.1f")°F"
        
        return SeasonalTransitionAnalysis(
            isTransitionDetected: isSpringLike,
            confidence: confidence,
            description: description,
            daysSinceTransition: isSpringLike ? 0 : -1,
            expectedDate: historicalContext.seasonalPatterns.averageSpringTransition,
            historicalAverage: historicalContext.seasonalPatterns.averageSpringTransition,
            temperatureTrend: .rising
        )
    }
    
    private func analyzeFallTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        let fallTemperatureThreshold = 60.0
        let isFallLike = currentWeather.temperature < fallTemperatureThreshold
        let confidence = isFallLike ? min(1.0, (fallTemperatureThreshold - currentWeather.temperature) / 15.0) : 0.0
        
        let description = isFallLike ?
            "Fall transition detected: temperature \(currentWeather.temperature, specifier: "%.1f")°F" :
            "Fall transition pending: temperature \(currentWeather.temperature, specifier: "%.1f")°F"
        
        return SeasonalTransitionAnalysis(
            isTransitionDetected: isFallLike,
            confidence: confidence,
            description: description,
            daysSinceTransition: isFallLike ? 0 : -1,
            expectedDate: historicalContext.seasonalPatterns.averageFallTransition,
            historicalAverage: historicalContext.seasonalPatterns.averageFallTransition,
            temperatureTrend: .falling
        )
    }
    
    private func analyzeSummerTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        let summerTemperatureThreshold = 75.0
        let isSummerLike = currentWeather.temperature > summerTemperatureThreshold
        let confidence = isSummerLike ? min(1.0, (currentWeather.temperature - summerTemperatureThreshold) / 15.0) : 0.0
        
        let description = isSummerLike ?
            "Summer transition detected: temperature \(currentWeather.temperature, specifier: "%.1f")°F" :
            "Summer transition pending: temperature \(currentWeather.temperature, specifier: "%.1f")°F"
        
        return SeasonalTransitionAnalysis(
            isTransitionDetected: isSummerLike,
            confidence: confidence,
            description: description,
            daysSinceTransition: isSummerLike ? 0 : -1,
            expectedDate: nil,
            historicalAverage: nil,
            temperatureTrend: .rising
        )
    }
    
    private func analyzeWinterTransition(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        let winterTemperatureThreshold = 40.0
        let isWinterLike = currentWeather.temperature < winterTemperatureThreshold
        let confidence = isWinterLike ? min(1.0, (winterTemperatureThreshold - currentWeather.temperature) / 15.0) : 0.0
        
        let description = isWinterLike ?
            "Winter transition detected: temperature \(currentWeather.temperature, specifier: "%.1f")°F" :
            "Winter transition pending: temperature \(currentWeather.temperature, specifier: "%.1f")°F"
        
        return SeasonalTransitionAnalysis(
            isTransitionDetected: isWinterLike,
            confidence: confidence,
            description: description,
            daysSinceTransition: isWinterLike ? 0 : -1,
            expectedDate: nil,
            historicalAverage: nil,
            temperatureTrend: .falling
        )
    }
    
    private func analyzeGrowingSeasonStart(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        // Growing season starts when risk of frost is past (same as last frost)
        return analyzeLastFrostTransition(
            currentWeather: currentWeather,
            historicalContext: historicalContext,
            currentDate: currentDate
        )
    }
    
    private func analyzeGrowingSeasonEnd(
        currentWeather: WeatherData,
        historicalContext: HistoricalWeatherContext,
        currentDate: Date
    ) -> SeasonalTransitionAnalysis {
        
        // Growing season ends with first frost
        return analyzeFirstFrostTransition(
            currentWeather: currentWeather,
            historicalContext: historicalContext,
            currentDate: currentDate
        )
    }
    
    private func calculateSeasonalEvaluationTime(
        seasonalType: SeasonalType,
        currentAnalysis: SeasonalTransitionAnalysis
    ) -> Date? {
        
        let calendar = Calendar.current
        let baseInterval: TimeInterval
        
        if currentAnalysis.isTransitionDetected {
            // If transition is detected, check less frequently
            baseInterval = 12 * 3600 // 12 hours
        } else {
            // During transition season, check more frequently
            let currentMonth = calendar.component(.month, from: Date())
            
            switch seasonalType {
            case .firstFrost, .growingSeasonEnd:
                baseInterval = (currentMonth >= 9 && currentMonth <= 11) ? 6 * 3600 : 24 * 3600
            case .lastFrost, .growingSeasonStart:
                baseInterval = (currentMonth >= 2 && currentMonth <= 5) ? 6 * 3600 : 24 * 3600
            case .springTransition:
                baseInterval = (currentMonth >= 3 && currentMonth <= 5) ? 4 * 3600 : 24 * 3600
            case .fallTransition:
                baseInterval = (currentMonth >= 9 && currentMonth <= 11) ? 4 * 3600 : 24 * 3600
            default:
                baseInterval = 12 * 3600
            }
        }
        
        return calendar.date(byAdding: .second, value: Int(baseInterval), to: Date())
    }
    
    private func performHistoricalComparison(
        location: CLLocation,
        currentWeather: WeatherData,
        comparisonDays: Int,
        useFeelsLike: Bool
    ) async -> HistoricalComparisonResult {
        
        let calendar = Calendar.current
        let currentDate = Date()
        let currentMonthDay = calendar.dateComponents([.month, .day], from: currentDate)
        
        // Get historical data for this date across multiple years
        let historicalData = await getHistoricalDataForDate(
            location: location,
            monthDay: currentMonthDay,
            years: comparisonDays / 365 + 1
        )
        
        let currentTemp = useFeelsLike ? currentWeather.apparentTemperature : currentWeather.temperature
        let historicalTemps = historicalData.map { useFeelsLike ? $0.apparentTemperature : $0.temperature }
        
        guard !historicalTemps.isEmpty else {
            return HistoricalComparisonResult(
                historicalAverage: currentTemp,
                temperatureDifference: 0.0,
                isWarmerThanHistorical: false,
                percentileRank: 0.5,
                percentileRange: (0.0, 1.0),
                dataPoints: 0,
                isWarmestOnRecord: false,
                isColdestOnRecord: false,
                temperatureDifferenceConfidence: 0.0
            )
        }
        
        let historicalAverage = historicalTemps.reduce(0, +) / Double(historicalTemps.count)
        let temperatureDifference = currentTemp - historicalAverage
        let sortedTemps = historicalTemps.sorted()
        
        // Calculate percentile rank
        let belowCurrent = historicalTemps.filter { $0 < currentTemp }.count
        let percentileRank = Double(belowCurrent) / Double(historicalTemps.count)
        
        // Determine percentile range (where current temp falls)
        let percentileRange = calculatePercentileRange(currentTemp: currentTemp, historicalTemps: sortedTemps)
        
        let isWarmestOnRecord = currentTemp > (sortedTemps.max() ?? currentTemp)
        let isColdestOnRecord = currentTemp < (sortedTemps.min() ?? currentTemp)
        
        // Calculate confidence based on sample size and difference magnitude
        let sampleSizeConfidence = min(1.0, Double(historicalTemps.count) / 10.0) // Full confidence with 10+ samples
        let differenceConfidence = min(1.0, abs(temperatureDifference) / 10.0) // Full confidence with 10°+ difference
        let temperatureDifferenceConfidence = (sampleSizeConfidence + differenceConfidence) / 2.0
        
        return HistoricalComparisonResult(
            historicalAverage: historicalAverage,
            temperatureDifference: temperatureDifference,
            isWarmerThanHistorical: temperatureDifference > 0,
            percentileRank: percentileRank,
            percentileRange: percentileRange,
            dataPoints: historicalTemps.count,
            isWarmestOnRecord: isWarmestOnRecord,
            isColdestOnRecord: isColdestOnRecord,
            temperatureDifferenceConfidence: temperatureDifferenceConfidence
        )
    }
    
    private func getHistoricalDataForDate(
        location: CLLocation,
        monthDay: DateComponents,
        years: Int
    ) async -> [WeatherData] {
        
        guard let modelContext = modelContext,
              let month = monthDay.month,
              let day = monthDay.day else {
            return []
        }
        
        var historicalData: [WeatherData] = []
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Search for this date in previous years
        for yearOffset in 1...years {
            let targetYear = currentYear - yearOffset
            guard let targetDate = calendar.date(from: DateComponents(year: targetYear, month: month, day: day)) else {
                continue
            }
            
            // Search for weather data within 1 day of the target date
            let startDate = calendar.date(byAdding: .day, value: -1, to: targetDate) ?? targetDate
            let endDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            
            let searchRadius: CLLocationDistance = 15000 // 15km
            let minLat = location.coordinate.latitude - (searchRadius / 111000)
            let maxLat = location.coordinate.latitude + (searchRadius / 111000)
            let minLon = location.coordinate.longitude - (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
            let maxLon = location.coordinate.longitude + (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
            
            let predicate = #Predicate<WeatherData> { weather in
                weather.timestamp >= startDate &&
                weather.timestamp <= endDate &&
                weather.location?.latitude >= minLat &&
                weather.location?.latitude <= maxLat &&
                weather.location?.longitude >= minLon &&
                weather.location?.longitude <= maxLon
            }
            
            let descriptor = FetchDescriptor<WeatherData>(
                predicate: predicate,
                sortBy: [SortDescriptor(\WeatherData.timestamp, order: .forward)]
            )
            
            do {
                let yearData = try modelContext.fetch(descriptor)
                if let closestData = yearData.min(by: { abs($0.timestamp.timeIntervalSince(targetDate)) < abs($1.timestamp.timeIntervalSince(targetDate)) }) {
                    historicalData.append(closestData)
                }
            } catch {
                logger.warning("Failed to fetch historical data for \(targetYear): \(error)")
            }
        }
        
        return historicalData
    }
    
    private func calculatePercentileRange(currentTemp: Double, historicalTemps: [Double]) -> (Double, Double) {
        guard !historicalTemps.isEmpty else { return (0.0, 1.0) }
        
        let sortedTemps = historicalTemps.sorted()
        let count = sortedTemps.count
        
        // Find where current temp would be inserted
        let insertIndex = sortedTemps.firstIndex { $0 >= currentTemp } ?? count
        
        let lowerPercentile = max(0.0, Double(insertIndex - 1) / Double(count))
        let upperPercentile = min(1.0, Double(insertIndex) / Double(count))
        
        return (lowerPercentile, upperPercentile)
    }
}