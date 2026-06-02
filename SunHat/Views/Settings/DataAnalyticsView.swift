//
//  DataAnalyticsView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct DataAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = true
    @State private var performanceDataEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Collection")
                            .font(.headline)

                        Text("SunHat respects your privacy. You have full control over what data is shared to help improve the app.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Analytics") {
                    Toggle("Share Analytics", isOn: $analyticsEnabled)

                    if analyticsEnabled {
                        Text("Help improve SunHat by sharing anonymous usage statistics.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Diagnostics") {
                    Toggle("Crash Reports", isOn: $crashReportingEnabled)

                    Text("Automatically send crash reports to help us fix bugs and improve stability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Performance Data", isOn: $performanceDataEnabled)

                    if performanceDataEnabled {
                        Text("Share anonymous performance metrics to help optimize the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Data & Analytics")
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

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
            Spacer()
        }
    }
}

#Preview {
    DataAnalyticsView()
}
