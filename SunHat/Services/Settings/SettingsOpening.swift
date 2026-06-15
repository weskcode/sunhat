//
//  SettingsOpening.swift
//  SunHat
//
//  Created by Codex on 6/2/26.
//

import Foundation
import UIKit

@MainActor
protocol SettingsOpening: AnyObject {
    /// Opens the URL and reports whether the system could handle it (e.g. `false`
    /// when a `mailto:` link can't open because no mail account is configured).
    @discardableResult
    func open(_ url: URL) async -> Bool
}

@MainActor
final class ApplicationSettingsOpener: SettingsOpening {
    @discardableResult
    func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}
