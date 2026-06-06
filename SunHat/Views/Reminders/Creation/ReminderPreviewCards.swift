//
//  ReminderPreviewCards.swift
//  SunHat
//

import SwiftUI

struct LivePreviewCard: View {
    let reminder: CustomReminder

    @State private var isVisible = false
    @State private var pulseAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.5 : 1.0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)

                    Image(systemName: "eye.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Text("Live Preview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(pulseAnimation ? 0.5 : 1.0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)

                    Text("LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)

                    Image(systemName: "cloud.sun.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("SunHat")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("now")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(reminder.previewTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(reminder.previewBody)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .glassEffect(.regular.tint(.green.opacity(0.05)), in: .rect(cornerRadius: 10))
        }
        .padding(16)
        .glassEffect(.regular.tint(.green.opacity(0.08)), in: .rect(cornerRadius: 12))
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isVisible = true
                }

                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    pulseAnimation = true
                }
            } else {
                isVisible = true
                pulseAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live preview: \(reminder.previewTitle). \(reminder.previewBody)")
    }
}

struct ReminderPreviewCard: View {
    let reminder: CustomReminder
    let animationDelay: Double

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(reminder.iconColor.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: reminder.selectedIcon)
                        .font(.title2)
                        .foregroundStyle(reminder.iconColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.displayTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Spacer()
            }

            VStack(spacing: 12) {
                ConditionRow(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: reminder.temperatureDescription,
                    color: .blue
                )

                ConditionRow(
                    icon: reminder.conditionMode == .exclude ? "xmark.circle" : "cloud.sun.fill",
                    title: "Sky",
                    value: reminder.skyConditionDescription,
                    color: reminder.conditionMode == .exclude ? .gray : .orange
                )

                ConditionRow(
                    icon: "clock",
                    title: "Time",
                    value: reminder.preferredTimeRange.displayName,
                    color: .orange
                )

                if reminder.respectQuietHours {
                    ConditionRow(
                        icon: "moon.zzz",
                        title: "Quiet Hours",
                        value: "Respected",
                        color: .purple
                    )
                }
            }
        }
        .padding(24)
        .glassEffect(.regular.tint(reminder.iconColor.opacity(0.06)), in: .rect(cornerRadius: 16))
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

private struct ConditionRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}
