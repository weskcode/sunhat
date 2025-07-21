//
//  WeatherAPI.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import WeatherKit
import CoreLocation

protocol WeatherAPI: Sendable {
    var provider: WeatherProvider { get }
    var isAvailable: Bool { get async }
    
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherData
    func fetchForecast(for location: CLLocation, days: Int) async throws -> [ForecastDay]
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherData
}

// MARK: - Apple WeatherKit Implementation

@MainActor
class AppleWeatherKitAPI: WeatherAPI {
    let provider: WeatherProvider = .appleWeatherKit
    private let weatherService = WeatherService.shared
    
    var isAvailable: Bool {
        get async {
            // Check if WeatherKit is available in current region
            do {
                let _ = try await weatherService.attribution
                return true
            } catch {
                return false
            }
        }
    }
    
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherData {
        do {
            let weather = try await weatherService.weather(for: location)
            return try mapCurrentWeather(weather.currentWeather, at: location)
        } catch {
            throw mapWeatherKitError(error)
        }
    }
    
    func fetchForecast(for location: CLLocation, days: Int = 7) async throws -> [ForecastDay] {
        do {
            let forecast = try await weatherService.weather(
                for: location,
                including: .daily(startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date())
            )
            
            return forecast.prefix(days).compactMap { dailyWeather in
                try? mapDailyWeather(dailyWeather)
            }
        } catch {
            throw mapWeatherKitError(error)
        }
    }
    
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherData {
        do {
            let weather = try await weatherService.weather(for: location)
            let weatherData = try mapCurrentWeather(weather.currentWeather, at: location)
            
            // Add forecast data
            let forecast = try await weatherService.weather(
                for: location,
                including: .daily(startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
            )
            
            let forecastDays = forecast.prefix(7).compactMap { dailyWeather in
                try? mapDailyWeather(dailyWeather)
            }
            
            weatherData.forecastDays = forecastDays
            return weatherData
        } catch {
            throw mapWeatherKitError(error)
        }
    }
    
    private func mapCurrentWeather(_ current: CurrentWeather, at location: CLLocation) throws -> WeatherData {
        let weatherData = WeatherData(
            temperature: current.temperature.value,
            feelsLike: current.apparentTemperature.value,
            humidity: Int(current.humidity * 100)
        )
        
        weatherData.dewPoint = current.dewPoint.value
        weatherData.pressure = current.pressure.value
        weatherData.visibility = current.visibility.value
        weatherData.uvIndex = current.uvIndex.value
        weatherData.windSpeed = current.wind.speed.value
        weatherData.windDirection = Int(current.wind.direction?.value ?? 0)
        weatherData.cloudCover = Int(current.cloudCover * 100)
        
        // Map weather condition
        weatherData.weatherCondition = mapWeatherKitCondition(current.condition)
        weatherData.weatherDescription = current.condition.description
        weatherData.iconName = current.symbolName
        
        // Precipitation
        if let precipitation = current.precipitationIntensity?.value {
            weatherData.precipitationAmount = precipitation
        }
        
        weatherData.dataSource = .appleWeatherKit
        weatherData.accuracy = .high
        weatherData.observationTime = current.date
        
        return weatherData
    }
    
    private func mapDailyWeather(_ daily: DayWeather) throws -> ForecastDay {
        let forecastDay = ForecastDay(
            date: daily.date,
            highTemperature: daily.highTemperature.value,
            lowTemperature: daily.lowTemperature.value,
            weatherCondition: mapWeatherKitCondition(daily.condition)
        )
        
        forecastDay.weatherDescription = daily.condition.description
        forecastDay.iconName = daily.symbolName
        forecastDay.windSpeed = daily.wind.speed.value
        forecastDay.windDirection = Int(daily.wind.direction?.value ?? 0)
        forecastDay.humidity = Int((daily.lowTemperature.value + daily.highTemperature.value) / 2) // Approximation
        forecastDay.uvIndex = daily.uvIndex.value
        forecastDay.cloudCover = Int(daily.cloudCover * 100)
        forecastDay.confidence = .high
        
        if let precipitationChance = daily.precipitationChance {
            forecastDay.precipitationProbability = Int(precipitationChance * 100)
        }
        
        if let precipitationAmount = daily.precipitationAmount?.value {
            forecastDay.precipitationAmount = precipitationAmount
        }
        
        return forecastDay
    }
    
    private func mapWeatherKitCondition(_ condition: WeatherKit.WeatherCondition) -> hatti.WeatherCondition {
        switch condition {
        case .clear: return .clear
        case .cloudy: return .cloudy
        case .partlyCloudy: return .partlyCloudy
        case .mostlyCloudy: return .overcast
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
}

// MARK: - OpenWeatherMap Implementation

actor OpenWeatherMapAPI: WeatherAPI {
    let provider: WeatherProvider = .openWeatherMap
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    var isAvailable: Bool {
        get async {
            !apiKey.isEmpty
        }
    }
    
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherData {
        let url = buildURL(endpoint: "weather", location: location)
        let response: OpenWeatherCurrentResponse = try await performRequest(url: url)
        return mapCurrentWeatherResponse(response, at: location)
    }
    
    func fetchForecast(for location: CLLocation, days: Int = 7) async throws -> [ForecastDay] {
        let url = buildURL(endpoint: "forecast", location: location)
        let response: OpenWeatherForecastResponse = try await performRequest(url: url)
        return mapForecastResponse(response, days: days)
    }
    
    func fetchWeatherData(for location: CLLocation) async throws -> WeatherData {
        async let currentTask = fetchCurrentWeather(for: location)
        async let forecastTask = fetchForecast(for: location)
        
        let (current, forecast) = try await (currentTask, forecastTask)
        current.forecastDays = forecast
        return current
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
    
    private func mapCurrentWeatherResponse(_ response: OpenWeatherCurrentResponse, at location: CLLocation) -> WeatherData {
        let weatherData = WeatherData(
            temperature: response.main.temp,
            feelsLike: response.main.feelsLike,
            humidity: response.main.humidity
        )
        
        weatherData.pressure = response.main.pressure
        weatherData.visibility = response.visibility / 1000.0 // Convert to km
        weatherData.windSpeed = response.wind?.speed ?? 0
        weatherData.windDirection = response.wind?.deg ?? 0
        weatherData.cloudCover = response.clouds?.all ?? 0
        
        // Map weather condition
        if let weather = response.weather.first {
            weatherData.weatherCondition = mapOpenWeatherCondition(weather.id)
            weatherData.weatherDescription = weather.description
            weatherData.iconName = weather.icon
        }
        
        weatherData.dataSource = .openWeatherMap
        weatherData.accuracy = .medium
        weatherData.observationTime = Date(timeIntervalSince1970: TimeInterval(response.dt))
        
        return weatherData
    }
    
    private func mapForecastResponse(_ response: OpenWeatherForecastResponse, days: Int) -> [ForecastDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var dailyForecasts: [Date: [OpenWeatherForecastItem]] = [:]
        
        // Group forecast items by day
        for item in response.list {
            let date = Date(timeIntervalSince1970: TimeInterval(item.dt))
            let dayStart = calendar.startOfDay(for: date)
            dailyForecasts[dayStart, default: []].append(item)
        }
        
        return dailyForecasts
            .sorted { $0.key < $1.key }
            .prefix(days)
            .compactMap { (date, items) in
                guard !items.isEmpty else { return nil }
                
                let temps = items.map { $0.main.temp }
                let highTemp = temps.max() ?? 0
                let lowTemp = temps.min() ?? 0
                
                let forecastDay = ForecastDay(
                    date: date,
                    highTemperature: highTemp,
                    lowTemperature: lowTemp
                )
                
                // Use the most common weather condition for the day
                if let mostCommonWeather = items.compactMap({ $0.weather.first }).mostFrequent() {
                    forecastDay.weatherCondition = mapOpenWeatherCondition(mostCommonWeather.id)
                    forecastDay.weatherDescription = mostCommonWeather.description
                    forecastDay.iconName = mostCommonWeather.icon
                }
                
                // Average other values
                forecastDay.windSpeed = items.map { $0.wind?.speed ?? 0 }.average()
                forecastDay.humidity = Int(items.map { Double($0.main.humidity) }.average())
                forecastDay.cloudCover = Int(items.map { Double($0.clouds?.all ?? 0) }.average())
                forecastDay.confidence = .medium
                
                return forecastDay
            }
    }
    
    private func mapOpenWeatherCondition(_ id: Int) -> hatti.WeatherCondition {
        switch id {
        case 200...232: return .thunderstorm
        case 300...321: return .drizzle
        case 500...504: return .rain
        case 511: return .freezingRain
        case 520...531: return .rain
        case 600...622: return .snow
        case 701: return .mist
        case 711: return .smoke
        case 721: return .mist
        case 731: return .dust
        case 741: return .fog
        case 751: return .dust
        case 761: return .dust
        case 762: return .dust
        case 771: return .unknown
        case 781: return .tornado
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

private struct OpenWeatherCurrentResponse: Codable {
    let dt: Int
    let main: MainData
    let weather: [WeatherInfo]
    let wind: WindData?
    let clouds: CloudData?
    let visibility: Double
    
    struct MainData: Codable {
        let temp: Double
        let feelsLike: Double
        let pressure: Double
        let humidity: Int
        
        private enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case pressure
            case humidity
        }
    }
    
    struct WeatherInfo: Codable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }
    
    struct WindData: Codable {
        let speed: Double
        let deg: Int
    }
    
    struct CloudData: Codable {
        let all: Int
    }
}

private struct OpenWeatherForecastResponse: Codable {
    let list: [OpenWeatherForecastItem]
}

private struct OpenWeatherForecastItem: Codable {
    let dt: Int
    let main: OpenWeatherCurrentResponse.MainData
    let weather: [OpenWeatherCurrentResponse.WeatherInfo]
    let wind: OpenWeatherCurrentResponse.WindData?
    let clouds: OpenWeatherCurrentResponse.CloudData?
}

// MARK: - Helper Extensions

private extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = Dictionary(grouping: self) { $0 }.mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }
}

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}