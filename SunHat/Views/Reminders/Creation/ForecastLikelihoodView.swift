//
//  ForecastLikelihoodView.swift
//  SunHat
//

import SwiftUI

struct ForecastLikelihoodView: View {
    let likelihood: TriggerLikelihood
    let forecast: [WeatherForecastDay]
    let animationDelay: Double

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)

                    Text("7-Day Forecast")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                Text("Based on current weather forecast")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger Likelihood")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(likelihood.description)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(likelihood.color)

                    if let nextTriggerDay = likelihood.triggerDays.first {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)

                            Text("Next: \(nextTriggerDay, style: .date)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    CircularProgressView(
                        progress: likelihood.percentage / 100,
                        color: likelihood.color
                    )
                    .frame(width: 60, height: 60)

                    Text("\(likelihood.triggerDays.count) of 7 days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                ForEach(forecast.prefix(7), id: \.date) { day in
                    ForecastDayRow(
                        day: day,
                        willTrigger: likelihood.triggerDays.contains(day.date)
                    )
                }
            }
        }
        .padding(20)
        .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 16))
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

private struct ForecastDayRow: View {
    let day: WeatherForecastDay
    let willTrigger: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.dayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(day.shortDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50, alignment: .leading)

            Image(systemName: day.weatherIcon)
                .font(.caption)
                .foregroundStyle(day.weatherColor)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text("\(day.highTemp)°")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: 30, alignment: .trailing)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(willTrigger ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)

                Text(willTrigger ? "Will trigger" : "No trigger")
                    .font(.caption2)
                    .foregroundStyle(willTrigger ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
