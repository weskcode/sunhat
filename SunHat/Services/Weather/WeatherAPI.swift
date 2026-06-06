//
//  WeatherAPI.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import WeatherKit
import CoreLocation
import SwiftData

// Use DTOs for protocol and async boundaries
protocol WeatherAPI: Sendable {
    var provider: WeatherProvider { get }
    var isAvailable: Bool { get async }
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherDataDTO
    func fetchForecast(for location: CLLocation, days: Int) async throws -> [ForecastDayDTO]
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherDataDTO
}

// MARK: - Apple WeatherKit Implementation

@MainActor
final class AppleWeatherKitAPI: WeatherAPI {
    nonisolated let provider: WeatherProvider = .appleWeatherKit
    private let weatherService = WeatherKit.WeatherService.shared
    
    nonisolated var isAvailable: Bool {
        get async {
            // Check if WeatherKit is available (requires iOS 16+)
            // Since this is a system framework, it's always available on supported iOS versions
            return true
        }
    }
    
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherDataDTO {
        do {
            let weather = try await weatherService.weather(for: location)
            return mapCurrentWeather(weather.currentWeather, at: location)
        } catch {
            throw mapWeatherKitError(error)
        }
    }

    // MARK: - iOS 26+ WeatherKit Enhancements

    @available(iOS 26, *)
    func fetchExtendedWeatherData(for location: CLLocation) async throws -> WeatherDataDTO {
        let weather = try await weatherService.weather(for: location)

        // Use iOS 26+ WeatherKit features
        let currentWeather = weather.currentWeather

        // Enhanced mapping with iOS 26+ features
        return mapEnhancedCurrentWeather(currentWeather, at: location)
    }

    @available(iOS 26, *)
    private func mapEnhancedCurrentWeather(_ current: CurrentWeather, at location: CLLocation) -> WeatherDataDTO {
        // WeatherKit doesn't provide direct precipitation amount in CurrentWeather
        // We'll use the condition to infer precipitation type and set amount to 0
        let precipType = mapPrecipitationType(current.condition)

        // iOS 26+ enhanced data mapping
        return WeatherDataDTO(
            temperature: current.temperature.fahrenheitValue,
            feelsLike: current.apparentTemperature.fahrenheitValue,
            humidity: Int(current.humidity * 100),
            dewPoint: current.dewPoint.fahrenheitValue,
            pressure: current.pressure.value,
            visibility: current.visibility.milesValue,
            uvIndex: Double(current.uvIndex.value),
            cloudCover: Int(current.cloudCover * 100),
            windSpeed: current.wind.speed.milesPerHourValue,
            windDirection: Int(current.wind.direction.value),
            precipitationAmount: 0.0, // CurrentWeather doesn't provide precipitation amount
            precipitationType: precipType,
            weatherCondition: mapWeatherKitCondition(current.condition),
            dataSource: .appleWeatherKit,
            accuracy: .high,
            forecast: []
        )
    }
    
    func fetchForecast(for location: CLLocation, days: Int = 7) async throws -> [ForecastDayDTO] {
        do {
            let weather = try await weatherService.weather(for: location)
            return weather.dailyForecast.forecast.prefix(days).map { dailyWeather in
                mapDailyWeather(dailyWeather)
            }
        } catch {
            throw mapWeatherKitError(error)
        }
    }
    
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherDataDTO {
        do {
            let weather = try await weatherService.weather(for: location)
            let current = mapCurrentWeather(weather.currentWeather, at: location)
            let forecast = weather.dailyForecast.forecast.prefix(10).map { dailyWeather in
                mapDailyWeather(dailyWeather)
            }

            return WeatherDataDTO(
                temperature: current.temperature,
                feelsLike: current.feelsLike,
                humidity: current.humidity,
                dewPoint: current.dewPoint,
                pressure: current.pressure,
                visibility: current.visibility,
                uvIndex: current.uvIndex,
                cloudCover: current.cloudCover,
                windSpeed: current.windSpeed,
                windDirection: current.windDirection,
                precipitationAmount: current.precipitationAmount,
                precipitationType: current.precipitationType,
                weatherCondition: current.weatherCondition,
                dataSource: current.dataSource,
                accuracy: current.accuracy,
                forecast: forecast
            )
        } catch {
            throw mapWeatherKitError(error)
        }
    }
    
    private func mapCurrentWeather(_ current: CurrentWeather, at location: CLLocation) -> WeatherDataDTO {
        // WeatherKit doesn't provide direct precipitation amount in CurrentWeather
        // We'll use the condition to infer precipitation type and set amount to 0
        let precipType = mapPrecipitationType(current.condition)
        
        return WeatherDataDTO(
            temperature: current.temperature.fahrenheitValue,
            feelsLike: current.apparentTemperature.fahrenheitValue,
            humidity: Int(current.humidity * 100),
            dewPoint: current.dewPoint.fahrenheitValue,
            pressure: current.pressure.value,
            visibility: current.visibility.milesValue,
            uvIndex: Double(current.uvIndex.value),
            cloudCover: Int(current.cloudCover * 100),
            windSpeed: current.wind.speed.milesPerHourValue,
            windDirection: Int(current.wind.direction.value),
            precipitationAmount: 0.0, // CurrentWeather doesn't provide precipitation amount
            precipitationType: precipType,
            weatherCondition: mapWeatherKitCondition(current.condition),
            dataSource: .appleWeatherKit,
            accuracy: .high,
            forecast: []
        )
    }
    
    private func mapDailyWeather(_ daily: DayWeather) -> ForecastDayDTO {
        // For daily forecast, we can use precipitation chance and infer type from condition
        let precipType = mapPrecipitationType(daily.condition)
        
        return ForecastDayDTO(
            date: daily.date,
            highTemperature: daily.highTemperature.fahrenheitValue,
            lowTemperature: daily.lowTemperature.fahrenheitValue,
            weatherCondition: mapWeatherKitCondition(daily.condition),
            precipitationProbability: Int(daily.precipitationChance * 100),
            // Real total liquid-equivalent precipitation, in inches to match the app's
            // US-unit convention (and the 0.1" thresholds in WeatherData descriptions).
            precipitationAmount: daily.precipitationAmount.converted(to: .inches).value,
            precipitationType: precipType,
            windSpeed: daily.wind.speed.milesPerHourValue,
            windDirection: Int(daily.wind.direction.value),
            // NOTE: WeatherKit's DayWeather exposes no daily humidity or cloud-cover
            // aggregate. These are placeholders — forecast-based humidity/cloud triggers
            // should treat them as unknown. Proper fix (optional fields + averaging the
            // hourlyForecast) is tracked in IMPROVEMENT_PLAN.md §4.
            humidity: 50,
            uvIndex: Double(daily.uvIndex.value),
            cloudCover: 20
        )
    }
    
    private func mapWeatherKitCondition(_ condition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch condition {
        case .clear: return .clear
        case .cloudy: return .cloudy
        case .partlyCloudy: return .partlyCloudy
        case .mostlyCloudy: return .overcast
        case .drizzle: return .drizzle
        case .rain: return .rain
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms: return .thunderstorm
        case .snow, .flurries, .blizzard, .blowingSnow: return .snow
        case .sleet, .freezingRain, .freezingDrizzle: return .sleet
        case .hail: return .hail
        case .foggy, .smoky: return .fog
        case .breezy, .windy: return .windy
        case .frigid, .hot: return .clear
        case .hurricane: return .thunderstorm
        case .tropicalStorm: return .thunderstorm
        case .blowingDust: return .windy
        case .haze: return .fog
        case .heavyRain: return .rain
        case .heavySnow: return .snow
        case .mostlyClear: return .clear
        case .sunFlurries: return .snow
        case .sunShowers: return .rain
        case .wintryMix: return .sleet
        @unknown default: return .unknown
        }
    }
    
    private func mapWeatherKitError(_ error: Error) -> WeatherError {
        if let weatherError = error as? WeatherError {
            return weatherError
        }
        
        // Map specific WeatherKit errors
        let nsError = error as NSError
        switch nsError.code {
        case 1: return .locationPermissionDenied
        case 2: return .networkUnavailable
        case 3: return .serviceUnavailable(provider: .appleWeatherKit)
        default: return .unknown(error)
        }
    }
    
    private func mapPrecipitationType(_ condition: WeatherKit.WeatherCondition) -> PrecipitationType {
        switch condition {
        case .drizzle, .freezingDrizzle:
            return .rain  // Map drizzle to rain since PrecipitationType doesn't have drizzle
        case .rain, .freezingRain:
            return .rain
        case .snow, .blizzard, .blowingSnow, .flurries:
            return .snow
        case .sleet:
            return .sleet
        case .hail:
            return .hail
        case .clear, .cloudy, .mostlyCloudy, .partlyCloudy,
             .breezy, .windy, .frigid, .hot,
             .isolatedThunderstorms, .scatteredThunderstorms,
             .strongStorms, .thunderstorms,
             .foggy, .smoky, .hurricane, .tropicalStorm,
             .blowingDust, .haze, .heavyRain, .heavySnow,
             .mostlyClear, .sunFlurries, .sunShowers, .wintryMix:
            return .none
        @unknown default:
            return .none
        }
    }
}

// MARK: - OpenWeatherMap Implementation

final class OpenWeatherMapAPI: WeatherAPI {
    nonisolated let provider: WeatherProvider = .openWeatherMap
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    nonisolated init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    var isAvailable: Bool {
        get async {
            // Check if API key is available
            return !apiKey.isEmpty
        }
    }
    
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherDataDTO {
        let url = buildURL(endpoint: "weather", location: location)
        let response: OpenWeatherCurrentResponse = try await performRequest(url: url)
        return await mapCurrentWeatherResponse(response, at: location)
    }
    
    func fetchForecast(for location: CLLocation, days: Int = 7) async throws -> [ForecastDayDTO] {
        let url = buildURL(endpoint: "forecast", location: location)
        let response: OpenWeatherForecastResponse = try await performRequest(url: url)
        return await mapForecastResponse(response, days: days)
    }
    
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherDataDTO {
        async let currentTask = fetchCurrentWeather(for: location)
        async let forecastTask = fetchForecast(for: location)
        let (current, forecast) = try await (currentTask, forecastTask)
        var currentWithForecast = current
        currentWithForecast = WeatherDataDTO(
            temperature: current.temperature,
            feelsLike: current.feelsLike,
            humidity: current.humidity,
            dewPoint: current.dewPoint,
            pressure: current.pressure,
            visibility: current.visibility,
            uvIndex: current.uvIndex,
            cloudCover: current.cloudCover,
            windSpeed: current.windSpeed,
            windDirection: current.windDirection,
            precipitationAmount: current.precipitationAmount,
            precipitationType: current.precipitationType,
            weatherCondition: current.weatherCondition,
            dataSource: current.dataSource,
            accuracy: current.accuracy,
            forecast: forecast
        )
        return currentWithForecast
    }
    
    private func buildURL(endpoint: String, location: CLLocation) -> URL {
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial")
        ]
        
        if endpoint == "forecast" {
            components.queryItems?.append(URLQueryItem(name: "cnt", value: "40")) // 5-day forecast with 3-hour intervals
        }
        
        return components.url!
    }
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw WeatherError.apiKeyInvalid
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw WeatherError.rateLimitExceeded(retryAfter: retryAfter)
        case 500...599:
            throw WeatherError.serviceUnavailable(provider: .openWeatherMap)
        default:
            throw WeatherError.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WeatherError.decodingError(error)
        }
    }
    
    private func mapCurrentWeatherResponse(_ response: OpenWeatherCurrentResponse, at location: CLLocation) async -> WeatherDataDTO {
        return WeatherDataDTO(
            temperature: response.main.temp,
            feelsLike: response.main.feelsLike,
            humidity: response.main.humidity,
            dewPoint: 0.0, // Not available
            pressure: response.main.pressure,
            visibility: response.visibility / 1000.0,
            uvIndex: 0.0, // Not available
            cloudCover: response.clouds?.all ?? 0,
            windSpeed: response.wind?.speed ?? 0,
            windDirection: response.wind?.deg ?? 0,
            precipitationAmount: 0.0, // Not available
            precipitationType: .none,
            weatherCondition: mapOpenWeatherCondition(response.weather.first?.id ?? 800),
            dataSource: .openWeatherMap,
            accuracy: .medium,
            forecast: []
        )
    }
    
    private func mapForecastResponse(_ response: OpenWeatherForecastResponse, days: Int) async -> [ForecastDayDTO] {
        let calendar = Calendar.current
        var dailyForecasts: [Date: [OpenWeatherForecastItem]] = [:]
        for item in response.list {
            let date = Date(timeIntervalSince1970: TimeInterval(item.dt))
            let dayStart = calendar.startOfDay(for: date)
            dailyForecasts[dayStart, default: []].append(item)
        }
        return await withTaskGroup(of: ForecastDayDTO?.self) { group in
            var results: [ForecastDayDTO] = []
            for (date, items) in dailyForecasts.sorted(by: { $0.key < $1.key }).prefix(days) {
                group.addTask {
                    guard !items.isEmpty else { return nil }
                    let temps = items.map { $0.main.temp }
                    let highTemp = temps.max() ?? 0
                    let lowTemp = temps.min() ?? 0
                    let weatherItems = items.compactMap { $0.weather.first }
                    let weatherFrequency = Dictionary(grouping: weatherItems) { $0.id }
                    let mostCommonWeather = weatherFrequency.max { $0.value.count < $1.value.count }?.value.first
                    return ForecastDayDTO(
                        date: date,
                        highTemperature: highTemp,
                        lowTemperature: lowTemp,
                        weatherCondition: self.mapOpenWeatherCondition(mostCommonWeather?.id ?? 800),
                        precipitationProbability: 0,
                        precipitationAmount: 0.0,
                        precipitationType: .none,
                        windSpeed: items.map { $0.wind?.speed ?? 0 }.average(),
                        windDirection: items.first?.wind?.deg ?? 0,
                        humidity: Int(items.map { Double($0.main.humidity) }.average()),
                        uvIndex: 0.0,
                        cloudCover: Int(items.map { Double($0.clouds?.all ?? 0) }.average())
                    )
                }
            }
            for await result in group {
                if let forecast = result {
                    results.append(forecast)
                }
            }
            return results
        }
    }
    
    private nonisolated func mapOpenWeatherCondition(_ id: Int) -> WeatherCondition {
        switch id {
        case 200...232: return .thunderstorm
        case 300...321: return .drizzle
        case 500...504: return .rain
        case 511: return .sleet  // Map freezingRain to sleet
        case 520...531: return .rain
        case 600...622: return .snow
        case 701: return .fog  // Map mist to fog
        case 711: return .fog  // Map smoke to fog
        case 721: return .fog  // Map haze to fog
        case 731: return .windy  // Map dust to windy
        case 741: return .fog
        case 751: return .windy  // Map sand to windy
        case 761: return .windy  // Map dust to windy
        case 762: return .windy  // Map volcanic ash to windy
        case 771: return .windy  // Map squalls to windy
        case 781: return .thunderstorm  // Map tornado to thunderstorm
        case 800: return .clear
        case 801: return .partlyCloudy
        case 802: return .partlyCloudy
        case 803: return .cloudy
        case 804: return .overcast
        default: return .unknown
        }
    }
}

// MARK: - OpenWeatherMap Response Models

private struct OpenWeatherCurrentResponse: Codable, Sendable {
    let dt: Int
    let main: MainData
    let weather: [WeatherInfo]
    let wind: WindData?
    let clouds: CloudData?
    let visibility: Double
    
    struct MainData: Codable, Sendable {
        let temp: Double
        let feelsLike: Double
        let pressure: Double
        let humidity: Int
        
        nonisolated private enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case pressure
            case humidity
        }
    }
    
    struct WeatherInfo: Codable, Sendable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }
    
    struct WindData: Codable, Sendable {
        let speed: Double
        let deg: Int
    }
    
    struct CloudData: Codable, Sendable {
        let all: Int
    }
}



private struct OpenWeatherForecastResponse: Codable, Sendable {
    let list: [OpenWeatherForecastItem]
}

private struct OpenWeatherForecastItem: Codable, Sendable {
    let dt: Int
    let main: OpenWeatherCurrentResponse.MainData
    let weather: [OpenWeatherCurrentResponse.WeatherInfo]
    let wind: OpenWeatherCurrentResponse.WindData?
    let clouds: OpenWeatherCurrentResponse.CloudData?
}

// MARK: - Helper Extensions



private extension Array where Element == Double {
    nonisolated func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private extension Measurement where UnitType == UnitTemperature {
    var fahrenheitValue: Double {
        converted(to: .fahrenheit).value
    }
}

private extension Measurement where UnitType == UnitLength {
    var milesValue: Double {
        converted(to: .miles).value
    }
}

private extension Measurement where UnitType == UnitSpeed {
    var milesPerHourValue: Double {
        converted(to: .milesPerHour).value
    }
}

// MARK: - Data Transfer Objects

struct WeatherDataDTO: Sendable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let dewPoint: Double
    let pressure: Double
    let visibility: Double
    let uvIndex: Double
    let cloudCover: Int
    let windSpeed: Double
    let windDirection: Int
    let precipitationAmount: Double
    let precipitationType: PrecipitationType
    let weatherCondition: WeatherCondition
    let dataSource: WeatherDataSource
    let accuracy: WeatherAccuracy
    let forecast: [ForecastDayDTO]
    
    func toWeatherData() -> WeatherData {
        let weather = WeatherData(
            temperature: temperature,
            feelsLike: feelsLike,
            humidity: humidity
        )
        weather.dewPoint = dewPoint
        weather.pressure = pressure
        weather.visibility = visibility
        weather.uvIndex = uvIndex
        weather.cloudCover = cloudCover
        weather.windSpeed = windSpeed
        weather.windDirection = windDirection
        weather.precipitationAmount = precipitationAmount
        weather.precipitationType = precipitationType
        weather.weatherCondition = weatherCondition
        weather.dataSource = dataSource
        weather.accuracy = accuracy
        weather.forecastDays = forecast.map { $0.toForecastDay() }
        return weather
    }
}

struct ForecastDayDTO: Sendable {
    let date: Date
    let highTemperature: Double
    let lowTemperature: Double
    let weatherCondition: WeatherCondition
    let precipitationProbability: Int
    let precipitationAmount: Double
    let precipitationType: PrecipitationType
    let windSpeed: Double
    let windDirection: Int
    let humidity: Int
    let uvIndex: Double
    let cloudCover: Int
    
    func toForecastDay() -> ForecastDay {
        let forecast = ForecastDay(
            date: date,
            highTemperature: highTemperature,
            lowTemperature: lowTemperature
        )
        forecast.precipitationProbability = precipitationProbability
        forecast.precipitationAmount = precipitationAmount
        forecast.precipitationType = precipitationType
        forecast.windSpeed = windSpeed
        forecast.windDirection = windDirection
        forecast.humidity = humidity
        forecast.uvIndex = uvIndex
        forecast.cloudCover = cloudCover
        forecast.weatherCondition = weatherCondition
        return forecast
    }
}
