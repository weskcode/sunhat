//
//  ReadOnlyLocationView.swift
//  SunHat
//

import SwiftUI

struct ReadOnlyLocationView: View {
    let location: LocationData?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: location != nil ? "mappin.circle.fill" : "location.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(location?.displayName ?? "Current Location")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let location = location {
                    let addressComponents = [location.city, location.state, location.country].filter { !$0.isEmpty }
                    if !addressComponents.isEmpty {
                        Text(addressComponents.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Using device location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Using device location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 10))
    }
}
