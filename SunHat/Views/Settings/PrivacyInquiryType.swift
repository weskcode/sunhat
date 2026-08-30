//
//  PrivacyInquiryType.swift
//  SunHat
//

import SwiftUI

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

    /// The shared privacy-inquiry email template, used by both the "Send Email
    /// Inquiry" mail composer and the "Copy Email Template"/mailto fallback so
    /// there is exactly one place that generates this text.
    func emailBody(inquiryText: String, userEmail: String) -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? String(localized: "Unknown", comment: "Fallback app version when it cannot be read from the bundle")
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? String(localized: "Unknown", comment: "Fallback build number when it cannot be read from the bundle")

        let legalBasisLine = hasLegalBasis
            ? String(localized: "\nLegal Basis: \(legalBasis)\n", comment: "Line in the privacy-request email template naming the applicable GDPR/CCPA legal basis")
            : ""

        let inquiryLine = inquiryText.isEmpty ? String(localized: "[Please describe your privacy request]", comment: "Placeholder in the privacy-request email template when the user left the inquiry field empty") : inquiryText
        let emailLine = userEmail.isEmpty ? String(localized: "[Your email address]", comment: "Placeholder in the privacy-request email template when the user left the email field empty") : userEmail
        let dateLine = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        return String(localized: """
        Privacy Inquiry Type: \(displayName)
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
