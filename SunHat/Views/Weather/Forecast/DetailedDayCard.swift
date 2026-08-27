//
//  DetailedDayCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DetailedDayCard: View {
    let day: WeatherForecastDay

    var body: some View {
        VStack(spacing: 12) {
            header
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.dayName), \(day.shortDate), high \(day.highTemp) degrees, low \(day.lowTemp) degrees"
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

            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: day.weatherIcon)
                        .foregroundStyle(day.weatherColor)

                    Text("\(day.highTemp)°")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Text("Low \(day.lowTemp)°")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
