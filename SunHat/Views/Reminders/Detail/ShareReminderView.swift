//
//  ShareReminderView.swift
//  SunHat
//

import SwiftUI

struct ShareReminderView: View {
    let reminder: WeatherReminder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share Reminder")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(reminder.displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)

                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        if let condition = reminder.triggerCondition {
                            Text("Triggers when temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°F")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .glassEffect(.regular.tint(.blue.opacity(0.05)), in: .rect(cornerRadius: 12))
                }

                VStack(spacing: 12) {
                    Button("Share as Text") {
                        shareAsText()
                    }
                    .buttonStyle(ShareButtonStyle())

                    Button("Export Settings") {
                        exportSettings()
                    }
                    .buttonStyle(ShareButtonStyle())
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Share Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareAsText() {
        // Implement text sharing
    }

    private func exportSettings() {
        // Implement settings export
    }
}

struct ShareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.blue)
            .foregroundColor(.white)
            .font(.headline)
            .clipShape(.rect(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    let reminder = WeatherReminder(
        title: "Morning Walk",
        reminderDescription: "Perfect weather for a refreshing morning walk",
        category: .exercise
    )

    return ShareReminderView(reminder: reminder)
}
