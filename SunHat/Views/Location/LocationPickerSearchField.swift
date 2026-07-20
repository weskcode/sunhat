//
//  LocationPickerSearchField.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct LocationPickerSearchField: View {
    @Binding var searchText: String
    let isSearching: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(AppFontStyle.callout.font)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("City, neighborhood, or place", text: $searchText)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .accessibilityLabel("Search locations")

            if isSearching {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Searching")
            } else if !searchText.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(SunHatPressButtonStyle())
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .sunHatSurface(tint: .blue, cornerRadius: 18, prominence: 0.58)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var searchText = ""

    LocationPickerSearchField(searchText: $searchText, isSearching: false, onSubmit: {})
        .padding()
}
