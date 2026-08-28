//
//  NextReadyReminderCompactView.swift
//  SunHat
//

import SwiftUI

struct NextReadyReminderCompactView: View {
    let snapshot: NextReadyReminderSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: snapshot.systemImageName)
                .font(.title3)
                .foregroundStyle(snapshot.isReady ? .blue : .secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(snapshot.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(snapshot.isReady ? String(localized: "Next ready reminder, \(snapshot.title)", comment: "Accessibility label announcing the next ready reminder by name") : snapshot.title)
        .accessibilityHint(snapshot.subtitle)
    }
}

#Preview("Ready") {
    NextReadyReminderCompactView(
        snapshot: NextReadyReminderSnapshot(
            id: UUID(),
            title: "Morning Run",
            subtitle: "65-75°",
            systemImageName: "figure.run",
            isReady: true
        )
    )
    .padding()
}

#Preview("Unavailable") {
    NextReadyReminderCompactView(snapshot: .unavailable)
        .padding()
}
