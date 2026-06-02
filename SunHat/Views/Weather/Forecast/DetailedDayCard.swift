//
//  DetailedDayCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DetailedDayCard: View {
    let day: WeatherForecastDay
    let reminder: CustomReminder

    var body: some View {
        VStack(spacing: 16) {
            header

            Divider()

            triggerAnalysis
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(day.dayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(day.shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                HStack {
                    Image(systemName: day.weatherIcon)
                        .foregroundStyle(day.weatherColor)

                    Text("\(day.highTemp)°")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Text("Low \(day.lowTemp)°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var triggerAnalysis: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trigger Analysis")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Perfect conditions for \(reminder.displayTitle.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("85%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)

                Text("Likelihood")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
