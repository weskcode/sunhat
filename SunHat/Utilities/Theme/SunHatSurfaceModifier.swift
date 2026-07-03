//
//  SunHatSurfaceModifier.swift
//  SunHat
//
//  Created by Codex on 7/2/26.
//

import SwiftUI

struct SunHatSurfaceModifier: ViewModifier {
    var tint: Color = .accentColor
    var cornerRadius: CGFloat = 22
    var prominence: Double = 1

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tint.opacity(colorScheme == .dark ? 0.045 * prominence : 0.060 * prominence))
                    }
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? 0.22 : 0.62),
                                        tint.opacity(colorScheme == .dark ? 0.10 : 0.20),
                                        .black.opacity(colorScheme == .dark ? 0.20 : 0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .glassEffect(.regular.tint(tint.opacity(colorScheme == .dark ? 0.055 : 0.035)), in: .rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.10), radius: 18 * prominence, x: 0, y: 10 * prominence)
    }
}

extension View {
    func sunHatSurface(
        tint: Color = .accentColor,
        cornerRadius: CGFloat = 22,
        prominence: Double = 1
    ) -> some View {
        modifier(SunHatSurfaceModifier(tint: tint, cornerRadius: cornerRadius, prominence: prominence))
    }
}
