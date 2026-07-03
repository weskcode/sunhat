//
//  SunHatWeatherDial.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct SunHatWeatherDial: View {
    let systemImage: String
    let tint: Color
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.07), lineWidth: 12)

            Circle()
                .trim(from: 0.10, to: 0.86)
                .stroke(
                    tint.gradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-112))
                .animation(SunHatMotion.cardToggle(reduceMotion: reduceMotion), value: systemImage)

            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.34), lineWidth: 0.8)
                }

            Image(systemName: systemImage)
                .font(AppFont.system(size: 38))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: reduceMotion ? "" : systemImage)
        }
        .frame(width: 104, height: 104)
        .accessibilityHidden(true)
    }
}
