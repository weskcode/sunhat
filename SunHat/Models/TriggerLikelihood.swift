//
//  TriggerLikelihood.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/22/25.
//

import Foundation
import SwiftUI

struct TriggerLikelihood {
    let percentage: Double
    let description: String
    let triggerDays: [Date]
    
    var color: Color {
        switch percentage {
        case 0...25:
            return Color.gray.opacity(0.6)
        case 26...50:
            return .orange
        case 51...75:
            return .blue
        case 76...100:
            return .green
        default:
            return .gray
        }
    }
}
