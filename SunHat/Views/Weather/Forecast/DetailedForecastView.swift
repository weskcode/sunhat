//
//  DetailedForecastView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DetailedForecastView: View {
    let forecast: [WeatherForecastDay]
    let reminder: CustomReminder

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if forecast.isEmpty {
                    ContentUnavailableView(
                        "Forecast Unavailable",
                        systemImage: "cloud.sun",
                        description: Text("Weather data for this reminder is not available right now.")
                    )
                } else {
                    List(forecast, id: \.date) { day in
                        DetailedDayCard(day: day)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
