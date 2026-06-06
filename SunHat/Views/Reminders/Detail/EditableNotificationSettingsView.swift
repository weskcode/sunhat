//
//  EditableNotificationSettingsView.swift
//  SunHat
//

import SwiftUI

struct EditableNotificationSettingsView: View {
    @Binding var config: EditableNotificationConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notification Title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                TextField("Enter notification title", text: $config.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Message")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                TextField("Enter notification message", text: $config.message, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Cooldown Period")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Stepper("\(config.cooldownPeriodHours) hours", value: $config.cooldownPeriodHours, in: 0...24)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show badge", isOn: $config.enableBadge)
                Toggle("Play sound", isOn: $config.enableSound)
            }
        }
    }
}
