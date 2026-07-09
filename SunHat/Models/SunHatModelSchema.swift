//
//  SunHatModelSchema.swift
//  SunHat
//

import SwiftData

enum SunHatModelSchema {
    static let modelTypes: [any PersistentModel.Type] = [
        WeatherReminder.self,
        TriggerCondition.self,
        LocationData.self,
        WeatherData.self,
        ForecastDay.self,
        NotificationConfig.self,
        ReminderHistory.self,
        UserPreferences.self,
        SavedLocation.self,
        LocationHistory.self
    ]

    static var modelTypeNames: Set<String> {
        Set(modelTypes.map { String(describing: $0) })
    }

    static var schema: Schema {
        Schema(modelTypes)
    }
}
