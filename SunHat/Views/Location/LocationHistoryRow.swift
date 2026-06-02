//
//  LocationHistoryRow.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct LocationHistoryRow: View {
    let historyItem: LocationHistory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: historyItem.source.icon)
                .font(.caption)
                .foregroundColor(sourceColor)
                .frame(width: 20, height: 20)

            Text(historyItem.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Text(historyItem.timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var sourceColor: Color {
        switch historyItem.source {
        case .gps:
            return .blue
        case .manual:
            return .purple
        case .search:
            return .green
        case .imported:
            return .orange
        }
    }
}
