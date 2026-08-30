//
//  MailComposeView.swift
//  SunHat
//

import SwiftUI
import MessageUI

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
        composer.setMessageBody(inquiryType.emailBody(inquiryText: inquiryText, userEmail: userEmail), isHTML: false)

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
