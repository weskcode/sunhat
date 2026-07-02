//
//  SunHatIntentHandoff.swift
//  SunHat
//
//  Created by Codex on 6/27/26.
//

import Foundation

nonisolated enum SunHatIntentDestination: String, Sendable {
    case home
    case reminders
    case createReminder
    case nextReady
    case settings
}

nonisolated enum SunHatIntentHandoff {
    private static let pendingDestinationKey = "pendingIntentDestination"
    private static let appGroupIdentifier = "group.org.wesley.sunhat"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func store(_ destination: SunHatIntentDestination) {
        defaults.set(destination.rawValue, forKey: pendingDestinationKey)
    }

    static func consumePendingDestination() -> SunHatIntentDestination? {
        guard
            let rawValue = defaults.string(forKey: pendingDestinationKey),
            let destination = SunHatIntentDestination(rawValue: rawValue)
        else {
            return nil
        }

        defaults.removeObject(forKey: pendingDestinationKey)
        return destination
    }
}
