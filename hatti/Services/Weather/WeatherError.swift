//
//  WeatherError.swift
//  hatti
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
    
    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Invalid location provided"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .apiKeyMissing:
            return "Weather API key not configured"
        case .apiKeyInvalid:
            return "Weather API key is invalid"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Try again in \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded. Please try again later"
        case .quotaExceeded:
            return "API quota exceeded for this period"
        case .serviceUnavailable(let provider):
            return "\(provider.displayName) service is temporarily unavailable"
        case .allProvidersFailed:
            return "All weather services are currently unavailable"
        case .invalidResponse:
            return "Invalid response from weather service"
        case .decodingError:
            return "Failed to parse weather data"
        case .locationPermissionDenied:
            return "Location permission is required for weather data"
        case .cacheExpired:
            return "Cached weather data has expired"
        case .backgroundRefreshDisabled:
            return "Background refresh is disabled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .apiKeyMissing, .apiKeyInvalid:
            return "Contact support to resolve API configuration"
        case .rateLimitExceeded:
            return "Too many requests made in a short period"
        case .serviceUnavailable:
            return "The weather service is experiencing temporary issues"
        case .locationPermissionDenied:
            return "Enable location services in Settings"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Connect to Wi-Fi or cellular data and try again"
        case .rateLimitExceeded:
            return "Wait a few minutes before making another request"
        case .allProvidersFailed:
            return "Try again in a few minutes or check your internet connection"
        case .locationPermissionDenied:
            return "Go to Settings > Privacy > Location Services and enable for this app"
        case .cacheExpired:
            return "Pull to refresh to get updated weather data"
        default:
            return "Try again later"
        }
    }
}

enum WeatherProvider: String, CaseIterable, Sendable {
    case appleWeatherKit = "apple_weather_kit"
    case openWeatherMap = "open_weather_map"
    
    var displayName: String {
        switch self {
        case .appleWeatherKit:
            return "Apple WeatherKit"
        case .openWeatherMap:
            return "OpenWeatherMap"
        }
    }
    
    var priority: Int {
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