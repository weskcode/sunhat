//
//  SunHatForecastRibbon.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
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

                Capsule()
                    .fill(.primary.opacity(0.10))
                    .frame(height: 6)
                    .padding(.horizontal, 14)

                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: 40)
                    .offset(x: min(max(markerX - 2, 14), width - 18))
            }
        }
    }
}
