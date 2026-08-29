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
        let body = generateEmailBody()
        
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
        let template = generateEmailBody()
        UIPasteboard.general.string = template

        statusAlert = PrivacyContactStatusAlert(
            title: String(localized: "Copied", comment: "Alert title after copying the email template to the clipboard"),
            message: String(localized: "The email template was copied to your clipboard. Paste it into any email to \(AppSupportLinks.privacyEmail).", comment: "Alert message")
        )
    }
    
    private func generateEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? String(localized: "Unknown", comment: "Fallback app version when it cannot be read from the bundle")
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? String(localized: "Unknown", comment: "Fallback build number when it cannot be read from the bundle")

        let legalBasisLine = selectedInquiryType.hasLegalBasis
            ? String(localized: "\nLegal Basis: \(selectedInquiryType.legalBasis)\n", comment: "Line in the privacy-request email template naming the applicable GDPR/CCPA legal basis")
            : ""

        let inquiryLine = inquiryText.isEmpty ? String(localized: "[Please describe your privacy request]", comment: "Placeholder in the privacy-request email template when the user left the inquiry field empty") : inquiryText
        let emailLine = userEmail.isEmpty ? String(localized: "[Your email address]", comment: "Placeholder in the privacy-request email template when the user left the email field empty") : userEmail
        let dateLine = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        return String(localized: """
        Privacy Inquiry Type: \(selectedInquiryType.displayName)
        \(legalBasisLine)
        Your Inquiry:
        \(inquiryLine)

        Contact Information:
        Email: \(emailLine)

        App Information:
        - App: SunHat
        - Version: \(appVersion) (\(buildNumber))
        - Platform: iOS
        - Date: \(dateLine)

        Thank you for contacting our Data Protection Officer. We will respond within 30 days as required by law.
        """, comment: "Pre-filled body of the GDPR/CCPA privacy-request email the app composes; keep the field labels (Privacy Inquiry Type, Your Inquiry, Contact Information, Email, App Information, App, Version, Platform, Date) and the '- ' bullet formatting")
    }
    
}

/// Typed alert state for `PrivacyContactView`, one alert surface for
/// open-failure and clipboard-confirmation messages.
private struct PrivacyContactStatusAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let inquiryType: PrivacyInquiryType
    let inquiryText: String
    let userEmail: String
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([AppSupportLinks.privacyEmail])
        composer.setSubject(String(localized: "Privacy Inquiry - \(inquiryType.displayName)", comment: "Pre-filled subject line of the privacy-request email the app composes"))
        
        let body = generateEmailBody()
        composer.setMessageBody(body, isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? String(localized: "Unknown", comment: "Fallback app version when it cannot be read from the bundle")
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? String(localized: "Unknown", comment: "Fallback build number when it cannot be read from the bundle")

        let legalBasisLine = inquiryType.hasLegalBasis
            ? String(localized: "\nLegal Basis: \(inquiryType.legalBasis)\n", comment: "Line in the privacy-request email template naming the applicable GDPR/CCPA legal basis")
            : ""

        let inquiryLine = inquiryText.isEmpty ? String(localized: "[Please describe your privacy request]", comment: "Placeholder in the privacy-request email template when the user left the inquiry field empty") : inquiryText
        let emailLine = userEmail.isEmpty ? String(localized: "[Your email address]", comment: "Placeholder in the privacy-request email template when the user left the email field empty") : userEmail
        let dateLine = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        return String(localized: """
        Privacy Inquiry Type: \(inquiryType.displayName)
        \(legalBasisLine)
        Your Inquiry:
        \(inquiryLine)

        Contact Information:
        Email: \(emailLine)

        App Information:
        - App: SunHat
        - Version: \(appVersion) (\(buildNumber))
        - Platform: iOS
        - Date: \(dateLine)

        Thank you for contacting our Data Protection Officer. We will respond within 30 days as required by law.
        """, comment: "Pre-filled body of the GDPR/CCPA privacy-request email the app composes; keep the field labels (Privacy Inquiry Type, Your Inquiry, Contact Information, Email, App Information, App, Version, Platform, Date) and the '- ' bullet formatting")
    }

    class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        @MainActor
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Supporting Types

enum PrivacyInquiryType: CaseIterable {
    case dataAccess
    case dataPortability
    case dataDeletion
    case dataCorrection
    case dataProcessing
    case marketingOptOut
    case securityConcern
    case generalInquiry
    
    var displayName: String {
        switch self {
        case .dataAccess:
            return String(localized: "Access My Data", comment: "Privacy inquiry type")
        case .dataPortability:
            return String(localized: "Data Portability", comment: "Privacy inquiry type")
        case .dataDeletion:
            return String(localized: "Delete My Data", comment: "Privacy inquiry type")
        case .dataCorrection:
            return String(localized: "Correct My Data", comment: "Privacy inquiry type")
        case .dataProcessing:
            return String(localized: "Data Processing Inquiry", comment: "Privacy inquiry type")
        case .marketingOptOut:
            return String(localized: "Marketing Opt-Out", comment: "Privacy inquiry type")
        case .securityConcern:
            return String(localized: "Security Concern", comment: "Privacy inquiry type")
        case .generalInquiry:
            return String(localized: "General Privacy Question", comment: "Privacy inquiry type")
        }
    }

    var description: String {
        switch self {
        case .dataAccess:
            return String(localized: "Request a copy of all data we have about you", comment: "Privacy inquiry type description")
        case .dataPortability:
            return String(localized: "Export your data in a machine-readable format", comment: "Privacy inquiry type description")
        case .dataDeletion:
            return String(localized: "Request deletion of all your personal data", comment: "Privacy inquiry type description")
        case .dataCorrection:
            return String(localized: "Update or correct your personal information", comment: "Privacy inquiry type description")
        case .dataProcessing:
            return String(localized: "Questions about how we process your data", comment: "Privacy inquiry type description")
        case .marketingOptOut:
            return String(localized: "Opt out of marketing communications", comment: "Privacy inquiry type description")
        case .securityConcern:
            return String(localized: "Report a security or privacy concern", comment: "Privacy inquiry type description")
        case .generalInquiry:
            return String(localized: "Other privacy-related questions", comment: "Privacy inquiry type description")
        }
    }
    
    var icon: String {
        switch self {
        case .dataAccess:
            return "eye.fill"
        case .dataPortability:
            return "square.and.arrow.up"
        case .dataDeletion:
            return "trash.fill"
        case .dataCorrection:
            return "pencil"
        case .dataProcessing:
            return "gearshape.fill"
        case .marketingOptOut:
            return "envelope.badge.fill"
        case .securityConcern:
            return "exclamationmark.shield.fill"
        case .generalInquiry:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .dataAccess:
            return .blue
        case .dataPortability:
            return .green
        case .dataDeletion:
            return .red
        case .dataCorrection:
            return .orange
        case .dataProcessing:
            return .purple
        case .marketingOptOut:
            return .yellow
        case .securityConcern:
            return .red
        case .generalInquiry:
            return .gray
        }
    }
    
    var hasLegalBasis: Bool {
        switch self {
        case .dataAccess, .dataPortability, .dataDeletion, .dataCorrection:
            return true
        default:
            return false
        }
    }
    
    // NOTE (localization): legal citation numbers/section references (GDPR Article N,
    // CCPA Section N) are kept verbatim across locales by design; only the parenthetical
    // plain-language description of the right is translated. Flagged for legal review of
    // whether Spanish-market users should instead see the EU's Spanish-language RGPD
    // naming convention.
    var legalBasis: String {
        switch self {
        case .dataAccess:
            return String(localized: "GDPR Article 15 (Right of Access), CCPA Section 1798.110", comment: "Legal citation; keep 'GDPR Article 15' and 'CCPA Section 1798.110' untranslated, translate only '(Right of Access)'")
        case .dataPortability:
            return String(localized: "GDPR Article 20 (Right to Data Portability)", comment: "Legal citation; keep 'GDPR Article 20' untranslated, translate only '(Right to Data Portability)'")
        case .dataDeletion:
            return String(localized: "GDPR Article 17 (Right to Erasure), CCPA Section 1798.105", comment: "Legal citation; keep 'GDPR Article 17' and 'CCPA Section 1798.105' untranslated, translate only '(Right to Erasure)'")
        case .dataCorrection:
            return String(localized: "GDPR Article 16 (Right to Rectification)", comment: "Legal citation; keep 'GDPR Article 16' untranslated, translate only '(Right to Rectification)'")
        default:
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyContactView()
}
