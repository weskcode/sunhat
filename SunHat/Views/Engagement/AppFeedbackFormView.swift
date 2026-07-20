//
//  AppFeedbackFormView.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct AppFeedbackFormView: View {
    @Binding var feedbackText: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 180)
                            .accessibilityLabel("Feedback")

                        if feedbackText.isEmpty {
                            Text("What could make SunHat better?")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                } footer: {
                    Text("Your feedback opens in Mail so you can review it before sending.")
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSubmit()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
