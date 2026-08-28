//
//  FilterChip.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(chipBackground, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(SunHatPressButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? String(localized: "Selected", comment: "Accessibility value for a toggled filter chip") : String(localized: "Not selected", comment: "Accessibility value for a toggled filter chip"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(SunHatMotion.cardToggle(reduceMotion: reduceMotion), value: isSelected)
    }

    private var chipBackground: some ShapeStyle {
        if isSelected {
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.45, blue: 0.68),
                        Color(red: 0.10, green: 0.62, blue: 0.52)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.70))
        }
    }
}
