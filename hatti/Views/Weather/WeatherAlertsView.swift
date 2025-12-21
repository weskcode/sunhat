//
//  WeatherAlertsView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct WeatherAlertsView: View {
    let alerts: [WeatherAlertDisplay]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if alerts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("No Active Alerts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("All weather conditions are normal")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(alerts) { alert in
                        WeatherAlertDetailCard(alert: alert)
                    }
                }
            }
            .navigationTitle("Weather Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WeatherAlertDetailCard: View {
    let alert: WeatherAlertDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: alert.iconName)
                    .font(.title2)
                    .foregroundColor(alert.severityColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(alert.severity.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(alert.severityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(alert.severityColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(alert.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(alert.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    WeatherAlertsView(alerts: [
WeatherAlertDisplay(
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
        ),
        WeatherAlertDisplay(
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
        )
    ])
}
