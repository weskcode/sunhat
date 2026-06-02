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
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(forecast, id: \.date) { day in
                        DetailedDayCard(day: day, reminder: reminder)
                    }
                }
                .padding()
            }
            .navigationTitle("Detailed Forecast")
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
