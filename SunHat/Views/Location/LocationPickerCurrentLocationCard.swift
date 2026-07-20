//
//  LocationPickerCurrentLocationCard.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct LocationPickerCurrentLocationCard: View {
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: "location.fill")
                    .font(AppFontStyle.title3.font)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Location")
                        .font(AppFontStyle.headline.font)
                        .foregroundStyle(.primary)

                    Text("Use the device location for live local weather.")
                        .font(AppFontStyle.callout.font)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppFontStyle.title3.font)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .sunHatSurface(tint: .blue, cornerRadius: 22, prominence: isSelected ? 0.82 : 0.58)
        }
        .buttonStyle(SunHatPressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current Location")
        .accessibilityHint("Uses the device location for live local weather.")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

#Preview {
    LocationPickerCurrentLocationCard(isSelected: true, onSelect: {})
        .padding()
}
