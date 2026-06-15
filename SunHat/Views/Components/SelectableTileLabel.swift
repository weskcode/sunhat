//
//  SelectableTileLabel.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// A fixed-height selectable tile (icon over caption) used for option grids
/// in the streamlined reminder creator — condition type and time range.
/// Selected tiles fill with a tint gradient and a subtle white stroke.
struct SelectableTileLabel: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let tint: Color
    var iconUsesTintWhenUnselected: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.white : .primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fillStyle)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.white.opacity(0.3) : .clear, lineWidth: 1)
                )
        )
    }

    private var iconColor: Color {
        if isSelected { return .white }
        return iconUsesTintWhenUnselected ? tint : .primary
    }

    private var fillStyle: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [tint.opacity(0.9), tint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            : AnyShapeStyle(Color(.tertiarySystemBackground))
    }
}
