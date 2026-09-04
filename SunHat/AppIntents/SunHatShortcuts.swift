//
//  SunHatShortcuts.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/27/26.
//

import AppIntents
import Foundation

enum SunHatAppSection: String, AppEnum {
    case home
    case reminders
    case settings

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "SunHat Section")

    static let caseDisplayRepresentations: [SunHatAppSection: DisplayRepresentation] = [
        .home: "Home",
        .reminders: "Reminders",
        .settings: "Settings"
    ]

    var destination: SunHatIntentDestination {
        switch self {
        case .home:
            return .home
        case .reminders:
            return .reminders
        case .settings:
            return .settings
        }
    }
}

struct OpenSunHatSectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open SunHat"
    static let description = IntentDescription("Open SunHat to a specific section.")
    static let openAppWhenRun = true

    @Parameter(title: "Section")
    var section: SunHatAppSection

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$section) in SunHat")
    }

    init() {
        section = .home
    }

    init(section: SunHatAppSection) {
        self.section = section
    }

    func perform() async throws -> some IntentResult {
        SunHatIntentHandoff.store(section.destination)
        return .result()
    }
}

struct CreateWeatherReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Weather Reminder"
    static let description = IntentDescription("Open SunHat to create a new weather-triggered reminder.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SunHatIntentHandoff.store(.createReminder)
        return .result()
    }
}

struct ShowNextReadyReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Next Ready Reminder"
    static let description = IntentDescription("Open SunHat to the next reminder that is ready or closest to being ready.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SunHatIntentHandoff.store(.nextReady)
        return .result()
    }
}

struct CheckTodayRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Today's Weather Reminders"
    static let description = IntentDescription("Open SunHat to review today's weather reminders.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SunHatIntentHandoff.store(.reminders)
        return .result()
    }
}

struct PauseWeatherRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Weather Reminders"
    static let description = IntentDescription("Open SunHat settings to manage weather reminder notifications.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SunHatIntentHandoff.store(.settings)
        return .result()
    }
}

struct SunHatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateWeatherReminderIntent(),
            phrases: [
                "Create a weather reminder in \(.applicationName)",
                "Add a reminder in \(.applicationName)"
            ],
            shortTitle: "Create Reminder",
            systemImageName: "bell.badge"
        )

        AppShortcut(
            intent: ShowNextReadyReminderIntent(),
            phrases: [
                "Show my next ready reminder in \(.applicationName)",
                "What's ready in \(.applicationName)"
            ],
            shortTitle: "Next Ready",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: CheckTodayRemindersIntent(),
            phrases: [
                "Check today's reminders in \(.applicationName)",
                "Show today's reminders in \(.applicationName)"
            ],
            shortTitle: "Today's Reminders",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: OpenSunHatSectionIntent(section: .settings),
            phrases: [
                "Open settings in \(.applicationName)",
                "Show settings in \(.applicationName)"
            ],
            shortTitle: "Open Settings",
            systemImageName: "gearshape"
        )

        AppShortcut(
            intent: PauseWeatherRemindersIntent(),
            phrases: [
                "Pause weather reminders in \(.applicationName)",
                "Manage notifications in \(.applicationName)"
            ],
            shortTitle: "Manage Reminders",
            systemImageName: "pause.circle"
        )
    }
}
