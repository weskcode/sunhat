//
//  WeatherServiceConfiguration.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import Combine
import os

struct WeatherServiceConfiguration: Sendable {
    let openWeatherMapAPIKey: String?
    let cacheExpirationMinutes: Int
    let backgroundRefreshIntervalMinutes: Int
    let rateLimitRequestsPerMinute: Int
    let rateLimitRequestsPerHour: Int
    let enabledProviders: Set<WeatherProvider>
    let preferredProvider: WeatherProvider
    let enableBackgroundRefresh: Bool
    let enableNotifications: Bool
    
    static let `default` = WeatherServiceConfiguration(
        openWeatherMapAPIKey: nil,
        cacheExpirationMinutes: 15,
        backgroundRefreshIntervalMinutes: 15,
        rateLimitRequestsPerMinute: 60,
        rateLimitRequestsPerHour: 1000,
        enabledProviders: [.appleWeatherKit, .openWeatherMap],
        preferredProvider: .appleWeatherKit,
        enableBackgroundRefresh: true,
        enableNotifications: true
    )
    
    init(
        openWeatherMapAPIKey: String? = nil,
        cacheExpirationMinutes: Int = 15,
        backgroundRefreshIntervalMinutes: Int = 15,
        rateLimitRequestsPerMinute: Int = 60,
        rateLimitRequestsPerHour: Int = 1000,
        enabledProviders: Set<WeatherProvider> = [.appleWeatherKit, .openWeatherMap],
        preferredProvider: WeatherProvider = .appleWeatherKit,
        enableBackgroundRefresh: Bool = true,
        enableNotifications: Bool = true
    ) {
        self.openWeatherMapAPIKey = openWeatherMapAPIKey
        self.cacheExpirationMinutes = cacheExpirationMinutes
        self.backgroundRefreshIntervalMinutes = backgroundRefreshIntervalMinutes
        self.rateLimitRequestsPerMinute = rateLimitRequestsPerMinute
        self.rateLimitRequestsPerHour = rateLimitRequestsPerHour
        self.enabledProviders = enabledProviders
        self.preferredProvider = preferredProvider
        self.enableBackgroundRefresh = enableBackgroundRefresh
        self.enableNotifications = enableNotifications
    }
}

@MainActor
final class WeatherServiceManager: ObservableObject {
    static let shared = WeatherServiceManager()
    
    @Published var configuration: WeatherServiceConfiguration = .default
    @Published var isConfigured = false
    @Published var configurationError: WeatherError?
    
    private let logger = Logger(subsystem: "com.hatti.app", category: "WeatherServiceManager")
    private let configurationKey = "weather_service_configuration"
    
    private init() {
        loadConfiguration()
    }
    
    func configure(with newConfiguration: WeatherServiceConfiguration, modelContext: ModelContext) async {
        configuration = newConfiguration
        saveConfiguration()
        
        do {
            await WeatherService.shared.configure(
                modelContext: modelContext,
                openWeatherMapKey: newConfiguration.openWeatherMapAPIKey
            )
            
            if newConfiguration.enableBackgroundRefresh {
                let permissionGranted = await BackgroundWeatherManager.shared.requestBackgroundRefreshPermission()
                if !permissionGranted {
                    logger.warning("Background refresh permission not granted")
                }
            }
            
            isConfigured = true
            configurationError = nil
            
            logger.info("Weather service configured successfully")
            
        } catch {
            configurationError = WeatherError.unknown(error)
            logger.error("Failed to configure weather service: \(error)")
        }
    }
    
    func updateAPIKey(_ apiKey: String) async {
        let newConfiguration = WeatherServiceConfiguration(
            openWeatherMapAPIKey: apiKey,
            cacheExpirationMinutes: configuration.cacheExpirationMinutes,
            backgroundRefreshIntervalMinutes: configuration.backgroundRefreshIntervalMinutes,
            rateLimitRequestsPerMinute: configuration.rateLimitRequestsPerMinute,
            rateLimitRequestsPerHour: configuration.rateLimitRequestsPerHour,
            enabledProviders: configuration.enabledProviders,
            preferredProvider: configuration.preferredProvider,
            enableBackgroundRefresh: configuration.enableBackgroundRefresh,
            enableNotifications: configuration.enableNotifications
        )
        
        configuration = newConfiguration
        saveConfiguration()
        
        logger.info("Updated OpenWeatherMap API key")
    }
    
    func toggleProvider(_ provider: WeatherProvider, enabled: Bool) {
        var newEnabledProviders = configuration.enabledProviders
        
        if enabled {
            newEnabledProviders.insert(provider)
        } else {
            newEnabledProviders.remove(provider)
        }
        
        let newConfiguration = WeatherServiceConfiguration(
            openWeatherMapAPIKey: configuration.openWeatherMapAPIKey,
            cacheExpirationMinutes: configuration.cacheExpirationMinutes,
            backgroundRefreshIntervalMinutes: configuration.backgroundRefreshIntervalMinutes,
            rateLimitRequestsPerMinute: configuration.rateLimitRequestsPerMinute,
            rateLimitRequestsPerHour: configuration.rateLimitRequestsPerHour,
            enabledProviders: newEnabledProviders,
            preferredProvider: configuration.preferredProvider,
            enableBackgroundRefresh: configuration.enableBackgroundRefresh,
            enableNotifications: configuration.enableNotifications
        )
        
        configuration = newConfiguration
        saveConfiguration()
        
        logger.info("Toggled provider \(provider.displayName): \(enabled ? "enabled" : "disabled")")
    }
    
    func setPreferredProvider(_ provider: WeatherProvider) {
        let newConfiguration = WeatherServiceConfiguration(
            openWeatherMapAPIKey: configuration.openWeatherMapAPIKey,
            cacheExpirationMinutes: configuration.cacheExpirationMinutes,
            backgroundRefreshIntervalMinutes: configuration.backgroundRefreshIntervalMinutes,
            rateLimitRequestsPerMinute: configuration.rateLimitRequestsPerMinute,
            rateLimitRequestsPerHour: configuration.rateLimitRequestsPerHour,
            enabledProviders: configuration.enabledProviders,
            preferredProvider: provider,
            enableBackgroundRefresh: configuration.enableBackgroundRefresh,
            enableNotifications: configuration.enableNotifications
        )
        
        configuration = newConfiguration
        saveConfiguration()
        
        logger.info("Set preferred provider to: \(provider.displayName)")
    }
    
    func toggleBackgroundRefresh(_ enabled: Bool) async {
        let newConfiguration = WeatherServiceConfiguration(
            openWeatherMapAPIKey: configuration.openWeatherMapAPIKey,
            cacheExpirationMinutes: configuration.cacheExpirationMinutes,
            backgroundRefreshIntervalMinutes: configuration.backgroundRefreshIntervalMinutes,
            rateLimitRequestsPerMinute: configuration.rateLimitRequestsPerMinute,
            rateLimitRequestsPerHour: configuration.rateLimitRequestsPerHour,
            enabledProviders: configuration.enabledProviders,
            preferredProvider: configuration.preferredProvider,
            enableBackgroundRefresh: enabled,
            enableNotifications: configuration.enableNotifications
        )
        
        configuration = newConfiguration
        saveConfiguration()
        
        if enabled {
            let _ = await BackgroundWeatherManager.shared.requestBackgroundRefreshPermission()
        } else {
            BackgroundWeatherManager.shared.cancelScheduledRefresh()
        }
        
        logger.info("Background refresh: \(enabled ? "enabled" : "disabled")")
    }
    
    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(ConfigurationData(from: configuration))
            UserDefaults.standard.set(data, forKey: configurationKey)
            logger.debug("Saved weather service configuration")
        } catch {
            logger.error("Failed to save configuration: \(error)")
        }
    }
    
    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configurationKey) else {
            logger.debug("No saved configuration found, using defaults")
            return
        }
        
        do {
            let configData = try JSONDecoder().decode(ConfigurationData.self, from: data)
            configuration = configData.toConfiguration()
            isConfigured = true
            logger.debug("Loaded weather service configuration")
        } catch {
            logger.error("Failed to load configuration: \(error)")
            configuration = .default
        }
    }
    
    func validateConfiguration() -> [WeatherError] {
        var errors: [WeatherError] = []
        
        if configuration.enabledProviders.isEmpty {
            errors.append(.serviceUnavailable(provider: .appleWeatherKit))
        }
        
        if configuration.enabledProviders.contains(.openWeatherMap) {
            if configuration.openWeatherMapAPIKey?.isEmpty ?? true {
                errors.append(.apiKeyMissing)
            }
        }
        
        if configuration.cacheExpirationMinutes < 1 {
            errors.append(.invalidResponse)
        }
        
        return errors
    }
    
    var hasValidOpenWeatherMapKey: Bool {
        guard let key = configuration.openWeatherMapAPIKey else { return false }
        return !key.isEmpty && key.count > 10
    }
    
    var canUseAppleWeatherKit: Bool {
        return configuration.enabledProviders.contains(.appleWeatherKit)
    }
    
    var canUseOpenWeatherMap: Bool {
        return configuration.enabledProviders.contains(.openWeatherMap) && hasValidOpenWeatherMapKey
    }
}

// MARK: - Configuration Data Model

private struct ConfigurationData: Codable {
    let openWeatherMapAPIKey: String?
    let cacheExpirationMinutes: Int
    let backgroundRefreshIntervalMinutes: Int
    let rateLimitRequestsPerMinute: Int
    let rateLimitRequestsPerHour: Int
    let enabledProviders: [String]
    let preferredProvider: String
    let enableBackgroundRefresh: Bool
    let enableNotifications: Bool
    
    init(from configuration: WeatherServiceConfiguration) {
        self.openWeatherMapAPIKey = configuration.openWeatherMapAPIKey
        self.cacheExpirationMinutes = configuration.cacheExpirationMinutes
        self.backgroundRefreshIntervalMinutes = configuration.backgroundRefreshIntervalMinutes
        self.rateLimitRequestsPerMinute = configuration.rateLimitRequestsPerMinute
        self.rateLimitRequestsPerHour = configuration.rateLimitRequestsPerHour
        self.enabledProviders = configuration.enabledProviders.map { $0.rawValue }
        self.preferredProvider = configuration.preferredProvider.rawValue
        self.enableBackgroundRefresh = configuration.enableBackgroundRefresh
        self.enableNotifications = configuration.enableNotifications
    }
    
    func toConfiguration() -> WeatherServiceConfiguration {
        let enabledProvidersSet = Set(enabledProviders.compactMap { WeatherProvider(rawValue: $0) })
        let preferred = WeatherProvider(rawValue: preferredProvider) ?? .appleWeatherKit
        
        return WeatherServiceConfiguration(
            openWeatherMapAPIKey: openWeatherMapAPIKey,
            cacheExpirationMinutes: cacheExpirationMinutes,
            backgroundRefreshIntervalMinutes: backgroundRefreshIntervalMinutes,
            rateLimitRequestsPerMinute: rateLimitRequestsPerMinute,
            rateLimitRequestsPerHour: rateLimitRequestsPerHour,
            enabledProviders: enabledProvidersSet,
            preferredProvider: preferred,
            enableBackgroundRefresh: enableBackgroundRefresh,
            enableNotifications: enableNotifications
        )
    }
}

// MARK: - Environment Setup Extension

extension WeatherServiceManager {
    func setupForDevelopment() async {
        // Load API key from environment or configuration file
        let configuration = WeatherServiceConfiguration(
            openWeatherMapAPIKey: getOpenWeatherMapAPIKey(),
            enableBackgroundRefresh: true,
            enableNotifications: true
        )
        
        // Configure with a temporary model context for development
        if let modelContext = createDevelopmentModelContext() {
            await configure(with: configuration, modelContext: modelContext)
        }
    }
    
    private func getOpenWeatherMapAPIKey() -> String? {
        // Try to load from bundle plist file
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let apiKey = dict["OpenWeatherMapAPIKey"] as? String {
            return apiKey
        }
        
        // Try environment variable for development
        return ProcessInfo.processInfo.environment["OPENWEATHERMAP_API_KEY"]
    }
    
    private func createDevelopmentModelContext() -> ModelContext? {
        do {
            let schema = Schema([
                WeatherReminder.self,
                TriggerCondition.self,
                LocationData.self,
                WeatherData.self,
                ForecastDay.self,
                NotificationConfig.self,
                ReminderHistory.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return ModelContext(container)
            
        } catch {
            logger.error("Failed to create development model context: \(error)")
            return nil
        }
    }
}
