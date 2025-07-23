//
//  SettingsSubViews.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    privacyPolicyContent
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                .fontWeight(.bold)
            
            Text("hatti is designed with your privacy in mind. Here's how we handle your data:")
                .font(.body)
            
            privacySection(
                title: "Location Data",
                content: "We only access your location to provide relevant weather information. Location data is never shared with third parties and is only used to fetch weather conditions for your area."
            )
            
            privacySection(
                title: "Weather Data",
                content: "Weather information is fetched from reliable sources and cached locally on your device for better performance. This data is not transmitted to our servers."
            )
            
            privacySection(
                title: "Reminders & Preferences",
                content: "Your reminders and app preferences are stored locally on your device and synced via iCloud when enabled. We never have access to your personal reminder content."
            )
            
            privacySection(
                title: "Analytics",
                content: "We do not collect any personal analytics or tracking data. The app works entirely locally with optional iCloud sync under your control."
            )
            
            privacySection(
                title: "Third-Party Services",
                content: "Weather data is provided by Apple WeatherKit and OpenWeatherMap. Please review their privacy policies for information on how they handle data."
            )
            
            Text("Contact Us")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 20)
            
            Text("If you have any questions about this privacy policy, please contact us at privacy@hatti.app")
                .font(.body)
            
            Text("Last updated: January 20, 2025")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
        }
    }
    
    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Data Analytics View

struct DataAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = true
    @State private var performanceDataEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Collection")
                            .font(.headline)
                        
                        Text("hatti respects your privacy. You have full control over what data is shared to help improve the app.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Analytics") {
                    Toggle("Share Analytics", isOn: $analyticsEnabled)
                    
                    if analyticsEnabled {
                        Text("Help improve hatti by sharing anonymous usage statistics.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Diagnostics") {
                    Toggle("Crash Reports", isOn: $crashReportingEnabled)
                    
                    Text("Automatically send crash reports to help us fix bugs and improve stability.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Performance Data", isOn: $performanceDataEnabled)
                    
                    if performanceDataEnabled {
                        Text("Share anonymous performance metrics to help optimize the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What We Don't Collect")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            bulletPoint("Personal reminder content")
                            bulletPoint("Precise location data")
                            bulletPoint("Contact information")
                            bulletPoint("Photos or personal files")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Data & Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
            Spacer()
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App icon and info
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
                        
                        Text("hatti")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Weather-Smart Reminders")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Mission statement
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Our Mission")
                            .font(.headline)
                        
                        Text("hatti helps you plan your activities around the weather. Get reminded when conditions are perfect for gardening, exercise, outdoor dining, and more.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Acknowledgments
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
                    
                    // Open source notice
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Open Source")
                            .font(.headline)
                        
                        Text("hatti is built with love using Apple's open source Swift language and modern iOS frameworks.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Contact
                    VStack(spacing: 12) {
                        Text("Made with ❤️ by the hatti Team")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        
                        Text("© 2025 hatti. All rights reserved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func acknowledgmentRow(service: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(service)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Help FAQ View

struct HelpFAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<Int> = []
    
    private let faqItems = [
        FAQItem(
            question: "How do weather-triggered reminders work?",
            answer: "hatti monitors weather conditions and sends you notifications when the temperature, humidity, or other conditions match your preferences. For example, you can set a reminder to water your garden when it hasn't rained and the temperature is above 70°F."
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
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequently Asked Questions")
                            .font(.headline)
                        
                        Text("Find answers to common questions about using hatti.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
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
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    } label: {
                        Text(item.question)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Section {
                    VStack(spacing: 12) {
                        Text("Still need help?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button("Contact Support") {
                            sendSupportEmail()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendSupportEmail() {
        let email = "support@hatti.app"
        let subject = "hatti Support Request"
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - FAQ Item Model

struct FAQItem {
    let question: String
    let answer: String
}

// MARK: - Previews

#Preview("Privacy Policy") {
    PrivacyPolicyView()
}

#Preview("Data Analytics") {
    DataAnalyticsView()
}

#Preview("About") {
    AboutView()
}

#Preview("Help FAQ") {
    HelpFAQView()
}