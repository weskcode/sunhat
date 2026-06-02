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
    
    var body: some View {
        NavigationStack {
            Form {
                // Contact Information Section
                contactInfoSection
                
                // Inquiry Type Section
                inquiryTypeSection
                
                // Contact Details Section
                contactDetailsSection
                
                // Inquiry Form Section
                inquiryFormSection
                
                // Response Time Section
                responseTimeSection
                
                // Contact Actions Section
                contactActionsSection
            }
            .navigationTitle("Privacy Contact")
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
        }
    }
    
    // MARK: - Contact Information Section
    
    private var contactInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.badge.shield.checkmark")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Protection Officer")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("SunHat Privacy Team")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ContactDetailRow(
                        icon: "envelope.fill",
                        title: "Email",
                        value: "placeholder@example.com", // TODO: Replace with actual privacy email
                        isLink: true
                    ) {
                        openEmailClient()
                    }
                    
                    ContactDetailRow(
                        icon: "clock.fill",
                        title: "Response Time",
                        value: "Within 30 days",
                        isLink: false
                    )
                    
                    ContactDetailRow(
                        icon: "globe",
                        title: "Jurisdiction",
                        value: "United States & European Union",
                        isLink: false
                    )
                }
            }
            .padding(.vertical, 4)
            
        } header: {
            Label("Privacy Officer", systemImage: "person.fill.checkmark")
        } footer: {
            Text("Our Data Protection Officer handles all privacy-related inquiries and rights requests under GDPR and CCPA.")
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
                                .foregroundColor(type.color)
                            Text(type.displayName)
                                .font(.body)
                        }
                        Text(type.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.navigationLink)
            
            if selectedInquiryType.hasLegalBasis {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "scale.3d")
                            .foregroundColor(.blue)
                        Text("Legal Basis")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(selectedInquiryType.legalBasis)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
        } header: {
            Label("Type of Inquiry", systemImage: "questionmark.circle")
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
                .autocapitalization(.none)
            
        } header: {
            Label("Your Information", systemImage: "person")
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
            Label("Your Inquiry", systemImage: "text.bubble")
        } footer: {
            Text("Please provide details about your privacy request. Include any specific data or timeframes if relevant.")
        }
    }
    
    // MARK: - Response Time Section
    
    private var responseTimeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ResponseTimeCard(
                    title: "Standard Requests",
                    timeframe: "Within 30 days",
                    description: "GDPR and CCPA compliant response time",
                    icon: "calendar",
                    color: .blue
                )
                
                ResponseTimeCard(
                    title: "Complex Requests",
                    timeframe: "Up to 90 days",
                    description: "May require additional time for verification",
                    icon: "hourglass",
                    color: .orange
                )
                
                ResponseTimeCard(
                    title: "Urgent Security Issues",
                    timeframe: "Within 72 hours",
                    description: "Security or breach-related inquiries",
                    icon: "exclamationmark.shield",
                    color: .red
                )
            }
            
        } header: {
            Label("Response Times", systemImage: "clock")
        } footer: {
            Text("We're committed to responding to all privacy inquiries within the legally required timeframes.")
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
            
            Button("Visit Privacy Policy") {
                openPrivacyPolicy()
            }
            
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose how you'd like to contact us about your privacy inquiry.")
                
                if !canSendEmail {
                    Text("📧 Email app not configured. We'll copy the details to your clipboard.")
                        .font(.caption)
                        .foregroundColor(.orange)
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
           let url = URL(string: "mailto:placeholder@example.com?subject=\(encodedSubject)&body=\(encodedBody)") { // TODO: Replace with actual privacy email
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func copyEmailTemplate() {
        let template = generateEmailBody()
        UIPasteboard.general.string = template
        
        // Show confirmation (would need to implement proper toast/alert)
        print("Email template copied to clipboard")
    }
    
    private func generateEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return """
        Privacy Inquiry Type: \(selectedInquiryType.displayName)
        
        Legal Basis: \(selectedInquiryType.legalBasis)
        
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
        if let url = URL(string: "https://example.com/privacy") { // TODO: Replace with actual privacy policy URL
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Supporting Views

struct ContactDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let isLink: Bool
    let action: (() -> Void)?
    
    init(icon: String, title: String, value: String, isLink: Bool, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.isLink = isLink
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(isLink ? .blue : .primary)
            }
            
            Spacer()
            
            if isLink {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isLink {
                action?()
            }
        }
    }
}

struct ResponseTimeCard: View {
    let title: String
    let timeframe: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(timeframe)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.05))
        .cornerRadius(8)
    }
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
        composer.setToRecipients(["placeholder@example.com"]) // TODO: Replace with actual privacy email
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
        
        return """
        Privacy Inquiry Type: \(inquiryType.displayName)
        
        Legal Basis: \(inquiryType.legalBasis)
        
        Your Inquiry:
        \(inquiryText.isEmpty ? "[Please describe your privacy request]" : inquiryText)
        
        Contact Information:
        Email: \(userEmail.isEmpty ? "[Your email address]" : userEmail)
        
        App Information:
        - App: SunHat
        - Version: \(appVersion) (\(buildNumber))
        - Platform: iOS
        - Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
        
        Thank you for contacting our Data Protection Officer.
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
