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
        let subject = "Privacy Inquiry - \(selectedInquiryType.displayName)"
        let body = generateEmailBody()
        
        if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mailto:\(AppSupportLinks.privacyEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
            Task {
                let opened = await urlOpener.open(url)
                if opened == false {
                    statusAlert = PrivacyContactStatusAlert(
                        title: "Couldn't Open Mail",
                        message: "Set up a mail account, or email \(AppSupportLinks.privacyEmail) directly. You can also use Copy Email Template."
                    )
                }
            }
        }
    }

    private func copyEmailTemplate() {
        let template = generateEmailBody()
        UIPasteboard.general.string = template

        statusAlert = PrivacyContactStatusAlert(
            title: "Copied",
            message: "The email template was copied to your clipboard. Paste it into any email to \(AppSupportLinks.privacyEmail)."
        )
    }
    
    private func generateEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let legalBasisLine = selectedInquiryType.hasLegalBasis
            ? "\nLegal Basis: \(selectedInquiryType.legalBasis)\n"
            : ""

        return """
        Privacy Inquiry Type: \(selectedInquiryType.displayName)
        \(legalBasisLine)
        Your Inquiry:
        \(inquiryText.isEmpty ? "[Please describe your privacy request]" : inquiryText)

        Contact Information:
        Email: \(userEmail.isEmpty ? "[Your email address]" : userEmail)

        App Information:
        - App: SunHat
        - Version: \(appVersion) (\(buildNumber))
        - Platform: iOS
        - Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))

        Thank you for contacting our Data Protection Officer. We will respond within 30 days as required by law.
        """
    }
    
    private func openPrivacyPolicy() {
        Task {
            let opened = await urlOpener.open(AppSupportLinks.privacyPolicyURL)
            if opened == false {
                statusAlert = PrivacyContactStatusAlert(
                    title: "Couldn't Open",
                    message: "Visit \(AppSupportLinks.privacyPolicyURL.absoluteString) in a browser."
                )
            }
        }
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
        composer.setSubject("Privacy Inquiry - \(inquiryType.displayName)")
        
        let body = generateEmailBody()
        composer.setMessageBody(body, isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let legalBasisLine = inquiryType.hasLegalBasis
            ? "\nLegal Basis: \(inquiryType.legalBasis)\n"
            : ""

        return """
        Privacy Inquiry Type: \(inquiryType.displayName)
        \(legalBasisLine)
        Your Inquiry:
        \(inquiryText.isEmpty ? "[Please describe your privacy request]" : inquiryText)

        Contact Information:
        Email: \(userEmail.isEmpty ? "[Your email address]" : userEmail)

        App Information:
        - App: SunHat
        - Version: \(appVersion) (\(buildNumber))
        - Platform: iOS
        - Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))

        Thank you for contacting our Data Protection Officer. We will respond within 30 days as required by law.
        """
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
            return "Access My Data"
        case .dataPortability:
            return "Data Portability"
        case .dataDeletion:
            return "Delete My Data"
        case .dataCorrection:
            return "Correct My Data"
        case .dataProcessing:
            return "Data Processing Inquiry"
        case .marketingOptOut:
            return "Marketing Opt-Out"
        case .securityConcern:
            return "Security Concern"
        case .generalInquiry:
            return "General Privacy Question"
        }
    }
    
    var description: String {
        switch self {
        case .dataAccess:
            return "Request a copy of all data we have about you"
        case .dataPortability:
            return "Export your data in a machine-readable format"
        case .dataDeletion:
            return "Request deletion of all your personal data"
        case .dataCorrection:
            return "Update or correct your personal information"
        case .dataProcessing:
            return "Questions about how we process your data"
        case .marketingOptOut:
            return "Opt out of marketing communications"
        case .securityConcern:
            return "Report a security or privacy concern"
        case .generalInquiry:
            return "Other privacy-related questions"
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
    
    var legalBasis: String {
        switch self {
        case .dataAccess:
            return "GDPR Article 15 (Right of Access), CCPA Section 1798.110"
        case .dataPortability:
            return "GDPR Article 20 (Right to Data Portability)"
        case .dataDeletion:
            return "GDPR Article 17 (Right to Erasure), CCPA Section 1798.105"
        case .dataCorrection:
            return "GDPR Article 16 (Right to Rectification)"
        default:
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyContactView()
}
