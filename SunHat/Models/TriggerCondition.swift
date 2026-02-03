//
//  TriggerCondition.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData

@Model
class TriggerCondition {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Temperature trigger types
    var triggerType: TriggerType = TriggerType.exactTemperature
    
    // Exact temperature settings
    var targetTemperature: Double = 70.0
    var temperatureTolerance: Double = 1.0
    var useFeelsLike: Bool = false
    
    // Range temperature settings
    var minTemperature: Double?
    var maxTemperature: Double?
    
    // Pattern settings
    var consecutiveDays: Int = 1
    var averagingPeriod: Int = 1
    var comparisonType: ComparisonType = ComparisonType.above
    
    // Seasonal markers
    var seasonalType: SeasonalType?
    var historicalComparisonDays: Int = 30
    
    // Composite conditions
    var requiresHumidity: Bool = false
    var targetHumidity: Double?
    var humidityTolerance: Double = 10.0
    
    var requiresWindSpeed: Bool = false
    var maxWindSpeed: Double?
    
    var requiresPrecipitation: Bool = false
    var precipitationRequirement: PrecipitationRequirement = PrecipitationRequirement.none
    
    // Time constraints
    var timeOfDayStart: Date?
    var timeOfDayEnd: Date?
    
    // Advanced settings
    var isEnabled: Bool = true
    var createdAt: Date = Date()
    var lastEvaluated: Date?
    var evaluationCount: Int = 0
    var successfulTriggers: Int = 0
    
    // CloudKit compatibility
    @Attribute(.externalStorage) var customConditionData: Data?
    
    // Relationship
    var weatherReminder: WeatherReminder?
    
    init(
        triggerType: TriggerType = .exactTemperature,
        targetTemperature: Double = 70.0,
        comparisonType: ComparisonType = .above
    ) {
        self.triggerType = triggerType
        self.targetTemperature = targetTemperature
        self.comparisonType = comparisonType
    }
}

enum TriggerType: String, Codable, CaseIterable {
    case exactTemperature = "exact"
    case temperatureRange = "range"
    case consecutiveDays = "consecutive"
    case averageTemperature = "average"
    case seasonalMarker = "seasonal"
    case composite = "composite"
    case historicalComparison = "historical"
}

enum ComparisonType: String, Codable, CaseIterable {
    case above = "above"
    case below = "below"
    case equals = "equals"
    case between = "between"
}

enum SeasonalType: String, Codable, CaseIterable {
    case firstFrost = "first_frost"
    case lastFrost = "last_frost"
    case springTransition = "spring_transition"
    case summerTransition = "summer_transition"
    case fallTransition = "fall_transition"
    case winterTransition = "winter_transition"
    case growingSeasonStart = "growing_season_start"
    case growingSeasonEnd = "growing_season_end"
}

enum PrecipitationRequirement: String, Codable, CaseIterable {
    case none = "none"
    case dry = "dry"
    case anyPrecipitation = "any"
    case rain = "rain"
    case snow = "snow"
    case noPrecipitationFor24Hours = "no_precip_24h"
    case noPrecipitationFor48Hours = "no_precip_48h"
}
