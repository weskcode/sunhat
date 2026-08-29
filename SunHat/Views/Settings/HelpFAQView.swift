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
    @State private var isShowingMailFailure = false

    private let urlOpener: SettingsOpening = ApplicationSettingsOpener()

    private let faqItems = [
        FAQItem(
            question: String(localized: "How do weather-triggered reminders work?", comment: "FAQ question"),
            answer: String(localized: "SunHat monitors weather conditions and sends you notifications when the temperature, humidity, or other conditions match your preferences. For example, you can set a reminder to water your garden when it hasn't rained and the temperature is above 70°F.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "Why isn't my reminder triggering?", comment: "FAQ question"),
            answer: String(localized: "Make sure notifications are enabled in Settings, your reminder is active, and the weather conditions match your trigger settings. Also check that you're not in quiet hours and haven't reached your daily notification limit.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "How accurate is the weather data?", comment: "FAQ question"),
            answer: String(localized: "We use Apple WeatherKit as our data source. Weather data is typically accurate for the next 24-48 hours, with longer forecasts being less precise.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "Can I use the app without location access?", comment: "FAQ question"),
            answer: String(localized: "Location access is required for current-location weather reminders. You can also save manual locations. Coordinates are sent only to enabled weather providers to fetch forecasts.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "Is my data synced to iCloud?", comment: "FAQ question"),
            answer: String(localized: "Not yet. Your reminders and preferences are stored locally on this device. iCloud sync is planned for a future update.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "What's the difference between temperature and 'feels like'?", comment: "FAQ question"),
            answer: String(localized: "Temperature is the actual air temperature, while 'feels like' accounts for humidity and wind chill to represent what the temperature actually feels like to your body.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "Can I set reminders for multiple locations?", comment: "FAQ question"),
            answer: String(localized: "Yes. Each reminder stores its own location: use your current location or pick a city when creating or editing a reminder.", comment: "FAQ answer")
        ),
        FAQItem(
            question: String(localized: "How do I delete a reminder?", comment: "FAQ question"),
            answer: String(localized: "Swipe left on any reminder in the list, or open the reminder and choose Delete from its detail screen.", comment: "FAQ answer")
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
            .alert("Couldn't Open Mail", isPresented: $isShowingMailFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Set up a mail account, or email \(AppSupportLinks.supportEmail) directly.")
            }
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
        let email = AppSupportLinks.supportEmail
        let subject = "SunHat Support Request"

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            Task {
                let opened = await urlOpener.open(url)
                if opened == false {
                    isShowingMailFailure = true
                }
            }
        }
    }
}

#Preview {
    HelpFAQView()
}
