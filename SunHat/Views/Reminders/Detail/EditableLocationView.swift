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
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let address = location.fullAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
