//
//  PrivacyContactView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import MessageUI

struct PrivacyContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedInquiryType: PrivacyInquiryType = .dataAccess
    @State private var inquiryText = ""
    @State private var userEmail = ""
    @State private var showingMailComposer = false
    @State private var canSendEmail = false
    @State private var statusAlert: PrivacyContactStatusAlert?

    private let urlOpener: SettingsOpening = ApplicationSettingsOpener()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Email SunHat about data access, correction, deletion, export, or another privacy question.")
                        .foregroundStyle(.secondary)
                }

                inquiryTypeSection
                contactDetailsSection
                inquiryFormSection
                responseCommitmentSection
                contactActionsSection
            }
            .navigationTitle("Contact About Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkEmailCapability()
            }
            .sheet(isPresented: $showingMailComposer) {
                if canSendEmail {
                    MailComposeView(
                        inquiryType: selectedInquiryType,
                        inquiryText: inquiryText,
                        userEmail: userEmail
                    )
                }
            }
            .alert(
                statusAlert?.title ?? "",
                isPresented: Binding(
                    get: { statusAlert != nil },
                    set: { if !$0 { statusAlert = nil } }
                ),
                presenting: statusAlert
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { alert in
                Text(alert.message)
            }
        }
    }

    // MARK: - Inquiry Type Section

    private var inquiryTypeSection: some View {
        Section {
            Picker("Inquiry Type", selection: $selectedInquiryType) {
                ForEach(PrivacyInquiryType.allCases, id: \.self) { type in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundStyle(type.color)
                            Text(type.displayName)
                                .font(.body)
                        }
                        Text(type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.navigationLink)

        } header: {
            Text("Type of Inquiry")
        } footer: {
            Text("Select the type of privacy inquiry or request you'd like to make.")
        }
    }

    // MARK: - Contact Details Section

    private var contactDetailsSection: some View {
        Section {
            TextField("Your Email (optional)", text: $userEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

        } header: {
            Text("Your Information")
        } footer: {
            Text("Providing your email helps us respond more efficiently. This is optional but recommended for faster resolution.")
        }
    }

    // MARK: - Inquiry Form Section

    private var inquiryFormSection: some View {
        Section {
            TextField(
                "Describe your inquiry...",
                text: $inquiryText,
                axis: .vertical
            )
            .lineLimit(5...10)

        } header: {
            Text("Your Inquiry")
        } footer: {
            Text("Please provide details about your privacy request. Include any specific data or timeframes if relevant.")
        }
    }

    // MARK: - Response Commitment Section

    private var responseCommitmentSection: some View {
        Section {
            LabeledContent("Response Time", value: "Within 30 days")

            if selectedInquiryType.hasLegalBasis {
                LabeledContent("Legal Basis", value: selectedInquiryType.legalBasis)
            }
        } footer: {
            Text("We respond to privacy inquiries within 30 days, as required by GDPR and CCPA.")
        }
    }

    // MARK: - Contact Actions Section

    private var contactActionsSection: some View {
        Section {
            Button("Send Email Inquiry") {
                if canSendEmail {
                    showingMailComposer = true
                } else {
                    openEmailClient()
                }
            }
            .disabled(inquiryText.isEmpty)

            Button("Copy Email Template") {
                copyEmailTemplate()
            }

        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose how you'd like to contact us about your privacy inquiry.")

                if !canSendEmail {
                    Text("Mail is not configured on this device. You can copy the message and send it from another email app.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func checkEmailCapability() {
        canSendEmail = MFMailComposeViewController.canSendMail()
    }

    private func openEmailClient() {
        let subject = String(localized: "Privacy Inquiry - \(selectedInquiryType.displayName)", comment: "Pre-filled subject line of the privacy-request email the app composes")
        let body = selectedInquiryType.emailBody(inquiryText: inquiryText, userEmail: userEmail)

        if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mailto:\(AppSupportLinks.privacyEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
            Task {
                let opened = await urlOpener.open(url)
                if opened == false {
                    statusAlert = PrivacyContactStatusAlert(
                        title: String(localized: "Couldn't Open Mail", comment: "Alert title"),
                        message: String(localized: "Set up a mail account, or email \(AppSupportLinks.privacyEmail) directly. You can also use Copy Email Template.", comment: "Alert message")
                    )
                }
            }
        }
    }

    private func copyEmailTemplate() {
        let template = selectedInquiryType.emailBody(inquiryText: inquiryText, userEmail: userEmail)
        UIPasteboard.general.string = template

        statusAlert = PrivacyContactStatusAlert(
            title: String(localized: "Copied", comment: "Alert title after copying the email template to the clipboard"),
            message: String(localized: "The email template was copied to your clipboard. Paste it into any email to \(AppSupportLinks.privacyEmail).", comment: "Alert message")
        )
    }

}

/// Typed alert state for `PrivacyContactView`, one alert surface for
/// open-failure and clipboard-confirmation messages.
private struct PrivacyContactStatusAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Preview

#Preview {
    PrivacyContactView()
}
