//
//  ForecastDetailToggleControl.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct ForecastDetailToggleControl: View {
    let isExpanded: Bool
    let tint: Color
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.down")
                .font(AppFontStyle.callout.font.weight(.semibold))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(SunHatMotion.cardToggle(reduceMotion: reduceMotion), value: isExpanded)
                .accessibilityHidden(true)

            Text(isExpanded ? "Hide forecast details" : "Show forecast details")
                .font(AppFontStyle.callout.font.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 14)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .overlay {
                    Capsule()
                        .fill(tint.opacity(colorScheme == .dark ? 0.18 : 0.10))
                }
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.18 : 0.62),
                                    tint.opacity(colorScheme == .dark ? 0.34 : 0.28),
                                    .black.opacity(colorScheme == .dark ? 0.28 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}
