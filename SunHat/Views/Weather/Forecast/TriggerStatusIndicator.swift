//
//  TriggerStatusIndicator.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct TriggerStatusIndicator: View {
    let weather: CurrentWeatherData
    let reminder: CustomReminder

    private var willTrigger: Bool {
        let tempMatch: Bool
        switch reminder.temperatureType {
        case .temperatureRange:
            tempMatch = weather.temperature >= reminder.minTemperature &&
                weather.temperature <= reminder.maxTemperature
        case .exactTemperature:
            tempMatch = abs(weather.temperature - reminder.minTemperature) <= 2
        }

        let skyMatch: Bool
        if reminder.selectedSkyConditions.isEmpty {
            skyMatch = true
        } else {
            let currentSky = skyCondition(for: weather.condition)
            switch reminder.conditionMode {
            case .include:
                skyMatch = reminder.selectedSkyConditions.contains(currentSky)
            case .exclude:
                skyMatch = !reminder.selectedSkyConditions.contains(currentSky)
            }
        }

        return tempMatch && skyMatch
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(willTrigger ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(willTrigger ? "Will trigger now!" : "Waiting for conditions")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(willTrigger ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((willTrigger ? Color.green : Color.orange).opacity(0.1))
        )
    }

    private func skyCondition(for condition: String) -> SkyCondition {
        switch condition.lowercased() {
        case "clear":
            .sunny
        case "partly cloudy":
            .partlyCloudy
        case "cloudy":
            .cloudy
        case "light rain", "rain":
            .rainy
        case "snow":
            .snowy
        default:
            .sunny
        }
    }
}
