//
//  TriggerEngine+Performance.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation
import os

// Allow grouping by CLLocationCoordinate2D in this file
extension CLLocationCoordinate2D: Hashable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

// MARK: - Performance Optimizations Extension

extension TriggerEngine {
    
    // MARK: - Batch Evaluation Optimizations
    
    func evaluateRemindersInBatches(
        batchSize: Int = 10,
        maxConcurrentBatches: Int = 3
    ) async -> [TriggerEvaluationResult] {
        
        guard let modelContext = modelContext else {
            logger.error("TriggerEngine not configured")
            return []
        }
        
        // Fetch all active reminders
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isCurrentlyActive && reminder.canTrigger
            }
        )
        
        do {
            let allReminders = try modelContext.fetch(descriptor)
            
            // Group by location for batch processing
            let locationGroups = Dictionary(grouping: allReminders) { reminder in
                reminder.location?.coordinate ?? CLLocationCoordinate2D()
            }
            
            logger.info("Processing \(allReminders.count) reminders in \(locationGroups.count) location groups")
            
            var allResults: [TriggerEvaluationResult] = []
            
            // Process location groups in batches with controlled concurrency
            let locationGroupsArray = Array(locationGroups)
            let batches = locationGroupsArray.chunked(into: batchSize)
            
            for batch in batches {
                // Process this batch with limited concurrency
                let batchResults = await withTaskGroup(of: [TriggerEvaluationResult].self, returning: [TriggerEvaluationResult].self) { group in
                    var results: [TriggerEvaluationResult] = []
                    var activeTasks = 0
                    
                    for (coordinate, reminders) in batch {
                        if activeTasks < maxConcurrentBatches {
                            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                            group.addTask {
                                await self.evaluateRemindersForLocation(reminders, at: location)
                            }
                            activeTasks += 1
                        }
                    }
                    
                    for await batchResult in group {
                        results.append(contentsOf: batchResult)
                    }
                    
                    return results
                }
                
                allResults.append(contentsOf: batchResults)
            }
            
            return allResults
            
        } catch {
            logger.error("Failed to fetch reminders for batch evaluation: \(error)")
            return []
        }
    }
    
    // MARK: - Cache Management
    
    func preloadCachesForLocations(_ locations: [CLLocation]) async {
        logger.info("Preloading caches for \(locations.count) locations")
        
        await withTaskGroup(of: Void.self) { group in
            for location in locations {
                group.addTask {
                    // Preload historical context
                    let _ = await self.getHistoricalWeatherContext(for: location)
                    
                    // Preload trend analysis for common periods
                    let _ = await self.getTrendAnalysis(for: location, days: 7, useFeelsLike: false)
                    let _ = await self.getTrendAnalysis(for: location, days: 7, useFeelsLike: true)
                    let _ = await self.getTrendAnalysis(for: location, days: 14, useFeelsLike: false)
                }
            }
        }
        
        logger.info("Cache preloading completed")
    }
    
    func optimizeCaches() async {
        let initialCacheSize = evaluationCache.count + historicalDataCache.count + trendAnalysisCache.count
        
        // Remove expired evaluation cache entries (older than 15 minutes)
        let cacheExpiration = Date().addingTimeInterval(-15 * 60)
        evaluationCache = evaluationCache.filter { $0.value.evaluationTime > cacheExpiration }
        
        // Remove old historical cache entries (keep only recent ones)
        if historicalDataCache.count > 50 {
            let sortedEntries = historicalDataCache.sorted { $0.value.currentDate > $1.value.currentDate }
            historicalDataCache = Dictionary(uniqueKeysWithValues:
                sortedEntries.prefix(30).map { ($0.key, $0.value) }
            )
        }
        
        // Remove old trend analysis cache entries
        if trendAnalysisCache.count > 100 {
            let keysToRemove = Array(trendAnalysisCache.keys.prefix(trendAnalysisCache.count - 50))
            for key in keysToRemove {
                trendAnalysisCache.removeValue(forKey: key)
            }
        }
        
        let finalCacheSize = evaluationCache.count + historicalDataCache.count + trendAnalysisCache.count
        logger.info("Cache optimization: \(initialCacheSize) -> \(finalCacheSize) entries")
    }
    
    // MARK: - Smart Evaluation Scheduling
    
    func calculateOptimalEvaluationInterval(for condition: TriggerCondition) -> TimeInterval {
        switch condition.triggerType {
        case .exactTemperature, .temperatureRange:
            // Fast evaluation for simple temperature checks
            return 15 * 60 // 15 minutes
            
        case .consecutiveDays:
            // Daily evaluation for consecutive day patterns
            return 24 * 3600 // 24 hours
            
        case .averageTemperature:
            // Evaluation based on averaging period
            let averagingHours = Double(condition.averagingPeriod * 24)
            return min(averagingHours / 4, 24 * 3600) // Quarter of averaging period, max 24h
            
        case .seasonalMarker:
            // Seasonal evaluation - more frequent during transition seasons
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: Date())
            
            switch condition.seasonalType {
            case .firstFrost, .growingSeasonEnd:
                return (currentMonth >= 9 && currentMonth <= 11) ? 12 * 3600 : 24 * 3600
            case .lastFrost, .growingSeasonStart:
                return (currentMonth >= 2 && currentMonth <= 5) ? 12 * 3600 : 24 * 3600
            case .springTransition, .fallTransition:
                return (currentMonth >= 3 && currentMonth <= 5) || (currentMonth >= 9 && currentMonth <= 11) ? 8 * 3600 : 24 * 3600
            default:
                return 24 * 3600
            }
            
        case .composite:
            // Composite conditions need frequent evaluation
            return 30 * 60 // 30 minutes
            
        case .historicalComparison:
            // Daily evaluation for historical comparisons
            return 24 * 3600
        }
    }
    
    func predictEvaluationLoad() async -> EvaluationLoadPrediction {
        guard let modelContext = modelContext else {
            return EvaluationLoadPrediction(
                activeReminders: 0,
                locationGroups: 0,
                estimatedDuration: 0,
                complexity: .low,
                recommendations: ["Configure TriggerEngine with ModelContext"]
            )
        }
        
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isCurrentlyActive && reminder.canTrigger
            }
        )
        
        do {
            let activeReminders = try modelContext.fetch(descriptor)
            let locationGroups = Set(activeReminders.compactMap { reminder in
                guard let location = reminder.location else { return nil }
                return "\(location.latitude),\(location.longitude)"
            }).count
            
            // Estimate complexity
            var complexityScore = 0
            var recommendations: [String] = []
            
            for reminder in activeReminders {
                guard let condition = reminder.triggerCondition else { continue }
                
                switch condition.triggerType {
                case .exactTemperature, .temperatureRange:
                    complexityScore += 1
                case .consecutiveDays, .averageTemperature:
                    complexityScore += 3
                case .seasonalMarker, .historicalComparison:
                    complexityScore += 5
                case .composite:
                    complexityScore += 7
                }
            }
            
            let averageComplexity = activeReminders.count > 0 ? Double(complexityScore) / Double(activeReminders.count) : 0
            
            let complexity: EvaluationComplexity
            if averageComplexity < 2 {
                complexity = .low
            } else if averageComplexity < 4 {
                complexity = .medium
            } else {
                complexity = .high
                recommendations.append("Consider optimizing complex trigger conditions")
            }
            
            // Estimate duration based on historical performance
            let metrics = getPerformanceMetrics()
            let estimatedDuration = metrics.averageDuration * Double(locationGroups) * 1.2 // 20% buffer
            
            if locationGroups > 20 {
                recommendations.append("Consider batch processing for \(locationGroups) location groups")
            }
            
            if activeReminders.count > 100 {
                recommendations.append("Large number of reminders (\(activeReminders.count)) may impact performance")
            }
            
            return EvaluationLoadPrediction(
                activeReminders: activeReminders.count,
                locationGroups: locationGroups,
                estimatedDuration: estimatedDuration,
                complexity: complexity,
                recommendations: recommendations
            )
            
        } catch {
            logger.error("Failed to predict evaluation load: \(error)")
            return EvaluationLoadPrediction(
                activeReminders: 0,
                locationGroups: 0,
                estimatedDuration: 0,
                complexity: .low,
                recommendations: ["Failed to analyze workload"]
            )
        }
    }
    
    // MARK: - Memory Management
    
    func performMemoryCleanup() async {
        logger.info("Performing memory cleanup")
        
        // Clear expired caches
        await optimizeCaches()
        
        // Force garbage collection hint (Swift will decide)
        evaluationCache.reserveCapacity(evaluationCache.count)
        historicalDataCache.reserveCapacity(historicalDataCache.count)
        trendAnalysisCache.reserveCapacity(trendAnalysisCache.count)
        
        logger.info("Memory cleanup completed")
    }
    
    // MARK: - Diagnostic Tools
    
    func generatePerformanceReport() async -> TriggerEnginePerformanceReport {
        let metrics = getPerformanceMetrics()
        let loadPrediction = await predictEvaluationLoad()
        
        let cacheStats = CacheStatistics(
            evaluationCacheSize: evaluationCache.count,
            historicalCacheSize: historicalDataCache.count,
            trendCacheSize: trendAnalysisCache.count,
            totalMemoryEstimate: estimateCacheMemoryUsage()
        )
        
        return TriggerEnginePerformanceReport(
            evaluationCount: metrics.count,
            lastEvaluationTime: metrics.lastEvaluation,
            averageDuration: metrics.averageDuration,
            cacheStatistics: cacheStats,
            loadPrediction: loadPrediction,
            recommendations: generatePerformanceRecommendations(metrics: metrics, cacheStats: cacheStats, loadPrediction: loadPrediction)
        )
    }
    
    private func estimateCacheMemoryUsage() -> Int {
        // Rough estimation of cache memory usage
        let evaluationCacheMemory = evaluationCache.count * 500 // ~500 bytes per result
        let historicalCacheMemory = historicalDataCache.count * 2000 // ~2KB per context
        let trendCacheMemory = trendAnalysisCache.count * 300 // ~300 bytes per analysis
        
        return evaluationCacheMemory + historicalCacheMemory + trendCacheMemory
    }
    
    private func generatePerformanceRecommendations(
        metrics: (count: Int, lastEvaluation: Date?, averageDuration: TimeInterval),
        cacheStats: CacheStatistics,
        loadPrediction: EvaluationLoadPrediction
    ) -> [String] {
        
        var recommendations: [String] = []
        
        // Duration recommendations
        if metrics.averageDuration > 10.0 {
            let formatted = String(format: "%.1f", metrics.averageDuration)
            recommendations.append("Average evaluation time (\(formatted)s) is high. Consider batch processing.")
        }
        
        // Cache recommendations
        if cacheStats.totalMemoryEstimate > 5_000_000 { // 5MB
            recommendations.append("Cache memory usage (\(cacheStats.totalMemoryEstimate / 1_000_000)MB) is high. Consider cache cleanup.")
        }
        
        // Load recommendations
        recommendations.append(contentsOf: loadPrediction.recommendations)
        
        // Frequency recommendations
        if metrics.count > 1000 {
            recommendations.append("High evaluation count (\(metrics.count)). Consider optimizing evaluation frequency.")
        }
        
        return recommendations
    }
}

// MARK: - Performance Data Structures

struct EvaluationLoadPrediction: Sendable {
    let activeReminders: Int
    let locationGroups: Int
    let estimatedDuration: TimeInterval
    let complexity: EvaluationComplexity
    let recommendations: [String]
}

enum EvaluationComplexity: Sendable {
    case low
    case medium
    case high
}

struct CacheStatistics: Sendable {
    let evaluationCacheSize: Int
    let historicalCacheSize: Int
    let trendCacheSize: Int
    let totalMemoryEstimate: Int
}

struct TriggerEnginePerformanceReport: Sendable {
    let evaluationCount: Int
    let lastEvaluationTime: Date?
    let averageDuration: TimeInterval
    let cacheStatistics: CacheStatistics
    let loadPrediction: EvaluationLoadPrediction
    let recommendations: [String]
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
