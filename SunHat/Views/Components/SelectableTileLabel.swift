//
//  SelectableTileLabel.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/12/26.
//

import SwiftUI

/// A fixed-height selectable tile (icon over caption) used for option grids
/// in the streamlined reminder creator, currently time-of-day preference.
/// Flat tint fill when selected, matching the app's native segmented/toggle styling.
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
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color(.tertiarySystemBackground)))
        )
    }

    private var iconColor: Color {
        if isSelected { return .white }
        return iconUsesTintWhenUnselected ? tint : .primary
    }
}
