//
//  BackgroundWeatherManager.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import UIKit
import BackgroundTasks
import SwiftData
import CoreLocation
import UserNotifications
import Combine
import os

@MainActor
final class BackgroundWeatherManager: ObservableObject {
    static let shared = BackgroundWeatherManager()

    private let taskIdentifier = "org.wesley.sunhat.weather-refresh"
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "BackgroundWeatherManager")

    @Published var isBackgroundRefreshEnabled = false
    @Published var lastBackgroundRefresh: Date?
    @Published var backgroundRefreshCount = 0

    private(set) var isBackgroundTaskRegistered = false

    private var modelContainer: ModelContainer?

    private init() {
        registerBackgroundTask()
        updateBackgroundRefreshStatus()
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        logger.info("BackgroundWeatherManager configured with shared ModelContainer")
    }

    /// Registers the BG refresh launch handler. Safe to call more than once —
    /// a second `BGTaskScheduler.register` for the same identifier raises
    /// `NSInternalInconsistencyException`, so duplicates are ignored.
    /// Returns whether this call performed the registration.
    @discardableResult
    func registerBackgroundTask() -> Bool {
        guard !isBackgroundTaskRegistered else {
            logger.warning("Background task already registered — ignoring duplicate registration")
            return false
        }
        isBackgroundTaskRegistered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: self.taskIdentifier, using: nil) { task in
            Task {
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }

                await self.handleBackgroundTask(refreshTask)
            }
        }
        logger.info("Registered background task: \(self.taskIdentifier)")
        return true
    }
    
    private func updateBackgroundRefreshStatus() {
        Task {
            let status = await MainActor.run { UIApplication.shared.backgroundRefreshStatus }
            await MainActor.run {
                self.isBackgroundRefreshEnabled = (status == .available)
            }
        }
    }
    
    /// Schedules the next background refresh. Returns whether a request was
    /// actually submitted — `false` when background refresh is unavailable
    /// (user disabled it / Low Power Mode) or submission fails, in which case
    /// the app falls back to foreground-only refreshes.
    @discardableResult
    func scheduleBackgroundRefresh() -> Bool {
        guard isBackgroundRefreshEnabled else {
            logger.warning("Background refresh is disabled — relying on foreground refresh only")
            return false
        }

        let request = BGAppRefreshTaskRequest(identifier: self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background weather refresh for 15 minutes from now")
            return true
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
            return false
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        logger.info("Starting background weather refresh task")
        let startTime = Date()
        backgroundRefreshCount += 1

        let workTask = Task {
            await WeatherService.shared.handleBackgroundRefresh()
            await checkTriggeredConditions()
        }

        task.expirationHandler = {
            self.logger.warning("Background task expired")
            workTask.cancel()
        }

        await workTask.value

        lastBackgroundRefresh = Date()
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Background refresh completed in \(duration) seconds")
        scheduleBackgroundRefresh()
        task.setTaskCompleted(success: !workTask.isCancelled)
    }
    
    private func checkTriggeredConditions() async {
        logger.debug("Checking for triggered weather conditions")
        
        guard let modelContext = await getModelContext() else {
            logger.error("No model context available for condition checking")
            return
        }
        
        // Fetch all reminders and filter programmatically due to MainActor isolation
        let descriptor: FetchDescriptor<WeatherReminder> = FetchDescriptor<WeatherReminder>()
        
        do {
            let fetchedReminders: [WeatherReminder] = try modelContext.fetch(descriptor)

            // Only consider reminders that can actually fire right now. `canTrigger`
            // encapsulates the active/paused/completed/snoozed/scheduled/max-trigger
            // checks AND the persistent cooldown (lastTriggered + cooldownPeriodHours).
            // Gating here prevents re-notifying the same reminder on every background
            // refresh while its condition stays true, and the cooldown survives app
            // launches because it is stored in SwiftData. It also avoids fetching
            // weather for reminders that are in cooldown.
            let eligibleReminders = fetchedReminders.filter { $0.canTrigger }

            logger.debug("Checking \(eligibleReminders.count) eligible reminders (filtered from \(fetchedReminders.count) total)")

            var triggeredCount = 0

            for reminder in eligibleReminders {
                if await evaluateReminderCondition(reminder) {
                   await sendNotificationForReminder(reminder)
                   reminder.trigger(with: nil)
                   triggeredCount += 1
               }
            }
            
            if triggeredCount > 0 {
                try modelContext.save()
                logger.info("Triggered \(triggeredCount) reminders")
            }
            
        } catch {
            logger.error("Failed to check triggered conditions: \(error)")
        }
    }
    
    private func evaluateReminderCondition(_ reminder: WeatherReminder) async -> Bool {
        guard let location = reminder.location?.clLocation,
              let condition = reminder.triggerCondition else {
            return false
        }
        
        do {
            let weatherData = try await WeatherService.shared.fetchCurrentWeather(for: location)
            return weatherData.evaluateCondition(condition)
        } catch {
            logger.warning("Failed to evaluate condition for reminder \(reminder.id): \(error)")
            return false
        }
    }
    
    private func sendNotificationForReminder(_ reminder: WeatherReminder) async {
        guard let notificationConfig = reminder.notificationConfig else { return }
        
        let content = notificationConfig.notificationContent
        content.title = reminder.displayTitle
        content.body = reminder.shortDescription
        
        // Add weather context if enabled
        if notificationConfig.includeWeatherSummary,
           let location = reminder.location?.clLocation {
            do {
                let weatherData = try await WeatherService.shared.fetchCurrentWeather(for: location)
                content.body += "\n\nCurrent: \(Int(weatherData.temperature))° • \(weatherData.weatherDescription.capitalized)"
            } catch {
                logger.warning("Failed to add weather context to notification: \(error)")
            }
        }
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Sent notification for reminder: \(reminder.displayTitle)")
            
            // Update notification tracking
            notificationConfig.lastDelivered = Date()
            notificationConfig.deliveryCount += 1
            notificationConfig.successfulDeliveries += 1
            
        } catch {
            logger.error("Failed to send notification for reminder \(reminder.id): \(error)")
        }
    }
    
    private func getModelContext() async -> ModelContext? {
        guard let modelContainer else {
            logger.error("ModelContainer not configured — call configure(modelContainer:) from the app entry point")
            return nil
        }
        return ModelContext(modelContainer)
    }
    
    // MARK: - Public Interface
    
    func requestBackgroundRefreshPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                scheduleBackgroundRefresh()
            }
            return granted
        } catch {
            logger.error("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func manualRefresh() async {
        logger.info("Starting manual weather refresh")
        await WeatherService.shared.handleBackgroundRefresh()
        await checkTriggeredConditions()
        lastBackgroundRefresh = Date()
    }
    
    func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.taskIdentifier)
        logger.info("Cancelled scheduled background refresh")
    }
}

// MARK: - Background Refresh Status Extension

// Note: BGBackgroundRefreshStatus extension removed - use UIApplication.backgroundRefreshStatus instead
