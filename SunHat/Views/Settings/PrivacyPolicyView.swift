//
//  PrivacyPolicyView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    privacyPolicyContent
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
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

    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Privacy Matters")
                .font(.title2)
                .bold()

            Text("SunHat is designed with your privacy in mind. Here's how we handle your data:")
                .font(.body)

            privacySection(
                title: "Location Data",
                content: "We only access your location to provide relevant weather information. Coordinates are sent only to enabled weather providers to fetch forecasts for your area."
            )

            privacySection(
                title: "Weather Data",
                content: "Weather information is fetched from reliable sources and cached locally on your device for better performance. This data is not transmitted to our servers."
            )

            privacySection(
                title: "Reminders & Preferences",
                content: "Your reminders and app preferences are stored locally on your device. We never have access to your personal reminder content."
            )

            privacySection(
                title: "Analytics",
                content: "We do not collect any personal analytics or tracking data. The app works entirely on your device."
            )

            privacySection(
                title: "Third-Party Services",
                content: "Weather data is provided by Apple WeatherKit. Please review Apple's privacy policy for information on how it handles data."
            )

            Text("Contact Us")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 20)

            Text("If you have any questions about this privacy policy, please contact us at \(AppSupportLinks.privacyEmail)")
                .font(.body)

            Text("Last updated: August 28, 2026")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
    }

    // LocalizedStringKey so the literal sections above resolve through the
    // String Catalog instead of rendering raw English in every locale.
    private func privacySection(title: LocalizedStringKey, content: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
