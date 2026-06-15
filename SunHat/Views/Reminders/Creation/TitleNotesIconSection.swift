//
//  TitleNotesIconSection.swift
//  SunHat
//

import SwiftUI

struct TitleNotesIconSection: View {
    @Binding var title: String
    @Binding var notes: String
    @Binding var selectedIcon: String

    var body: some View {
        VStack(spacing: 16) {
            TextField("Title", text: $title)
                .font(.body)
                .padding(12)
                .glassEffect(.regular.tint(.purple.opacity(0.05)), in: .rect(cornerRadius: 10))
                .accessibilityLabel("Reminder title")

            TextField("Add Notes", text: $notes)
                .font(.body)
                .padding(12)
                .glassEffect(.regular.tint(.purple.opacity(0.05)), in: .rect(cornerRadius: 10))
                .accessibilityLabel("Reminder notes")

            HStack {
                Text("Icon")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            IconPickerGrid(selectedIcon: $selectedIcon)
        }
    }
}

private struct IconPickerGrid: View {
    @Binding var selectedIcon: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CustomReminder.availableIcons, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    ZStack {
                        Circle()
                            .fill(selectedIcon == icon
                                  ? Color.purple.opacity(0.2)
                                  : Color(.tertiarySystemBackground))
                            .overlay(
                                Circle()
                                    .stroke(selectedIcon == icon ? Color.purple : Color.clear, lineWidth: 2)
                            )

                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(selectedIcon == icon ? .purple : .secondary)
                    }
                    .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon)
                .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
            }
        }
    }
}
