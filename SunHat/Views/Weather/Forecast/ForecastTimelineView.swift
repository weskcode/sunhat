//
//  ForecastTimelineView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct ForecastTimelineView: View {
    let forecast: [WeatherForecastDay]
    let reminder: CustomReminder

    @State private var selectedDay: WeatherForecastDay?
    @State private var showingDetails = false

    var body: some View {
        VStack(spacing: 16) {
            header
            timeline

            if let selectedDay {
                DayDetailsCard(day: selectedDay, reminder: reminder)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingDetails) {
            DetailedForecastView(forecast: forecast, reminder: reminder)
        }
    }

    private var header: some View {
        HStack {
            Text("7-Day Outlook")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            Button("View Details") {
                showingDetails = true
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
    }

    private var timeline: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(forecast, id: \.date) { day in
                    ForecastDayCard(
                        day: day,
                        reminder: reminder,
                        isSelected: selectedDay?.date == day.date
                    ) {
                        selectedDay = day
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    ForecastTimelineView(
        forecast: [],
        reminder: CustomReminder()
    )
    .padding()
}
