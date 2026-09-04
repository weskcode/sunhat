//
//  LocationPickerSearchField.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
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
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var searchText = ""

    LocationPickerSearchField(searchText: $searchText, isSearching: false, onSubmit: {})
        .padding()
}
