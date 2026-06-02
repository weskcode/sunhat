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
                            .foregroundColor(.blue)

                        Text(config.title.isEmpty ? "Default Title" : config.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    if !config.message.isEmpty {
                        Text(config.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cooldown:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(config.cooldownPeriodHours) hours")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Label("Badge", systemImage: "app.badge")
                            .font(.caption2)
                            .foregroundColor(.blue)

                        if config.customSound != nil {
                            Label("Sound", systemImage: "speaker.wave.2")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else {
                Text("Default notification settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 10))
    }
}
