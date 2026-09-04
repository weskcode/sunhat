//
//  WeatherHeroMetricPill.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import SwiftUI

struct WeatherHeroMetricPill: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(AppFontStyle.callout.font.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        } icon: {
            Image(systemName: systemImage)
                .font(AppFontStyle.caption.font.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.13), in: .circle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.primary.opacity(0.045), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
