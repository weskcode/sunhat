//
//  ReminderGlassCard.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct ReminderGlassCard: View {
    let reminder: WeatherReminder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shouldReduceMotion = reduceMotion

        NavigationLink {
            DetailedReminderView(reminder: reminder)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.16))
                            .overlay {
                                Circle()
                                    .stroke(Color.accentColor.opacity(0.26), lineWidth: 0.8)
                            }
                            .frame(width: 46, height: 46)

                        Image(systemName: reminder.category.iconName)
                            .font(AppFontStyle.title3.font)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(reminder.displayTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    SunHatStatusPill(
                        text: reminder.isCurrentlyActive ? "Active" : "Paused",
                        systemImage: reminder.isCurrentlyActive ? "checkmark.circle.fill" : "pause.circle.fill",
                        tint: reminder.isCurrentlyActive ? .green : .orange
                    )
                }

                if let condition = reminder.triggerCondition {
                    HStack(spacing: 10) {
                        Label("When temp is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°", systemImage: "thermometer.medium")
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Text(reminder.createdDate, format: .dateTime.month().day())
                            .font(AppFontStyle.caption.font)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.primary.opacity(0.045), in: .rect(cornerRadius: 13))
                }
            }
            .padding(16)
            .sunHatSurface(
                tint: reminder.isCurrentlyActive ? Color.accentColor : .secondary,
                cornerRadius: 20,
                prominence: 0.70
            )
        }
        .buttonStyle(SunHatPressButtonStyle())
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.84)
                .scaleEffect(shouldReduceMotion || phase.isIdentity ? 1 : 0.98)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens task details.")
    }

    private var accessibilityLabel: String {
        var parts = [reminder.displayTitle, reminder.isCurrentlyActive ? "Active" : "Paused"]

        if !reminder.reminderDescription.isEmpty {
            parts.append(reminder.reminderDescription)
        }

        if let condition = reminder.triggerCondition {
            parts.append("When temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature)) degrees")
        }

        return parts.joined(separator: ", ")
    }
}
