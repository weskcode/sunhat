//
//  SunHatForecastRibbon.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct SunHatForecastRibbon: View {
    let current: Double
    let high: Double
    let low: Double
    let tint: Color

    private var normalized: Double {
        let range = max(high - low, 1)
        return min(max((current - low) / range, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let markerX = width * normalized

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.primary.opacity(0.045))

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<18, id: \.self) { index in
                        Capsule()
                            .fill(index < Int(normalized * 18) ? tint.opacity(0.52) : .primary.opacity(0.10))
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(14 + ((index * 11) % 26)))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: 40)
                    .shadow(color: tint.opacity(0.40), radius: 8, x: 0, y: 0)
                    .offset(x: min(max(markerX - 2, 14), width - 18))
            }
        }
    }
}
