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
                VStack(spacing: 30) {
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
        VStack(spacing: 16) {
            Image(systemName: "thermometer.sun.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("SunHat")
                .font(.largeTitle)
                .bold()

            Text("Weather-Smart Reminders")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var mission: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our Mission")
                .font(.headline)

            Text("SunHat helps you plan your activities around the weather. Get reminded when conditions are perfect for gardening, exercise, outdoor dining, and more.")
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
                    service: "SwiftData & CloudKit",
                    description: "Data storage and sync"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var builtWithNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Built With")
                .font(.headline)

            Text("SunHat is a private project built with Swift (Apple's open source programming language) and Apple's modern iOS frameworks.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contactFooter: some View {
        VStack(spacing: 12) {
            Text("Made with ❤️ by the SunHat Team")
                .font(.callout)
                .foregroundStyle(.secondary)

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
