//
//  LocationPickerCurrentLocationCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import SwiftUI

struct LocationPickerCurrentLocationCard: View {
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .frame(width: 28)
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
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current Location")
        .accessibilityHint("Uses the device location for live local weather.")
        .accessibilityValue(isSelected ? String(localized: "Selected", comment: "Accessibility value for the current-location card when chosen") : String(localized: "Not selected", comment: "Accessibility value for the current-location card when not chosen"))
    }
}

#Preview {
    LocationPickerCurrentLocationCard(isSelected: true, onSelect: {})
        .padding()
}
