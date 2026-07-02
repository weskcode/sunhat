//
//  WeatherService.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation
import BackgroundTasks
import Combine
import os

@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var connectionStatus: ConnectionStatus = .unknown

    private var weatherActor: WeatherServiceActor?
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherService")

    nonisolated init() {
        // Actor will be created in configure
    }

    func configure(modelContainer: ModelContainer, openWeatherMapKey: String? = nil) async {
        let modelContext = modelContainer.mainContext
        self.weatherActor = WeatherServiceActor(modelContext: modelContext)
        await weatherActor?.configure(openWeatherMapKey: openWeatherMapKey)
    }
    
    func fetchWeatherData(for location: CLLocation, forceRefresh: Bool = false) async throws -> WeatherData {
        guard let weatherActor else {
            logger.error("WeatherService used before configure(modelContainer:) — returning serviceUnavailable")
            throw WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let weatherData = try await weatherActor.fetchWeatherData(for: location, forceRefresh: forceRefresh)
            lastUpdateTime = Date()
            connectionStatus = .connected
            return weatherData
        } catch {
            connectionStatus = .disconnected
            logger.error("Failed to fetch weather data: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchCurrentWeather(for location: CLLocation, forceRefresh: Bool = false) async throws -> WeatherData {
        try await fetchWeatherData(for: location, forceRefresh: forceRefresh)
    }

    func scheduleBackgroundRefresh() {
        guard let weatherActor else {
            logger.warning("scheduleBackgroundRefresh called before WeatherService was configured")
            return
        }
        Task {
            weatherActor.scheduleBackgroundRefresh()
        }
    }

    func handleBackgroundRefresh() async {
        guard let weatherActor else {
            logger.warning("handleBackgroundRefresh called before WeatherService was configured — skipping")
            return
        }
        await weatherActor.handleBackgroundRefresh()
    }

    func getCachedWeatherData(for location: CLLocation) async -> WeatherData? {
        guard let weatherActor else { return nil }
        return await weatherActor.getCachedWeatherData(for: location)
    }

    func clearCache() async {
        guard let weatherActor else { return }
        await weatherActor.clearCache()
    }
}

enum ConnectionStatus {
    case unknown
    case connected
    case disconnected
    case rateLimited
}

// MARK: - Weather Service Actor

@MainActor
class WeatherServiceActor {
    private var modelContext: ModelContext
    private var providers: [any WeatherAPI] = []
    private let cacheExpirationInterval: TimeInterval = 15 * 60 // 15 minutes
    private let rateLimiter = RateLimiter()
    private let backgroundTaskIdentifier = "org.wesley.sunhat.weather-refresh"

    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherServiceActor")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func configure(openWeatherMapKey: String? = nil) async {

        // Initialize providers in priority order
        var newProviders: [any WeatherAPI] = []

        // Add Apple WeatherKit (always available)
        let appleWeatherKitAPI = AppleWeatherKitAPI()
        newProviders.append(appleWeatherKitAPI)

        // Add OpenWeatherMap only if API key is provided
        if let apiKey = openWeatherMapKey, !apiKey.isEmpty {
            let openWeatherMapAPI = OpenWeatherMapAPI(apiKey: apiKey)
            newProviders.append(openWeatherMapAPI)
        }

        self.providers = newProviders
        logger.info("WeatherService configured with \(self.providers.count) providers")
    }
    
    func fetchWeatherData(for location: CLLocation, forceRefresh: Bool = false) async throws -> WeatherData {
        logger.debug("Starting fetchWeatherData for location: \(location.coordinate.latitude), \(location.coordinate.longitude), forceRefresh: \(forceRefresh)")
        // Check cache first unless force refresh is requested
        if !forceRefresh, let cachedData = await getCachedWeatherData(for: location) {
            logger.debug("Returning cached weather data for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return cachedData
        }
        
        // Check rate limiting
        guard await rateLimiter.canMakeRequest() else {
            logger.warning("Rate limit exceeded, returning cached data if available")
            if let cachedData = await getCachedWeatherData(for: location, allowExpired: true) {
                return cachedData
            }
            throw WeatherError.rateLimitExceeded(retryAfter: await rateLimiter.timeUntilNextRequest())
        }
        
        // Try providers in order until one succeeds
        var lastError: WeatherError?
        
        // Sort providers by priority within the actor
        let sortedProviders = providers.sorted { provider1, provider2 in
            provider1.provider.priority < provider2.provider.priority
        }
        
        for provider in sortedProviders {
            do {
                let providerName = provider.provider.displayName
                guard await provider.isAvailable else {
                    logger.debug("Provider \(providerName) is not available")
                    continue
                }
                
                logger.debug("Attempting to fetch weather data from \(providerName)")
                await rateLimiter.recordRequest()
                
                let weatherDataDTO = try await provider.fetchWeatherData(for: location)
                
                // Convert DTO to WeatherData and cache the result
                let weatherData = weatherDataDTO.toWeatherData()
                await cacheWeatherData(weatherData, for: location)
                
                logger.info("Successfully fetched weather data from \(providerName)")
                return weatherData
                
            } catch let error as WeatherError {
                let providerName = provider.provider.displayName
                logger.warning("Provider \(providerName) failed: \(error.localizedDescription)")
                lastError = error
                
                // If rate limited, wait before trying next provider
                if case .rateLimitExceeded(let retryAfter) = error {
                    if let retryAfter = retryAfter, retryAfter < 60 {
                        try? await Task.sleep(for: .seconds(retryAfter))
                    }
                }
            } catch {
                let providerName = provider.provider.displayName
                logger.warning("Provider \(providerName) failed with unknown error: \(error)")
                lastError = .unknown(error)
            }
        }
        
        // All providers failed, try to return cached data even if expired
        if let cachedData = await getCachedWeatherData(for: location, allowExpired: true) {
            logger.warning("All providers failed, returning expired cached data")
            return cachedData
        }
        
        logger.error("All weather providers failed and no cached data available")
        throw lastError ?? WeatherError.allProvidersFailed
    }
    
    func getCachedWeatherData(for location: CLLocation, allowExpired: Bool = false) async -> WeatherData? {
        let searchRadius: CLLocationDistance = 10000 // 10km radius
        let minLat = location.coordinate.latitude - (searchRadius / 111000)
        let maxLat = location.coordinate.latitude + (searchRadius / 111000)
        let minLon = location.coordinate.longitude - (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))
        let maxLon = location.coordinate.longitude + (searchRadius / (111000 * cos(location.coordinate.latitude * .pi / 180)))

        // Use simpler descriptor without key paths that cause issues
        let descriptor = FetchDescriptor<WeatherData>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let results = try modelContext.fetch(descriptor)

            for weatherData in results {
                // Filter manually since Predicate key paths cause issues
                guard let weatherLocation = weatherData.location,
                      weatherLocation.latitude >= minLat,
                      weatherLocation.latitude <= maxLat,
                      weatherLocation.longitude >= minLon,
                      weatherLocation.longitude <= maxLon else {
                    continue
                }

                let dataAge = Date().timeIntervalSince(weatherData.timestamp)

                if allowExpired || dataAge < cacheExpirationInterval {
                    logger.debug("Found cached weather data, age: \(dataAge) seconds")
                    return weatherData
                }
            }
        } catch {
            logger.error("Failed to fetch cached weather data: \(error)")
        }

        return nil
    }
    
    private func cacheWeatherData(_ weatherData: WeatherData, for location: CLLocation) async {
        // Create or update location data
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        weatherData.location = locationData
        weatherData.timestamp = Date()
        weatherData.lastUpdated = Date()
        weatherData.expiresAt = Calendar.current.date(byAdding: .minute, value: 15, to: Date())

        modelContext.insert(weatherData)

        do {
            try modelContext.save()
            logger.debug("Cached weather data for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } catch {
            logger.error("Failed to cache weather data: \(error)")
        }

        // Clean up old cache entries
        await cleanupOldCache()
    }
    
    private func cleanupOldCache() async {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()

        // Use simple descriptor and filter manually
        let descriptor = FetchDescriptor<WeatherData>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let allEntries = try modelContext.fetch(descriptor)
            let oldEntries = allEntries.filter { $0.timestamp < cutoffDate }

            for entry in oldEntries {
                modelContext.delete(entry)
            }
            try modelContext.save()
            logger.debug("Cleaned up \(oldEntries.count) old cache entries")
        } catch {
            logger.error("Failed to cleanup old cache: \(error)")
        }
    }
    
    func clearCache() async {
        let descriptor = FetchDescriptor<WeatherData>()

        do {
            let allEntries = try modelContext.fetch(descriptor)
            for entry in allEntries {
                modelContext.delete(entry)
            }
            try modelContext.save()
            logger.info("Cleared all cached weather data")
        } catch {
            logger.error("Failed to clear cache: \(error)")
        }
    }
    
    // MARK: - Background Refresh

    func scheduleBackgroundRefresh() {
        Task {
            await scheduleBackgroundRefreshAsync()
        }
    }

    private func scheduleBackgroundRefreshAsync() async {
        // Use iOS 26+ background task scheduling
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            // Submit the task using the standard API
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background weather refresh")
        } catch {
            logger.error("Failed to schedule background refresh: \(error)")
        }
    }
    
    func performFetch(for location: CLLocation, forceRefresh: Bool) async throws {
        _ = try await fetchWeatherData(for: location, forceRefresh: forceRefresh)
    }

    func handleBackgroundRefresh() async {
        logger.info("Handling background weather refresh")

        logger.debug("Fetching active reminders")
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isActive && !reminder.isCompleted && !reminder.isPaused && reminder.location != nil
            }
        )

        let activeReminders: [WeatherReminder]
        do {
            activeReminders = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch active reminders for background refresh: \(error)")
            return
        }

        logger.debug("Found \(activeReminders.count) active reminders to refresh")

        // Group reminders by location to avoid duplicate requests
        let locationGroups = Dictionary(grouping: activeReminders) { reminder in
            guard let location = reminder.location else { return "unknown" }
            return "\(location.latitude),\(location.longitude)"
        }

        // Convert location groups to coordinates
        let locationCoordinates = locationGroups.compactMap { (key, reminders) -> (String, CLLocationCoordinate2D)? in
            guard let reminder = reminders.first, let location = reminder.location else { return nil }
            return (key, location.clLocation.coordinate)
        }

        await withTaskGroup(of: Void.self) { group in
            for (_, coordinate) in locationCoordinates {
                group.addTask { [weak self] in
                    guard let self = self else { return }

                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                    do {
                        try await self.performFetch(for: location, forceRefresh: true)
                        self.logger.debug("Background refresh successful for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    } catch {
                        self.logger.warning("Background refresh failed for location: \(location.coordinate.latitude), \(location.coordinate.longitude), error: \(error)")
                    }
                }
            }
        }

        // Schedule next refresh
        scheduleBackgroundRefresh()
    }
}

// MARK: - Rate Limiter

private actor RateLimiter {
    private var requestTimes: [Date] = []
    private let maxRequestsPerMinute = 60
    private let maxRequestsPerHour = 1000
    
    func canMakeRequest() -> Bool {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        // Clean up old requests
        requestTimes = requestTimes.filter { $0 > oneHourAgo }
        
        let recentRequests = requestTimes.filter { $0 > oneMinuteAgo }
        let hourlyRequests = requestTimes.count
        
        return recentRequests.count < maxRequestsPerMinute && hourlyRequests < maxRequestsPerHour
    }
    
    func recordRequest() {
        requestTimes.append(Date())
    }
    
    func timeUntilNextRequest() -> TimeInterval? {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        let recentRequests = requestTimes.filter { $0 > oneMinuteAgo }
        
        if recentRequests.count >= maxRequestsPerMinute {
            // Find the oldest request in the last minute
            if let oldestRecent = recentRequests.min() {
                return 60 - now.timeIntervalSince(oldestRecent)
            }
        }
        
        return nil
    }
}
