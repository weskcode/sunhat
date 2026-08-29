//
//  ReadOnlyNotificationSettingsView.swift
//  SunHat
//

import SwiftUI

struct ReadOnlyNotificationSettingsView: View {
    let config: NotificationConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let config = config {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        Text(config.title.isEmpty ? "Default Title" : config.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }

                    if !config.message.isEmpty {
                        Text(config.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cooldown:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(config.cooldownPeriodHours) hours")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Label("Badge", systemImage: "app.badge")
                            .font(.caption2)
                            .foregroundStyle(.blue)

                        if config.customSound != nil {
                            Label("Sound", systemImage: "speaker.wave.2")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack {
                        Label(preferredTimeRangeDisplayName, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if config.respectsQuietHours {
                            Label("Quiet hours respected", systemImage: "moon.zzz")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Default notification settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 10))
    }

    private var preferredTimeRangeDisplayName: String {
        (config?.preferredTimeRange ?? .allDay).displayName
    }
}
