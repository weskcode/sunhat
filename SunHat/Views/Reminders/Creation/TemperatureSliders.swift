//
//  TemperatureSliders.swift
//  SunHat
//

import SwiftUI

struct TemperatureRangeSlider: View {
    @Binding var minTemp: Double
    @Binding var maxTemp: Double

    @State private var tempRange: ClosedRange<Double> = 65...75

    var body: some View {
        VStack(spacing: 12) {
            RangeSlider(
                range: $tempRange,
                bounds: 32...100,
                step: 1
            )
            .onChange(of: tempRange) { _, newRange in
                minTemp = newRange.lowerBound
                maxTemp = newRange.upperBound
            }
            .onAppear {
                tempRange = minTemp...maxTemp
            }

            HStack {
                Text("32°F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("100°F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SingleTemperatureSlider: View {
    @Binding var temperature: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("32°F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(temperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Spacer()

                Text("100°F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $temperature, in: 32...100, step: 1)
                .tint(Color.accentColor)
        }
    }
}

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double

    @State private var lowerThumbLocation: CGFloat = 0
    @State private var upperThumbLocation: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - 44

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 4)
                    .clipShape(.rect(cornerRadius: 2))
                    .offset(x: 22)

                Rectangle()
                    .fill(Color.blue)
                    .frame(width: (upperThumbLocation - lowerThumbLocation) * trackWidth, height: 4)
                    .clipShape(.rect(cornerRadius: 2))
                    .offset(x: 22 + lowerThumbLocation * trackWidth)

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                    .offset(x: lowerThumbLocation * trackWidth)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newLocation = max(0, min(upperThumbLocation, value.location.x / trackWidth))
                                lowerThumbLocation = newLocation
                                updateRange()
                            }
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                    .offset(x: upperThumbLocation * trackWidth + 22)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newLocation = max(lowerThumbLocation, min(1, (value.location.x - 22) / trackWidth))
                                upperThumbLocation = newLocation
                                updateRange()
                            }
                    )
            }
        }
        .frame(height: 44)
        .onAppear {
            updateThumbLocations()
        }
        .onChange(of: range) { _, _ in
            updateThumbLocations()
        }
    }

    private func updateThumbLocations() {
        let normalizedLower = (range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        let normalizedUpper = (range.upperBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)

        lowerThumbLocation = normalizedLower
        upperThumbLocation = normalizedUpper
    }

    private func updateRange() {
        let lowerValue = bounds.lowerBound + lowerThumbLocation * (bounds.upperBound - bounds.lowerBound)
        let upperValue = bounds.lowerBound + upperThumbLocation * (bounds.upperBound - bounds.lowerBound)

        let steppedLower = round(lowerValue / step) * step
        let steppedUpper = round(upperValue / step) * step

        range = steppedLower...steppedUpper
    }
}
