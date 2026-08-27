//
//  AboutView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    appIdentity
                    mission
                    acknowledgments
                    builtWithNotice
                    contactFooter
                }
                .padding()
            }
            .navigationTitle("About")
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

    private var appIdentity: some View {
        VStack(spacing: 12) {
            Image(systemName: "thermometer.sun.fill")
                .font(.system(.largeTitle, design: .rounded, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("SunHat")
                .font(.largeTitle)
                .bold()

            Text("Weather reminders for the plans that matter")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var mission: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About SunHat")
                .font(.headline)

            Text("SunHat watches the forecast for conditions you choose, then reminds you when it may be a good time for an activity.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var acknowledgments: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acknowledgments")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                acknowledgmentRow(
                    service: "Apple WeatherKit",
                    description: "Primary weather data provider"
                )

                acknowledgmentRow(
                    service: "OpenWeatherMap",
                    description: "Backup weather data service"
                )

                acknowledgmentRow(
                    service: "SF Symbols",
                    description: "Icons and symbols throughout the app"
                )

                acknowledgmentRow(
                    service: "SwiftData",
                    description: "On-device data storage"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var builtWithNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Built With")
                .font(.headline)

            Text("SunHat is built with Swift and Apple's iOS frameworks.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contactFooter: some View {
        VStack(spacing: 8) {
            Text("© 2026 SunHat. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private func acknowledgmentRow(service: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(service)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AboutView()
}
