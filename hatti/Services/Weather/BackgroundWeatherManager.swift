//
//  BackgroundWeatherManager.swift
//  hatti
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
    
    private let taskIdentifier = "com.hatti.app.weather-refresh"
    private let logger = Logger(subsystem: "com.hatti.app", category: "BackgroundWeatherManager")
    
    @Published var isBackgroundRefreshEnabled = false
    @Published var lastBackgroundRefresh: Date?
    @Published var backgroundRefreshCount = 0
    
    private init() {
        registerBackgroundTask()
        updateBackgroundRefreshStatus()
    }
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: self.taskIdentifier, using: nil) { task in
            Task {
                await self.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
        logger.info("Registered background task: \(self.taskIdentifier)")
    }
    
    private func updateBackgroundRefreshStatus() {
        Task {
            let status = await MainActor.run { UIApplication.shared.backgroundRefreshStatus }
            await MainActor.run {
                self.isBackgroundRefreshEnabled = (status == .available)
            }
        }
    }
    
    func scheduleBackgroundRefresh() {
        guard isBackgroundRefreshEnabled else {
            logger.warning("Background refresh is disabled")
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background weather refresh for 15 minutes from now")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        logger.info("Starting background weather refresh task")
        let startTime = Date()
        backgroundRefreshCount += 1
        // Set up task completion
        task.expirationHandler = {
            self.logger.warning("Background task expired")
            task.setTaskCompleted(success: false)
        }
        // Perform the background refresh
        await WeatherService.shared.handleBackgroundRefresh()
        // Check for triggered conditions and send notifications
        await checkTriggeredConditions()
        lastBackgroundRefresh = Date()
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Background refresh completed successfully in \(duration) seconds")
        // Schedule next refresh
        scheduleBackgroundRefresh()
        task.setTaskCompleted(success: true)
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
            
            // Filter reminders using MainActor-isolated properties
            let activeReminders = await withTaskGroup(of: WeatherReminder?.self) { group in
                for reminder in fetchedReminders {
                    group.addTask {
                        let isActive = await MainActor.run { reminder.isActive }
                        let isCompleted = await MainActor.run { reminder.isCompleted }
                        let isPaused = await MainActor.run { reminder.isPaused }
                        
                        if isActive && !isCompleted && !isPaused {
                            return reminder
                        }
                        return nil
                    }
                }
                
                var results: [WeatherReminder] = []
                for await reminder in group {
                    if let reminder = reminder {
                        results.append(reminder)
                    }
                }
                return results
            }
            
            logger.debug("Checking \(activeReminders.count) active reminders (filtered from \(fetchedReminders.count) total)")
            
            var triggeredCount = 0
            
            for reminder in activeReminders {
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
        // This would typically be injected or accessed through the app's container
        // For now, we'll create a temporary context
        do {
            let schema = Schema([
                WeatherReminder.self,
                TriggerCondition.self,
                LocationData.self,
                WeatherData.self,
                ForecastDay.self,
                NotificationConfig.self,
                ReminderHistory.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return ModelContext(container)
            
        } catch {
            logger.error("Failed to create model context: \(error)")
            return nil
        }
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
    
    func getBackgroundRefreshStatus() -> String {
        return "Available" // Placeholder - would need proper implementation
    }
    
    func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.taskIdentifier)
        logger.info("Cancelled scheduled background refresh")
    }
}

// MARK: - Background Refresh Status Extension

// Note: BGBackgroundRefreshStatus extension removed - use UIApplication.backgroundRefreshStatus instead
