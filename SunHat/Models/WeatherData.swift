//
//  WeatherData.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData

@Model
class WeatherData {
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
    var cloudCoverage: Int = 0
    
    // Wind data
    var windSpeed: Double = 0.0
    var windDirection: Int = 0
    var windDirectionDegrees: Double = 0.0
    var windGust: Double?
    
    // Precipitation
    var precipitationAmount: Double = 0.0
    var precipitationProbability: Int = 0
    var precipitationType: PrecipitationType
    var snowDepth: Double?
    
    // Weather description
    var weatherCondition: WeatherCondition
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
    var dataSource: WeatherDataSource
    var accuracy: WeatherAccuracy
    var lastUpdated: Date = Date()
    
    // CloudKit optimization
    @Attribute(.externalStorage) var rawWeatherData: Data?
    
    // Location coordinates (for backward compatibility)
    var locationLatitude: Double = 0.0
    var locationLongitude: Double = 0.0
    
    // Relationships
    var location: LocationData?
    var forecastDays: [ForecastDay] = []
    
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
        
        // Set location coordinates if location is provided
        if let location = location {
            self.locationLatitude = location.latitude
            self.locationLongitude = location.longitude
        }
        
        self.precipitationType = .none
        self.weatherCondition = .clear
        self.dataSource = .unknown
        self.accuracy = .medium
        self.expiresAt = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
    }
}

@Model
class ForecastDay {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Date for this forecast
    var date: Date = Date()
    var dayOfWeek: String = ""
    
    // Temperature range
    var highTemperature: Double = 0.0
    var lowTemperature: Double = 0.0
    var averageTemperature: Double = 0.0
    
    // Conditions
    var weatherCondition: WeatherCondition
    var weatherDescription: String = ""
    var iconName: String = ""
    
    // Precipitation
    var precipitationProbability: Int = 0
    var precipitationAmount: Double = 0.0
    var precipitationType: PrecipitationType
    
    // Wind
    var windSpeed: Double = 0.0
    var windDirection: Int = 0
    
    // Other conditions
    var humidity: Int = 0
    var uvIndex: Double = 0.0
    var cloudCover: Int = 0
    
    // Confidence and accuracy
    var confidence: ForecastConfidence
    var lastUpdated: Date = Date()
    
    // Relationship
    var weatherData: WeatherData?
    
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
        self.precipitationType = .none
        self.confidence = .medium
        
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
    case fog = "fog"
    case rain = "rain"
    case drizzle = "drizzle"
    case snow = "snow"
    case sleet = "sleet"
    case hail = "hail"
    case thunderstorm = "thunderstorm"
    case windy = "windy"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .clear:
            return "Clear"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .cloudy:
            return "Cloudy"
        case .overcast:
            return "Overcast"
        case .fog:
            return "Fog"
        case .rain:
            return "Rain"
        case .drizzle:
            return "Drizzle"
        case .snow:
            return "Snow"
        case .sleet:
            return "Sleet"
        case .hail:
            return "Hail"
        case .thunderstorm:
            return "Thunderstorm"
        case .windy:
            return "Windy"
        case .unknown:
            return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .clear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy:
            return "cloud.fill"
        case .overcast:
            return "cloud.fill"
        case .fog:
            return "cloud.fog.fill"
        case .rain:
            return "cloud.rain.fill"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .snow:
            return "cloud.snow.fill"
        case .sleet:
            return "cloud.sleet.fill"
        case .hail:
            return "cloud.hail.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .windy:
            return "wind"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
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

