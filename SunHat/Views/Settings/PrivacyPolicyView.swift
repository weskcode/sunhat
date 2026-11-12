//
//  PrivacyPolicyView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

/// A hierarchical push destination, not a sheet: it relies on the presenting
/// NavigationStack's own back button rather than providing its own
/// NavigationStack or a Done button.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                privacyPolicyContent
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
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
                content: "Weather samples stay on your device for week and month history. New samples use coordinates rounded to about 1 km; reminder locations keep their selected precision. Weather refreshes remove samples older than 35 days. Samples can remain longer if weather is not refreshed. Older weather-location data may retain precise coordinates until you use Delete All Data in Settings. This history can reveal places where you requested weather and may be included in device backups. It is not sent to us."
            )

            privacySection(
                title: "Reminders & Preferences",
                content: "Your reminders and app preferences are stored locally on your device. We never have access to your personal reminder content."
            )

            privacySection(
                title: "Analytics",
                content: "SunHat itself does not collect personal analytics. Your reminders, preferences, and weather history stay on your device."
            )

            privacySection(
                title: "Advertising",
                content: "The free version of SunHat shows banner ads provided by Google AdMob. Google may collect device data (such as an advertising identifier) to serve and measure ads; iOS asks for your permission before any cross-app tracking, and you can decline. The SunHat Ad-Free subscription removes all ads, and no ad requests are made for subscribers. See Google's privacy policy for details on how Google handles ad data."
            )

            privacySection(
                title: "Third-Party Services",
                content: "Weather data is provided by Apple WeatherKit and advertising by Google AdMob. Please review Apple's and Google's privacy policies for information on how they handle data."
            )

            Text("Contact Us")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 20)

            Text("If you have any questions about this privacy policy, please contact us at \(AppSupportLinks.privacyEmail)")
                .font(.body)

            Text("Last updated: November 3, 2026")
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
    NavigationStack {
        PrivacyPolicyView()
    }
}
