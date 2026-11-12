//
//  WeatherService.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import CoreLocation
import Combine
import os

@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var connectionStatus: ConnectionStatus = .unknown

    /// Fetches can overlap; isLoading stays true until the last one finishes.
    private var activeFetchCount = 0 {
        didSet { isLoading = activeFetchCount > 0 }
    }

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
            logger.error("WeatherService used before configure(modelContainer:), returning serviceUnavailable")
            throw WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        }

        activeFetchCount += 1
        defer { activeFetchCount -= 1 }

        do {
            let weatherData = try await weatherActor.fetchWeatherData(for: location, forceRefresh: forceRefresh)
            lastUpdateTime = weatherData.timestamp
            connectionStatus = Date().timeIntervalSince(weatherData.timestamp) < 15 * 60 ? .connected : .disconnected
            return weatherData
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            connectionStatus = .disconnected
            logger.error("Failed to fetch weather data: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchCurrentWeather(for location: CLLocation, forceRefresh: Bool = false) async throws -> WeatherData {
        try await fetchWeatherData(for: location, forceRefresh: forceRefresh)
    }

    /// Real provider hourly forecast for the next ~24 hours, or `[]` when unavailable.
    func fetchHourlyForecast(for location: CLLocation) async -> [HourlyForecastDTO] {
        guard let weatherActor else {
            logger.warning("fetchHourlyForecast called before WeatherService was configured")
            return []
        }
        return await weatherActor.fetchHourlyForecast(for: location)
    }

    func handleBackgroundRefresh() async {
        guard let weatherActor else {
            logger.warning("handleBackgroundRefresh called before WeatherService was configured, skipping")
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
    // A context alone does not keep its SwiftData backing store alive.
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext
    private var providers: [any WeatherAPI] = []
    private let now: () -> Date
    private let cacheExpirationInterval: TimeInterval = 15 * 60 // 15 minutes
    private let offlineCacheExpirationInterval: TimeInterval = 24 * 60 * 60
    /// Latest provider responses stay in memory so sampling history cannot
    /// revert current conditions. Hourly rows are not persisted; empty hours
    /// mean hourly forecasts are unavailable.
    private var recentWeather: [String: (id: UUID, fetchedAt: Date, data: WeatherDataDTO, latitude: Double, longitude: Double)] = [:]
    private var cacheGeneration = 0
    private let rateLimiter = RateLimiter()

    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherServiceActor")

    init(modelContext: ModelContext, providers: [any WeatherAPI] = [], now: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.modelContainer = modelContext.container
        self.providers = providers
        self.now = now
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
        try Task.checkCancellation()
        let generation = cacheGeneration
        logger.debug("Starting fetchWeatherData for location: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private), forceRefresh: \(forceRefresh)")
        // Check cache first unless force refresh is requested
        if !forceRefresh, let cachedData = await getCachedWeatherData(for: location) {
            guard generation == cacheGeneration else { throw CancellationError() }
            logger.debug("Returning cached weather data for location: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private)")
            return cachedData
        }
        
        // Check rate limiting
        guard await rateLimiter.canMakeRequest() else {
            logger.warning("Rate limit exceeded, returning cached data if available")
            if let cachedData = await getCachedWeatherData(for: location, allowExpired: true) {
                guard generation == cacheGeneration else { throw CancellationError() }
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
            try Task.checkCancellation()

            do {
                let providerName = provider.provider.displayName
                guard await provider.isAvailable else {
                    logger.debug("Provider \(providerName) is not available")
                    continue
                }
                
                logger.debug("Attempting to fetch weather data from \(providerName)")
                await rateLimiter.recordRequest()
                guard generation == cacheGeneration else { throw CancellationError() }
                
                let weatherDataDTO = try await provider.fetchWeatherData(for: location)
                try Task.checkCancellation()
                guard generation == cacheGeneration else { throw CancellationError() }

                // Convert DTO to WeatherData and cache the result
                let weatherData = weatherDataDTO.toWeatherData()
                await cacheWeatherData(weatherData, for: location, generation: generation)
                guard generation == cacheGeneration else { throw CancellationError() }
                let fetchedAt = weatherData.timestamp
                recentWeather = recentWeather.filter {
                    let age = fetchedAt.timeIntervalSince($0.value.fetchedAt)
                    return age >= 0 && age <= offlineCacheExpirationInterval
                }
                recentWeather[recentWeatherKey(for: location)] = (
                    id: weatherData.id, fetchedAt: fetchedAt, data: weatherDataDTO,
                    latitude: weatherData.locationLatitude, longitude: weatherData.locationLongitude
                )
                
                logger.info("Successfully fetched weather data from \(providerName)")
                return weatherData
                
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as WeatherError {
                let providerName = provider.provider.displayName
                logger.warning("Provider \(providerName) failed: \(error.localizedDescription)")
                lastError = error
                
                // If rate limited, wait before trying next provider
                if case .rateLimitExceeded(let retryAfter) = error {
                    if let retryAfter = retryAfter, retryAfter < 60 {
                        try await Task.sleep(for: .seconds(retryAfter))
                    }
                }
            } catch {
                let providerName = provider.provider.displayName
                logger.warning("Provider \(providerName) failed with unknown error: \(error)")
                lastError = .unknown(error)
            }
        }

        try Task.checkCancellation()
        guard generation == cacheGeneration else { throw CancellationError() }
        
        // All providers failed, try to return cached data even if expired
        if let cachedData = await getCachedWeatherData(for: location, allowExpired: true) {
            guard generation == cacheGeneration else { throw CancellationError() }
            logger.warning("All providers failed, returning expired cached data")
            return cachedData
        }
        
        logger.error("All weather providers failed and no cached data available")
        throw lastError ?? WeatherError.allProvidersFailed
    }
    
    /// Real provider hourly forecast for the location, or `[]` when unavailable.
    /// Serves the in-memory copy from the last provider fetch when fresh; otherwise
    /// refreshes through the normal fetch path (which also updates the SwiftData
    /// weather cache and respects the rate limiter). Never synthesizes hours.
    func fetchHourlyForecast(for location: CLLocation) async -> [HourlyForecastDTO] {
        let key = recentWeatherKey(for: location)
        if let entry = recentWeather[key],
           now().timeIntervalSince(entry.fetchedAt) < cacheExpirationInterval,
           !entry.data.hourly.isEmpty {
            return futureHours(entry.data.hourly)
        }

        _ = try? await fetchWeatherData(for: location, forceRefresh: true)

        if let entry = recentWeather[key],
           now().timeIntervalSince(entry.fetchedAt) < cacheExpirationInterval {
            return futureHours(entry.data.hourly)
        }
        return []
    }

    private func futureHours(_ hours: [HourlyForecastDTO]) -> [HourlyForecastDTO] {
        let currentHourStart = Calendar.current.dateInterval(of: .hour, for: now())?.start ?? now()
        return hours.filter { $0.date >= currentHourStart }
    }

    private func recentWeatherKey(for location: CLLocation) -> String {
        String(format: "%.2f,%.2f", location.coordinate.latitude, location.coordinate.longitude)
    }

    func getCachedWeatherData(for location: CLLocation, allowExpired: Bool = false) async -> WeatherData? {
        let currentTime = now()
        if let entry = recentWeather.values.filter({ entry in
            let age = currentTime.timeIntervalSince(entry.fetchedAt)
            return age >= 0 && (age < cacheExpirationInterval || (allowExpired && age <= offlineCacheExpirationInterval)) &&
                CLLocation(latitude: entry.latitude, longitude: entry.longitude).distance(from: location) <= 1_000
        }).max(by: { $0.fetchedAt < $1.fetchedAt }) {
            let weather = entry.data.toWeatherData()
            weather.id = entry.id
            weather.locationLatitude = entry.latitude
            weather.locationLongitude = entry.longitude
            weather.timestamp = entry.fetchedAt
            weather.observationTime = entry.fetchedAt
            weather.lastUpdated = entry.fetchedAt
            weather.expiresAt = entry.fetchedAt.addingTimeInterval(cacheExpirationInterval)
            return weather
        }
        // Use simpler descriptor without key paths that cause issues
        var descriptor = FetchDescriptor<WeatherData>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        do {
            let results = try modelContext.fetch(descriptor)

            for weatherData in results {
                let cachedLatitude = weatherData.location?.latitude ?? weatherData.locationLatitude
                let cachedLongitude = weatherData.location?.longitude ?? weatherData.locationLongitude

                guard CLLocation(latitude: cachedLatitude, longitude: cachedLongitude)
                    .distance(from: location) <= 1_000 else {
                    continue
                }

                let dataAge = now().timeIntervalSince(weatherData.timestamp)

                if dataAge >= 0 && (dataAge < cacheExpirationInterval || (allowExpired && dataAge <= offlineCacheExpirationInterval)) {
                    logger.debug("Found cached weather data, age: \(dataAge) seconds")
                    return weatherData
                }
            }
        } catch {
            logger.error("Failed to fetch cached weather data: \(error)")
        }

        return nil
    }
    
    private func cacheWeatherData(_ weatherData: WeatherData, for location: CLLocation, generation: Int) async {
        guard generation == cacheGeneration else { return }
        // Separate LocationData rows can outlive samples; keep history coordinates on the sample.
        let latitude = (location.coordinate.latitude * 100).rounded() / 100
        let longitude = (location.coordinate.longitude * 100).rounded() / 100
        weatherData.locationLatitude = latitude
        weatherData.locationLongitude = longitude
        weatherData.timestamp = now()
        weatherData.lastUpdated = now()
        weatherData.expiresAt = Calendar.current.date(byAdding: .minute, value: 15, to: now())

        do {
            let now = weatherData.timestamp
            let recentCutoff = now.addingTimeInterval(-cacheExpirationInterval)
            let recentSamples = FetchDescriptor<WeatherData>(predicate: #Predicate { sample in
                sample.locationLatitude == latitude && sample.locationLongitude == longitude &&
                sample.timestamp >= recentCutoff && sample.timestamp <= now
            })
            // Forced refreshes still return fresh conditions; history needs only one sample per interval.
            guard try modelContext.fetchCount(recentSamples) == 0 else {
                await cleanupOldCache()
                return
            }
            modelContext.insert(weatherData)
            try modelContext.save()
            logger.debug("Cached weather data for location: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private)")
        } catch {
            logger.error("Failed to cache weather data: \(error)")
        }

        // Clean up old cache entries
        await cleanupOldCache()
    }
    
    private func cleanupOldCache() async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -35, to: now()) ?? now()

        let descriptor = FetchDescriptor<WeatherData>(
            predicate: #Predicate { weatherData in
                weatherData.timestamp < cutoffDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let oldEntries = try modelContext.fetch(descriptor)

            for entry in oldEntries {
                for forecast in entry.forecastDays {
                    modelContext.delete(forecast)
                }
                modelContext.delete(entry)
            }
            try modelContext.save()
            logger.debug("Cleaned up \(oldEntries.count) old cache entries")
        } catch {
            logger.error("Failed to cleanup old cache: \(error)")
        }
    }
    
    func clearCache() async {
        cacheGeneration += 1
        recentWeather.removeAll()
        let descriptor = FetchDescriptor<WeatherData>()

        do {
            let allEntries = try modelContext.fetch(descriptor)
            for entry in allEntries {
                for forecast in entry.forecastDays {
                    modelContext.delete(forecast)
                }
                modelContext.delete(entry)
            }
            try modelContext.save()
            logger.info("Cleared all cached weather data")
        } catch {
            logger.error("Failed to clear cache: \(error)")
        }
    }
    
    // MARK: - Background Refresh

    func performFetch(for location: CLLocation, forceRefresh: Bool) async throws {
        _ = try await fetchWeatherData(for: location, forceRefresh: forceRefresh)
    }

    func handleBackgroundRefresh() async {
        logger.info("Handling background weather refresh")

        logger.debug("Fetching active reminders")
        let descriptor = FetchDescriptor<WeatherReminder>(
            predicate: #Predicate { reminder in
                reminder.isActive && !reminder.isCompleted && !reminder.isPaused && reminder.location?.id != nil
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
                        self.logger.debug("Background refresh successful for location: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private)")
                    } catch {
                        self.logger.warning("Background refresh failed for location: \(location.coordinate.latitude, privacy: .private), \(location.coordinate.longitude, privacy: .private), error: \(error)")
                    }
                }
            }
        }

        // Rescheduling the next refresh is BackgroundWeatherManager's job (the
        // sole caller of this method): it submits one BGAppRefreshTaskRequest
        // per task-identifier after this returns. A second reschedule here
        // used to race that one for the same identifier.
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
