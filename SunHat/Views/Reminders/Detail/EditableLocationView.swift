//
//  EditableLocationView.swift
//  SunHat
//

import SwiftUI

struct EditableLocationView: View {
    @Binding var location: EditableLocation
    @Binding var showingLocationPicker: Bool

    var body: some View {
        Button {
            showingLocationPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: location.isCurrentLocation ? "location.fill" : "mappin.circle")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let address = location.fullAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
