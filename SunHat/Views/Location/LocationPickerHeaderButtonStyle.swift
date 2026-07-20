//
//  LocationPickerHeaderButtonStyle.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct LocationPickerHeaderButtonStyle: ButtonStyle {
    var isEmphasized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFontStyle.callout.font.weight(.semibold))
            .foregroundStyle(isEmphasized ? Color.white : Color.accentColor)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(isEmphasized ? Color.accentColor : Color(.secondarySystemBackground).opacity(0.76))
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.58), lineWidth: 0.8)
                    }
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.06 : 0.10), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(SunHatMotion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
