//
//  SmartSuggestion.swift
//  hatti
//
//  Created by Wesley Keetch on 7/22/25.
//

import Foundation
import SwiftUI

struct SmartSuggestion: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let naturalLanguageText: String
    let category: ActivityInterest
    let temperature: Double
    let temperatureRange: ClosedRange<Double>?
    let conditionType: TriggerType
    let timing: NotificationTiming
    let icon: String
    let color: Color
    
    init(id: UUID = UUID(), title: String, description: String, naturalLanguageText: String, category: ActivityInterest, temperature: Double, temperatureRange: ClosedRange<Double>? = nil, conditionType: TriggerType, timing: NotificationTiming, icon: String, color: Color) {
        self.id = id
        self.title = title
        self.description = description
        self.naturalLanguageText = naturalLanguageText
        self.category = category
        self.temperature = temperature
        self.temperatureRange = temperatureRange
        self.conditionType = conditionType
        self.timing = timing
        self.icon = icon
        self.color = color
    }
}