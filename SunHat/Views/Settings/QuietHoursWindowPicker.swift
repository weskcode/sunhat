//
//  QuietHoursWindowPicker.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import SwiftUI

struct QuietHoursWindowPicker: View {
    @Binding var start: Date
    @Binding var end: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Silent Window")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Weather reminders pause between these times.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 30, height: 30)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Divider()

            QuietHoursTimeRow(
                title: "Pause at",
                detail: "Start quiet hours",
                systemImage: "moon.fill",
                tint: .indigo,
                selection: $start
            )

            Divider()

            QuietHoursTimeRow(
                title: "Resume at",
                detail: "Allow reminders again",
                systemImage: "sun.max.fill",
                tint: .orange,
                selection: $end
            )
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var start = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? .now
    @Previewable @State var end = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? .now

    Form {
        Section("Notifications") {
            Toggle("Quiet Hours", isOn: .constant(true))
            QuietHoursWindowPicker(start: $start, end: $end)
        }
    }
}
