//
//  WeatherError.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation

enum WeatherError: LocalizedError, Sendable {
    case invalidLocation
    case networkUnavailable
    case apiKeyMissing
    case apiKeyInvalid
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case quotaExceeded
    case serviceUnavailable(provider: WeatherProvider)
    case allProvidersFailed
    case invalidResponse
    case decodingError(Error)
    case locationPermissionDenied
    case cacheExpired
    case backgroundRefreshDisabled
    case unknown(Error)
    
    nonisolated var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return String(localized: "Invalid location provided", comment: "Weather error shown when a location cannot be used to fetch weather")
        case .networkUnavailable:
            return String(localized: "Network connection unavailable", comment: "Weather error shown when the device has no network connection")
        case .apiKeyMissing:
            return String(localized: "Weather API key not configured", comment: "Weather error shown when no API key is configured for the backup provider")
        case .apiKeyInvalid:
            return String(localized: "Weather API key is invalid", comment: "Weather error shown when the configured API key was rejected")
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return String(localized: "Rate limit exceeded. Try again in \(Int(retryAfter)) seconds", comment: "Weather error with a countdown before the next request is allowed")
            }
            return String(localized: "Rate limit exceeded. Please try again later", comment: "Weather error when no retry countdown is available")
        case .quotaExceeded:
            return String(localized: "API quota exceeded for this period", comment: "Weather error when the provider's usage quota has been used up")
        case .serviceUnavailable(let provider):
            return String(localized: "\(provider.displayName) service is temporarily unavailable", comment: "Weather error naming the specific provider (e.g. Apple WeatherKit) that is down")
        case .allProvidersFailed:
            return String(localized: "All weather services are currently unavailable", comment: "Weather error when every configured provider failed")
        case .invalidResponse:
            return String(localized: "Invalid response from weather service", comment: "Weather error when the provider's response could not be understood")
        case .decodingError:
            return String(localized: "Failed to parse weather data", comment: "Weather error when the provider's response could not be decoded")
        case .locationPermissionDenied:
            return String(localized: "Location permission is required for weather data", comment: "Weather error when location access has not been granted")
        case .cacheExpired:
            return String(localized: "Cached weather data has expired", comment: "Weather error when only stale cached data is available")
        case .backgroundRefreshDisabled:
            return String(localized: "Background refresh is disabled", comment: "Weather error when background updates are turned off")
        case .unknown(let error):
            return String(localized: "Unknown error: \(error.localizedDescription)", comment: "Weather error fallback wrapping an unexpected underlying error")
        }
    }

    var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "Check your internet connection and try again", comment: "Weather error failure reason")
        case .apiKeyMissing, .apiKeyInvalid:
            return String(localized: "Contact support to resolve API configuration", comment: "Weather error failure reason")
        case .rateLimitExceeded:
            return String(localized: "Too many requests made in a short period", comment: "Weather error failure reason")
        case .serviceUnavailable:
            return String(localized: "The weather service is experiencing temporary issues", comment: "Weather error failure reason")
        case .locationPermissionDenied:
            return String(localized: "Enable location services in Settings", comment: "Weather error failure reason")
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "Connect to Wi-Fi or cellular data and try again", comment: "Weather error recovery suggestion")
        case .rateLimitExceeded:
            return String(localized: "Wait a few minutes before making another request", comment: "Weather error recovery suggestion")
        case .allProvidersFailed:
            return String(localized: "Try again in a few minutes or check your internet connection", comment: "Weather error recovery suggestion")
        case .locationPermissionDenied:
            return String(localized: "Go to Settings > Privacy > Location Services and enable for this app", comment: "Weather error recovery suggestion; \">\" separates iOS Settings menu levels and should stay as-is")
        case .cacheExpired:
            return String(localized: "Pull to refresh to get updated weather data", comment: "Weather error recovery suggestion")
        default:
            return String(localized: "Try again later", comment: "Weather error generic recovery suggestion")
        }
    }
}

enum WeatherProvider: String, CaseIterable, Sendable {
    case appleWeatherKit = "apple_weather_kit"
    case openWeatherMap = "open_weather_map"
    
    nonisolated var displayName: String {
        switch self {
        case .appleWeatherKit:
            return String(localized: "Apple WeatherKit", comment: "Weather data provider name; 'WeatherKit' is an Apple product name and should not be translated")
        case .openWeatherMap:
            return String(localized: "OpenWeatherMap", comment: "Weather data provider name; product name, should not be translated")
        }
    }

    nonisolated var priority: Int {
        switch self {
        case .appleWeatherKit:
            return 0
        case .openWeatherMap:
            return 1
        }
    }
}

struct WeatherRequestMetadata: Sendable {
    let provider: WeatherProvider
    let requestTime: Date
    let responseTime: Date?
    let success: Bool
    let error: WeatherError?
    let cacheHit: Bool
    
    init(provider: WeatherProvider, requestTime: Date = Date(), responseTime: Date? = nil, success: Bool = false, error: WeatherError? = nil, cacheHit: Bool = false) {
        self.provider = provider
        self.requestTime = requestTime
        self.responseTime = responseTime
        self.success = success
        self.error = error
        self.cacheHit = cacheHit
    }
}
