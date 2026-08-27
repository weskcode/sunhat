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

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular.tint(tint.opacity(0.025 + 0.025 * prominence)),
                in: .rect(cornerRadius: cornerRadius)
            )
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
