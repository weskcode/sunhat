//
//  AppSupportLinks.swift
//  SunHat
//

import Foundation

enum AppSupportLinks {
    static let supportEmail = "weskcode@duck.com"
    static let feedbackEmail = "weskcode@duck.com"
    static let privacyEmail = "weskcode@duck.com"

    static let privacyPolicyURL = URL(string: "https://sunhat.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://sunhat.app/terms")!

    static func mailURL(to email: String, subject: String, body: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email

        var queryItems = [
            URLQueryItem(name: "subject", value: subject)
        ]

        if let body {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }

        components.queryItems = queryItems
        return components.url
    }
}
