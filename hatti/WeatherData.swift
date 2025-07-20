//
//  WeatherData.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData

@Model
final class WeatherData {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Timestamp and validity
    var timestamp: Date = Date()
    var observationTime: Date = Date()
    var isValid: Bool = true
    var expiresAt: Date?
    
    // Current temperature data
    var temperature: Double = 0.0
    var feelsLike: Double = 0.0
    var dewPoint: Double = 0.0
    var heatIndex: Double?
    var windChill: Double?
    
    // Atmospheric conditions
    var humidity: Int = 0
    var pressure: Double = 0.0
    var visibility: Double = 0.0
    var uvIndex: Double = 0.0
    var cloudCover: Int = 0
    
    // Wind data
    var windSpeed: Double = 0.0
    var windDirection: Int = 0
    var windGust: Double?
    
    // Precipitation
    var precipitationAmount: Double = 0.0
    var precipitationProbability: Int = 0
    var precipitationType: PrecipitationType = .none
    var snowDepth: Double?
    
    // Weather description
    var weatherCondition: WeatherCondition = .clear
    var weatherDescription: String = ""
    var iconName: String = ""
    
    // Air quality (optional)
    var airQualityIndex: Int?
    var pm25: Double?
    var ozone: Double?
    var pollenCount: Int?
    
    // Sun data
    var sunrise: Date?
    var sunset: Date?
    var dayLength: TimeInterval?
    
    // Data source metadata
    var dataSource: WeatherDataSource = .unknown
    var accuracy: WeatherAccuracy = .medium
    var lastUpdated: Date = Date()
    
    // CloudKit optimization
    @Attribute(.externalStorage) var rawWeatherData: Data?
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \LocationData.weatherData)
    var location: LocationData?
    
    @Relationship(deleteRule: .cascade, inverse: \WeatherData.parentWeatherData)
    var forecastDays: [ForecastDay] = []
    
    @Relationship(deleteRule: .nullify, inverse: \ForecastDay.parentWeatherData)
    var parentWeatherData: WeatherData?
    
    init(
        temperature: Double,
        feelsLike: Double,
        humidity: Int,
        location: LocationData? = nil
    ) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.location = location
        self.expiresAt = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
    }
}

@Model
final class ForecastDay {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Date for this forecast
    var date: Date = Date()
    var dayOfWeek: String = ""
    
    // Temperature range
    var highTemperature: Double = 0.0
    var lowTemperature: Double = 0.0
    var averageTemperature: Double = 0.0
    
    // Conditions
    var weatherCondition: WeatherCondition = .clear
    var weatherDescription: String = ""
    var iconName: String = ""
    
    // Precipitation
    var precipitationProbability: Int = 0
    var precipitationAmount: Double = 0.0
    var precipitationType: PrecipitationType = .none
    
    // Wind
    var windSpeed: Double = 0.0
    var windDirection: Int = 0
    
    // Other conditions
    var humidity: Int = 0
    var uvIndex: Double = 0.0
    var cloudCover: Int = 0
    
    // Confidence and accuracy
    var confidence: ForecastConfidence = .medium
    var lastUpdated: Date = Date()
    
    // Relationship
    @Relationship(deleteRule: .nullify, inverse: \WeatherData.forecastDays)
    var parentWeatherData: WeatherData?
    
    init(
        date: Date,
        highTemperature: Double,
        lowTemperature: Double,
        weatherCondition: WeatherCondition = .clear
    ) {
        self.date = date
        self.highTemperature = highTemperature
        self.lowTemperature = lowTemperature
        self.averageTemperature = (highTemperature + lowTemperature) / 2
        self.weatherCondition = weatherCondition
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        self.dayOfWeek = formatter.string(from: date)
    }
}

enum WeatherCondition: String, Codable, CaseIterable {
    case clear = "clear"
    case partlyCloudy = "partly_cloudy"
    case cloudy = "cloudy"
    case overcast = "overcast"
    case mist = "mist"
    case fog = "fog"
    case drizzle = "drizzle"
    case lightRain = "light_rain"
    case rain = "rain"
    case heavyRain = "heavy_rain"
    case thunderstorm = "thunderstorm"
    case lightSnow = "light_snow"
    case snow = "snow"
    case heavySnow = "heavy_snow"
    case sleet = "sleet"
    case hail = "hail"
    case blizzard = "blizzard"
    case freezingRain = "freezing_rain"
    case tornado = "tornado"
    case hurricane = "hurricane"
    case dust = "dust"
    case smoke = "smoke"
    case unknown = "unknown"
}

enum PrecipitationType: String, Codable, CaseIterable {
    case none = "none"
    case rain = "rain"
    case snow = "snow"
    case sleet = "sleet"
    case hail = "hail"
    case freezingRain = "freezing_rain"
    case mixed = "mixed"
}

enum WeatherDataSource: String, Codable, CaseIterable {
    case appleWeatherKit = "apple_weather_kit"
    case openWeatherMap = "open_weather_map"
    case weatherUnderground = "weather_underground"
    case nationalWeatherService = "national_weather_service"
    case personalWeatherStation = "personal_weather_station"
    case unknown = "unknown"
}

enum WeatherAccuracy: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
}

enum ForecastConfidence: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

extension WeatherData {
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var apparentTemperature: Double {
        if let windChill = windChill, temperature < 50 {
            return windChill
        } else if let heatIndex = heatIndex, temperature > 80 {
            return heatIndex
        } else {
            return feelsLike
        }
    }
    
    var windDirectionCardinal: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(windDirection) + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    var isFreezingTemperature: Bool {
        return temperature <= 32.0
    }
    
    var precipitationDescription: String {
        switch precipitationType {
        case .none:
            return "No precipitation"
        case .rain:
            return precipitationAmount > 0.1 ? "Rain" : "Light rain"
        case .snow:
            return precipitationAmount > 0.1 ? "Snow" : "Light snow"
        case .sleet:
            return "Sleet"
        case .hail:
            return "Hail"
        case .freezingRain:
            return "Freezing rain"
        case .mixed:
            return "Mixed precipitation"
        }
    }
    
    func evaluateCondition(_ triggerCondition: TriggerCondition) -> Bool {
        switch triggerCondition.triggerType {
        case .exactTemperature:
            let targetTemp = triggerCondition.useFeelsLike ? feelsLike : temperature
            let tolerance = triggerCondition.temperatureTolerance
            return abs(targetTemp - triggerCondition.targetTemperature) <= tolerance
            
        case .temperatureRange:
            let checkTemp = triggerCondition.useFeelsLike ? feelsLike : temperature
            if let min = triggerCondition.minTemperature, let max = triggerCondition.maxTemperature {
                return checkTemp >= min && checkTemp <= max
            }
            return false
            
        case .composite:
            var conditionsMet = true
            
            // Temperature check
            let tempCheck = evaluateTemperatureCondition(triggerCondition)
            conditionsMet = conditionsMet && tempCheck
            
            // Humidity check
            if triggerCondition.requiresHumidity {
                if let targetHumidity = triggerCondition.targetHumidity {
                    let humidityDiff = abs(Double(humidity) - targetHumidity)
                    conditionsMet = conditionsMet && (humidityDiff <= triggerCondition.humidityTolerance)
                }
            }
            
            // Wind speed check
            if triggerCondition.requiresWindSpeed {
                if let maxWind = triggerCondition.maxWindSpeed {
                    conditionsMet = conditionsMet && (windSpeed <= maxWind)
                }
            }
            
            // Precipitation check
            if triggerCondition.requiresPrecipitation {
                let precipConditionMet = evaluatePrecipitationCondition(triggerCondition.precipitationRequirement)
                conditionsMet = conditionsMet && precipConditionMet
            }
            
            return conditionsMet
            
        default:
            return evaluateTemperatureCondition(triggerCondition)
        }
    }
    
    private func evaluateTemperatureCondition(_ condition: TriggerCondition) -> Bool {
        let checkTemp = condition.useFeelsLike ? feelsLike : temperature
        
        switch condition.comparisonType {
        case .above:
            return checkTemp > condition.targetTemperature
        case .below:
            return checkTemp < condition.targetTemperature
        case .equals:
            return abs(checkTemp - condition.targetTemperature) <= condition.temperatureTolerance
        case .between:
            if let min = condition.minTemperature, let max = condition.maxTemperature {
                return checkTemp >= min && checkTemp <= max
            }
            return false
        }
    }
    
    private func evaluatePrecipitationCondition(_ requirement: PrecipitationRequirement) -> Bool {
        switch requirement {
        case .none:
            return true
        case .dry:
            return precipitationAmount == 0 && precipitationType == .none
        case .anyPrecipitation:
            return precipitationAmount > 0 || precipitationType != .none
        case .rain:
            return precipitationType == .rain && precipitationAmount > 0
        case .snow:
            return precipitationType == .snow && precipitationAmount > 0
        case .noPrecipitationFor24Hours, .noPrecipitationFor48Hours:
            return precipitationAmount == 0 && precipitationType == .none
        }
    }
}