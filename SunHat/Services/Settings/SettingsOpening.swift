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
    func open(_ url: URL)
}

@MainActor
final class ApplicationSettingsOpener: SettingsOpening {
    func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
