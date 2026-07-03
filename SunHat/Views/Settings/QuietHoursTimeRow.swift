//
//  QuietHoursTimeRow.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct QuietHoursTimeRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    @Binding var selection: Date

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            label

            Spacer(minLength: 12)

            timePicker
        }
        .frame(minHeight: 52)
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            label
            timePicker
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }

    private var label: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timePicker: some View {
        DatePicker(title, selection: $selection, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.compact)
            .fixedSize()
            .accessibilityLabel(Text("\(title) time"))
    }
}

#Preview {
    @Previewable @State var selection = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? .now

    Form {
        Section {
            QuietHoursTimeRow(
                title: "Pause at",
                detail: "Start quiet hours",
                systemImage: "moon.fill",
                tint: .indigo,
                selection: $selection
            )
        }
    }
}
