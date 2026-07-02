//
//  SunHatNotificationCategoryRegistry.swift
//  SunHat
//
//  Created by Codex on 6/27/26.
//

import Foundation
@preconcurrency import UserNotifications

nonisolated enum SunHatNotificationActionIdentifier {
    static let complete = "COMPLETE_ACTION"
    static let snooze = "SNOOZE_ACTION"
    static let pause = "PAUSE_ACTION"
    static let view = "VIEW_ACTION"
    static let viewForecast = "VIEW_FORECAST"
    static let viewAlert = "VIEW_ALERT"
    static let postponeReminder = "POSTPONE_REMINDER"
    static let reschedule = "RESCHEDULE"
    static let startWorkout = "START_WORKOUT"
    static let skipToday = "SKIP_TODAY"
    static let waterPlants = "WATER_PLANTS"
    static let remindLater = "REMIND_LATER"
    static let startTask = "START_TASK"
    static let acknowledge = "ACKNOWLEDGE"
}

nonisolated enum SunHatNotificationCategoryIdentifier {
    static let weatherTrigger = "WEATHER_TRIGGER"
    static let weatherReminder = "WEATHER_REMINDER"
    static let dailySummary = "DAILY_SUMMARY"
    static let severeWeather = "SEVERE_WEATHER"
    static let reminderCompleted = "REMINDER_COMPLETED"
    static let exerciseReminder = "EXERCISE_REMINDER"
    static let gardeningReminder = "GARDENING_REMINDER"
    static let maintenanceReminder = "MAINTENANCE_REMINDER"
    static let criticalWeatherAlert = "CRITICAL_WEATHER_ALERT"
}

nonisolated enum SunHatNotificationCategoryRegistry {
    static func register(
        includeCriticalAlerts: Bool = false,
        center: UNUserNotificationCenter = .current()
    ) {
        center.setNotificationCategories(categories(includeCriticalAlerts: includeCriticalAlerts))
    }

    static func categories(includeCriticalAlerts: Bool = false) -> Set<UNNotificationCategory> {
        var categories: Set<UNNotificationCategory> = [
            weatherTriggerCategory,
            weatherReminderCategory,
            dailySummaryCategory,
            severeWeatherCategory,
            reminderCompletedCategory,
            exerciseReminderCategory,
            gardeningReminderCategory,
            maintenanceReminderCategory
        ]

        if includeCriticalAlerts {
            categories.insert(criticalWeatherAlertCategory)
        }

        return categories
    }

    private static var weatherTriggerCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.weatherTrigger,
            actions: [
                viewForecastAction,
                snoozeAction,
                pauseAction,
                completeAction
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var weatherReminderCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.weatherReminder,
            actions: [
                completeAction,
                snoozeAction,
                pauseAction,
                viewForecastAction
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var dailySummaryCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.dailySummary,
            actions: [viewForecastAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private static var severeWeatherCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.severeWeather,
            actions: [
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.viewAlert,
                    title: "View Alert",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.postponeReminder,
                    title: "Postpone Reminder",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var reminderCompletedCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.reminderCompleted,
            actions: [
                completeAction,
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.reschedule,
                    title: "Reschedule",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    private static var exerciseReminderCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.exerciseReminder,
            actions: [
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.startWorkout,
                    title: "Start Workout",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.skipToday,
                    title: "Skip Today",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var gardeningReminderCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.gardeningReminder,
            actions: [
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.waterPlants,
                    title: "Water Plants",
                    options: []
                ),
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.remindLater,
                    title: "Remind Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var maintenanceReminderCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.maintenanceReminder,
            actions: [
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.startTask,
                    title: "Start Task",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.postponeReminder,
                    title: "Postpone",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var criticalWeatherAlertCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: SunHatNotificationCategoryIdentifier.criticalWeatherAlert,
            actions: [
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.view,
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: SunHatNotificationActionIdentifier.acknowledge,
                    title: "Acknowledge",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static var completeAction: UNNotificationAction {
        UNNotificationAction(
            identifier: SunHatNotificationActionIdentifier.complete,
            title: "Mark Done",
            options: []
        )
    }

    private static var snoozeAction: UNNotificationAction {
        UNNotificationAction(
            identifier: SunHatNotificationActionIdentifier.snooze,
            title: "Snooze 2h",
            options: []
        )
    }

    private static var pauseAction: UNNotificationAction {
        UNNotificationAction(
            identifier: SunHatNotificationActionIdentifier.pause,
            title: "Pause This Reminder",
            options: []
        )
    }

    private static var viewForecastAction: UNNotificationAction {
        UNNotificationAction(
            identifier: SunHatNotificationActionIdentifier.viewForecast,
            title: "View Forecast",
            options: [.foreground]
        )
    }
}
