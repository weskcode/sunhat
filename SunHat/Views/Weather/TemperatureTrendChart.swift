//
//  TemperatureTrendChart.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import Charts

struct TemperatureTrendChart: View {
    let forecastData: [ForecastDay]
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateChart = false
    
    var body: some View {
        VStack(spacing: 8) {
            if forecastData.isEmpty {
                EmptyChartView()
            } else {
                chartView
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                animateChart = true
            }
        }
    }
    
    private var chartView: some View {
        Chart(forecastData.prefix(7), id: \.id) { forecast in
            // High temperature line
            LineMark(
                x: .value("Day", forecast.date),
                y: .value("High", forecast.highTemperature)
            )
            .foregroundStyle(.red)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
            .opacity(animateChart ? 1.0 : 0.0)
            
            // Low temperature line
            LineMark(
                x: .value("Day", forecast.date),
                y: .value("Low", forecast.lowTemperature)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
            .opacity(animateChart ? 1.0 : 0.0)
            
            // High temperature area fill
            AreaMark(
                x: .value("Day", forecast.date),
                yStart: .value("Low", forecast.lowTemperature),
                yEnd: .value("High", forecast.highTemperature)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .red.opacity(0.1),
                        .blue.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(animateChart ? 0.3 : 0.0)
            
            // Data points
            PointMark(
                x: .value("Day", forecast.date),
                y: .value("High", forecast.highTemperature)
            )
            .foregroundStyle(.red)
            .symbolSize(30)
            .opacity(animateChart ? 1.0 : 0.0)
            
            PointMark(
                x: .value("Day", forecast.date),
                y: .value("Low", forecast.lowTemperature)
            )
            .foregroundStyle(.blue)
            .symbolSize(30)
            .opacity(animateChart ? 1.0 : 0.0)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dayFormatter.string(from: date))
                            .font(AppFontStyle.caption2.font)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let temp = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(temp))°")
                            .font(AppFontStyle.caption2.font)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartPlotStyle { plot in
            plot.frame(height: 120)
        }
        .animation(.easeInOut(duration: 1.0), value: animateChart)
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Forecast Unavailable")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 8))
    }
}

#Preview {
    TemperatureTrendChart(forecastData: [
        ForecastDay(date: Date(), highTemperature: 75, lowTemperature: 55),
        ForecastDay(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!, highTemperature: 78, lowTemperature: 58),
        ForecastDay(date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!, highTemperature: 72, lowTemperature: 52),
        ForecastDay(date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!, highTemperature: 69, lowTemperature: 49),
        ForecastDay(date: Calendar.current.date(byAdding: .day, value: 4, to: Date())!, highTemperature: 71, lowTemperature: 51),
        ForecastDay(date: Calendar.current.date(byAdding: .day, value: 5, to: Date())!, highTemperature: 74, lowTemperature: 54),
        ForecastDay(date: Calendar.current.date(byAdding: .day, value: 6, to: Date())!, highTemperature: 76, lowTemperature: 56)
    ])
    .padding()
}
