//
//  ForecastDayCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct ForecastDayCard: View {
    let day: WeatherForecastDay
    let reminder: CustomReminder
    let isSelected: Bool
    let onTap: () -> Void

    private var willTrigger: Bool {
        let tempMatch: Bool
        switch reminder.temperatureType {
        case .temperatureRange:
            tempMatch = day.highTemp >= Int(reminder.minTemperature) &&
                day.highTemp <= Int(reminder.maxTemperature)
        case .exactTemperature:
            tempMatch = abs(Double(day.highTemp) - reminder.minTemperature) <= 2
        }

        let skyMatch = reminder.matchesSkyCondition(for: day.weatherCondition)
        return tempMatch && skyMatch
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(day.dayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Image(systemName: day.weatherIcon)
                    .font(.title3)
                    .foregroundStyle(day.weatherColor)

                Text("\(day.highTemp)°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Circle()
                    .fill(willTrigger ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue : Color.clear,
                                lineWidth: 1
                            )
                    }
            )
        }
        .buttonStyle(.plain)
    }
}
