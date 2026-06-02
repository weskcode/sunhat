//
//  LivePredictionCard.swift
//  SunHat
//

import SwiftUI

struct LivePredictionCard: View {
    let prediction: LivePrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Trigger")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(prediction.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(prediction.confidenceText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(prediction.confidenceColor)

                    Text("confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
                        .animation(.easeInOut(duration: 0.5), value: prediction.confidence)
                }
            }
            .frame(height: 4)

            HStack {
                ForEach(0..<prediction.totalDays, id: \.self) { index in
                    Circle()
                        .fill(index < prediction.matchingDays ? prediction.confidenceColor : Color(.systemGray5))
                        .frame(width: 8, height: 8)
                }

                Spacer()

                Text("\(prediction.matchingDays) of \(prediction.totalDays) days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(prediction.confidenceColor.opacity(0.08)), in: .rect(cornerRadius: 12))
    }
}
