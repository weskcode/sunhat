//
//  SavedLocationCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct SavedLocationCard: View {
    let location: SavedLocation
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    @State private var showingActions = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(sourceColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: location.source.icon)
                    .font(.body)
                    .foregroundColor(sourceColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(location.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if location.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Text(location.shortAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("Used \(location.useCount) times", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Label(location.lastUsed.formatted(.relative(presentation: .named)), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                showingActions = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
        .confirmationDialog("Location Actions", isPresented: $showingActions) {
            Button(location.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite()
            }

            Button("Rename") {
                onEdit()
            }

            Button("Delete", role: .destructive) {
                onDelete()
            }

            Button("Cancel", role: .cancel) { }
        }
    }

    private var sourceColor: Color {
        switch location.source {
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
