//
//  LocationResultRow.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import MapKit

struct LocationResultRow: View {
    let result: MKLocalSearchCompletion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "mappin.circle")
                    .font(AppFontStyle.title3.font)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(.blue.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(AppFontStyle.subheadline.font)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .sunHatSurface(tint: .blue, cornerRadius: 18, prominence: 0.52)
        }
        .buttonStyle(SunHatPressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if result.subtitle.isEmpty {
            return result.title
        }

        return "\(result.title), \(result.subtitle)"
    }
}
