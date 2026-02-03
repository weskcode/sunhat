//
//  ParsedLanguageInfo.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/22/25.
//

import Foundation

struct ParsedLanguageInfo {
    let originalInput: String
    let extractedTemperature: Double?
    let extractedTemperatureRange: ClosedRange<Double>?
    let suggestedCategory: ActivityInterest?
    let suggestedTiming: NotificationTiming?
    let suggestedTitle: String
    let suggestedMessage: String
    let confidence: Double
}
