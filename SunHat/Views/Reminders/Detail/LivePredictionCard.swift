//
//  LivePredictionCard.swift
//  SunHat
//

import SwiftUI

struct LivePredictionCard: View {
    let prediction: LivePrediction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Trigger")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(prediction.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SunHatStatusPill(
                    text: prediction.confidenceText,
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: prediction.confidenceColor
                )
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .clipShape(.rect(cornerRadius: 2))

                    Rectangle()
                        .fill(prediction.confidenceColor)
                        .frame(width: geometry.size.width * prediction.confidence, height: 4)
                        .clipShape(.rect(cornerRadius: 2))
                        .animation(SunHatMotion.cardToggle(reduceMotion: reduceMotion), value: prediction.confidence)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)

            HStack {
                ForEach(0..<prediction.totalDays, id: \.self) { index in
                    Circle()
                        .fill(index < prediction.matchingDays ? prediction.confidenceColor : Color(.systemGray5))
                        .frame(width: 8, height: 8)
                }

                Spacer()

                Text("\(prediction.matchingDays) of \(prediction.totalDays) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(prediction.confidenceColor.opacity(0.08)), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next trigger, \(prediction.description)")
        .accessibilityValue("\(prediction.confidenceText) confidence, \(prediction.matchingDays) of \(prediction.totalDays) days match")
    }
}
