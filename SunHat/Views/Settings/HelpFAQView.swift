//
//  HelpFAQView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct HelpFAQView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var expandedSections: Set<Int> = []

    private let faqItems = [
        FAQItem(
            question: "How do weather-triggered reminders work?",
            answer: "SunHat monitors weather conditions and sends you notifications when the temperature, humidity, or other conditions match your preferences. For example, you can set a reminder to water your garden when it hasn't rained and the temperature is above 70°F."
        ),
        FAQItem(
            question: "Why isn't my reminder triggering?",
            answer: "Make sure notifications are enabled in Settings, your reminder is active, and the weather conditions match your trigger settings. Also check that you're not in quiet hours and haven't reached your daily notification limit."
        ),
        FAQItem(
            question: "How accurate is the weather data?",
            answer: "We use Apple WeatherKit as our primary data source, with OpenWeatherMap as backup. Weather data is typically accurate for the next 24-48 hours, with longer forecasts being less precise."
        ),
        FAQItem(
            question: "Can I use the app without location access?",
            answer: "Location access is required for weather-based reminders. We only use your location to fetch relevant weather data and never share it with third parties."
        ),
        FAQItem(
            question: "How does iCloud sync work?",
            answer: "When signed in to iCloud, your reminders and preferences automatically sync across all your devices. All data remains private and encrypted."
        ),
        FAQItem(
            question: "What's the difference between temperature and 'feels like'?",
            answer: "Temperature is the actual air temperature, while 'feels like' accounts for humidity and wind chill to represent what the temperature actually feels like to your body."
        ),
        FAQItem(
            question: "Can I set reminders for multiple locations?",
            answer: "Currently, reminders are based on your current location. Multiple location support is planned for a future update."
        ),
        FAQItem(
            question: "How do I delete a reminder?",
            answer: "Swipe left on any reminder in the list view, or use the edit button to select multiple reminders for deletion."
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                introSection
                faqSection
                supportSection
            }
            .navigationTitle("Help & FAQ")
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

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Frequently Asked Questions")
                    .font(.headline)

                Text("Find answers to common questions about using SunHat.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    private var faqSection: some View {
        ForEach(Array(faqItems.enumerated()), id: \.offset) { index, item in
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedSections.contains(index) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedSections.insert(index)
                        } else {
                            expandedSections.remove(index)
                        }
                    }
                )
            ) {
                Text(item.answer)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } label: {
                Text(item.question)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }

    private var supportSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("Still need help?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Button("Contact Support", action: sendSupportEmail)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    private func sendSupportEmail() {
        let email = "placeholder@example.com"
        let subject = "SunHat Support Request"

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    HelpFAQView()
}
