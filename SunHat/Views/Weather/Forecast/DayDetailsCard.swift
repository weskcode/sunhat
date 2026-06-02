//
//  DayDetailsCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DayDetailsCard: View {
    let day: WeatherForecastDay
    let reminder: CustomReminder

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(day.dayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(day.shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                weatherSummary

                Spacer()

                triggerProbability
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var weatherSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: day.weatherIcon)
                    .foregroundStyle(day.weatherColor)

                Text("\(day.highTemp)° / \(day.lowTemp)°")
                    .fontWeight(.medium)
            }

            Text("Conditions look good for \(reminder.displayTitle.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var triggerProbability: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("85%")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.green)

            Text("Trigger chance")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
