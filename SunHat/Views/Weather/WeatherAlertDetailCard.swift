//
//  WeatherAlertDetailCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct WeatherAlertDetailCard: View {
    let alert: WeatherAlertDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: alert.iconName)
                    .font(AppFontStyle.title2.font)
                    .foregroundStyle(alert.severityColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(alert.severity.displayName)
                        .font(.caption)
                        .foregroundStyle(alert.severityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(alert.severityColor.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 4))
                }
                
                Spacer()
                
                Text(alert.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(alert.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        WeatherAlertDetailCard(alert: WeatherAlertDisplay(
            id: UUID(),
            timestamp: Date(),
            title: "UV Index Advisory",
            description: "UV index will be very high. Use sunscreen and protective clothing.",
            severity: .moderate,
            type: .uv,
            area: "Local Area",
            instructions: nil,
            expiresAt: nil,
            isActive: true
        ))
    }
}
