//
//  LiquidGlassFieldBackground.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/12/26.
//

import SwiftUI

extension View {
    /// The shared form-field surface for the streamlined reminder creator:
    /// a tinted Liquid Glass rounded rectangle.
    func liquidGlassFieldBackground(tint: Color) -> some View {
        background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .glassEffect(.regular.tint(tint.opacity(0.05)), in: .rect(cornerRadius: 16))
        )
    }
}
