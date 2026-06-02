//
//  DuplicateReminderView.swift
//  SunHat
//

import SwiftUI

struct DuplicateReminderView: View {
    let reminder: WeatherReminder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Create a copy of this reminder with modifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button("Exact Copy") {
                        duplicateExact()
                    }
                    .buttonStyle(ShareButtonStyle())

                    Button("Copy with New Location") {
                        duplicateWithNewLocation()
                    }
                    .buttonStyle(ShareButtonStyle())

                    Button("Copy with Different Temperature") {
                        duplicateWithDifferentTemperature()
                    }
                    .buttonStyle(ShareButtonStyle())
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Duplicate Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func duplicateExact() {
        // Implement exact duplication
        dismiss()
    }

    private func duplicateWithNewLocation() {
        // Implement duplication with location picker
        dismiss()
    }

    private func duplicateWithDifferentTemperature() {
        // Implement duplication with temperature adjustment
        dismiss()
    }
}
