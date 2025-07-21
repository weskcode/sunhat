//
//  WeatherTypes.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI

// MARK: - Additional Weather Types
// Note: Main enum definitions moved to their respective model files to avoid duplication

// MARK: - Supporting Weather Types

enum WeatherSeverity: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case severe = "severe"
    case extreme = "extreme"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .severe:
            return "Severe"
        case .extreme:
            return "Extreme"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .moderate:
            return .yellow
        case .high:
            return .orange
        case .severe:
            return .red
        case .extreme:
            return .purple
        }
    }
}