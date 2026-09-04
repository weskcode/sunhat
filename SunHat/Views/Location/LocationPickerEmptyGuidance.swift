//
//  LocationPickerEmptyGuidance.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import SwiftUI

struct LocationPickerEmptyGuidance: View {
    let hasSearchText: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hasSearchText ? "mappin.slash" : "magnifyingglass")
                .font(AppFontStyle.title2.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(hasSearchText ? "No Matches Yet" : "Find Any Forecast")
                    .font(AppFontStyle.headline.font)
                    .foregroundStyle(.primary)

                Text(hasSearchText ? "Try a broader city or landmark name." : "Search by city, neighborhood, airport, or landmark.")
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 36)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LocationPickerEmptyGuidance(hasSearchText: false)
        .padding()
}
