//
//  TriggerHistoryTimeline.swift
//  SunHat
//

import SwiftUI

struct TriggerHistoryTimeline: View {
    let history: [ReminderHistory]
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if history.isEmpty {
                emptyHistoryView
            } else {
                ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                    TriggerHistoryRow(
                        entry: entry,
                        isLast: index == history.count - 1,
                        isCompact: isCompact
                    )
                }
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No recent activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("History will appear here when the reminder triggers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private struct TriggerHistoryRow: View {
    let entry: ReminderHistory
    let isLast: Bool
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(actionColor)
                    .frame(width: 12, height: 12)

                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: isCompact ? 20 : 30)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.action.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isCompact ? 1 : 2)
                }

                if let temperature = entry.temperatureAtTime {
                    Text("Temperature: \(Int(temperature))°F")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(entry.timestamp, format: .dateTime.weekday().month().day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var actionColor: Color {
        switch entry.action {
        case .triggered:
            return .green
        case .completed:
            return .blue
        case .snoozed, .paused:
            return .orange
        case .skipped:
            return .red
        case .created, .modified:
            return .purple
        default:
            return .gray
        }
    }
}
