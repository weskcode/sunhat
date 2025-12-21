//
//  TriggerEngineManager.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftData
import BackgroundTasks
@preconcurrency import UserNotifications
import CoreLocation
import Combine
import os

@MainActor
final class TriggerEngineManager: ObservableObject {
    static let shared = TriggerEngineManager()
    
    @Published var isEvaluating = false
    @Published var lastEvaluationTime: Date?
    @Published var triggeredReminders: [UUID] = []
    @Published var evaluationResults: [TriggerEvaluationResult] = []
    
    private var triggerEngine: TriggerEngine?
    private let notificationManager = TriggerNotificationManager.shared
    private let backgroundTaskIdentifier = "com.hatti.app.trigger-evaluation"
    private let logger = Logger(subsystem: "com.hatti.app", category: "TriggerEngineManager")
    
    // Performance tracking
    @Published var evaluationCount = 0
    @Published var successfulTriggers = 0
    @Published var averageEvaluationTime: TimeInterval = 0
    
    private init() {
        registerBackgroundTask()
    }
    
    func configure(modelContainer: ModelContainer) async {
        self.triggerEngine = await TriggerEngine.shared(modelContainer: modelContainer)
        await notificationManager.configure()
        logger.info("TriggerEngineManager configured")
    }
    
    // MARK: - Manual Evaluation
    
    func evaluateAllReminders() async {
        guard !isEvaluating else {
            logger.warning("Evaluation already in progress")
            return
        }
        
        guard let triggerEngine = triggerEngine else {
            logger.error("TriggerEngine not configured")
            return
        }
        
        isEvaluating = true
        let startTime = Date()
        
        do {
            logger.info("Starting manual evaluation of all reminders")
            
            let results = await triggerEngine.evaluateAllActiveReminders()
            await processEvaluationResults(results)
            
            let duration = Date().timeIntervalSince(startTime)
            updatePerformanceMetrics(duration: duration)
            
            lastEvaluationTime = Date()
            evaluationResults = results
            
            logger.info("Manual evaluation completed: \(results.count) reminders evaluated in \(duration)s")
            
        } catch {
            logger.error("Manual evaluation failed: \(error)")
        }
        
        isEvaluating = false
    }
    
    func evaluateSpecificReminder(_ reminder: WeatherReminder) async -> TriggerEvaluationResult? {
        logger.debug("Evaluating specific reminder: \(reminder.displayTitle)")
         
        guard let triggerEngine = triggerEngine else {
            logger.error("TriggerEngine not configured")
            return nil
        }
         
        let result = await triggerEngine.evaluateReminder(reminderId: reminder.id)
         
        if let result = result {
            await processEvaluationResults([result])
             
            // Update the specific reminder in our results
            if let index = evaluationResults.firstIndex(where: { $0.reminderId == reminder.id }) {
                evaluationResults[index] = result
            } else {
                evaluationResults.append(result)
            }
        }
         
        return result
    }
    
    // MARK: - Background Evaluation
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            Task {
                await self.handleBackgroundEvaluation(task as! BGAppRefreshTask)
            }
        }
        logger.info("Registered background task: \(self.backgroundTaskIdentifier)")
    }
    
    func scheduleBackgroundEvaluation() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // 10 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background trigger evaluation")
        } catch {
            logger.error("Failed to schedule background evaluation: \(error)")
        }
    }
    
    private func handleBackgroundEvaluation(_ task: BGAppRefreshTask) async {
        logger.info("Starting background trigger evaluation")
        
        let startTime = Date()
        
        // Set up task completion handler
        task.expirationHandler = {
            self.logger.warning("Background evaluation task expired")
            task.setTaskCompleted(success: false)
        }
        
        guard let triggerEngine = triggerEngine else {
            logger.error("TriggerEngine not configured for background evaluation")
            task.setTaskCompleted(success: false)
            return
        }
        
        do {
            // Perform the evaluation
            let results = await triggerEngine.evaluateAllActiveReminders()
            
            // Process results and send notifications
            await processEvaluationResults(results, isBackground: true)
            
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.lastEvaluationTime = Date()
                self.evaluationResults = results
                self.updatePerformanceMetrics(duration: duration)
            }
            
            logger.info("Background evaluation completed: \(results.count) reminders in \(duration)s")
            
            // Schedule next evaluation
            scheduleBackgroundEvaluation()
            
            task.setTaskCompleted(success: true)
            
        } catch {
            logger.error("Background evaluation failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }
    
    // MARK: - Result Processing
    
    private func processEvaluationResults(_ results: [TriggerEvaluationResult], isBackground: Bool = false) async {
        var newlyTriggered: [UUID] = []
        
        for result in results {
            if result.triggered {
                // Check if this is a new trigger (not already in our triggered list)
                if !triggeredReminders.contains(result.reminderId) {
                    newlyTriggered.append(result.reminderId)
                    await MainActor.run {
                        triggeredReminders.append(result.reminderId)
                    }
                    
                    // Send notification for newly triggered reminder
                    await sendNotificationForResult(result, isBackground: isBackground)
                    
                    // Update reminder in database
                    await updateReminderWithResult(result)
                }
            } else {
                // Remove from triggered list if no longer triggered
                await MainActor.run {
                    triggeredReminders.removeAll { $0 == result.reminderId }
                }
            }
        }
        
        if !newlyTriggered.isEmpty {
            await MainActor.run {
                successfulTriggers += newlyTriggered.count
            }
            logger.info("Triggered \(newlyTriggered.count) new reminders")
        }
        
        // Schedule next evaluations based on results
        await scheduleNextEvaluations(results)
    }
    
    private func sendNotificationForResult(_ result: TriggerEvaluationResult, isBackground: Bool) async {
        do {
            try await notificationManager.sendTriggerNotification(for: result, isBackground: isBackground)
            logger.info("Sent notification for triggered reminder: \(result.reminderId)")
        } catch {
            logger.error("Failed to send notification for reminder \(result.reminderId): \(error)")
        }
    }
    
    private func updateReminderWithResult(_ result: TriggerEvaluationResult) async {
        // This would typically update the reminder in the database
        // For now, we'll log the trigger event
        logger.debug("Reminder \(result.reminderId) triggered: \(result.triggerReason)")
    }
    
    private func scheduleNextEvaluations(_ results: [TriggerEvaluationResult]) async {
        // Find the earliest next evaluation time
        let nextEvaluationTimes = results.compactMap { $0.nextEvaluationTime }
        
        if let earliestNext = nextEvaluationTimes.min() {
            let timeInterval = earliestNext.timeIntervalSince(Date())
            
            if timeInterval > 0 && timeInterval < 24 * 3600 { // Within next 24 hours
                // Schedule a more specific evaluation
                DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
                    Task {
                        await self.evaluateAllReminders()
                    }
                }
                
                logger.debug("Scheduled next evaluation in \(String(format: "%.1f", timeInterval / 3600)) hours")
            }
        }
    }
    
    // MARK: - Performance Metrics
    
    private func updatePerformanceMetrics(duration: TimeInterval) {
        evaluationCount += 1
        
        if averageEvaluationTime == 0 {
            averageEvaluationTime = duration
        } else {
            averageEvaluationTime = (averageEvaluationTime * 0.8) + (duration * 0.2)
        }
    }
    
    func getPerformanceMetrics() -> (evaluations: Int, triggers: Int, avgTime: TimeInterval, lastEval: Date?) {
        return (evaluationCount, successfulTriggers, averageEvaluationTime, lastEvaluationTime)
    }
    
    // MARK: - Public Interface
    
    func clearTriggeredReminders() {
        triggeredReminders.removeAll()
        logger.info("Cleared triggered reminders list")
    }
    
    func getTriggeredReminderIds() -> [UUID] {
        return triggeredReminders
    }
    
    func isReminderTriggered(_ reminderId: UUID) -> Bool {
        return triggeredReminders.contains(reminderId)
    }
    
    func getEvaluationResult(for reminderId: UUID) -> TriggerEvaluationResult? {
        return evaluationResults.first { $0.reminderId == reminderId }
    }
}

// MARK: - Notification Manager

actor TriggerNotificationManager {
    static let shared = TriggerNotificationManager()
    
    private let logger = Logger(subsystem: "com.hatti.app", category: "TriggerNotificationManager")
    private var isConfigured = false
    
    private init() {}
    
    func configure() async {
        // Request notification permissions
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await setupNotificationCategories()
                isConfigured = true
                logger.info("Notification permissions granted and categories configured")
            } else {
                logger.warning("Notification permissions denied")
            }
        } catch {
            logger.error("Failed to request notification permissions: \(error)")
        }
    }
    
    private func setupNotificationCategories() async {
        let center = UNUserNotificationCenter.current()
        
        // Create actions
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 2h",
            options: []
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Details",
            options: [.foreground]
        )
        
        // Create category
        let triggerCategory = UNNotificationCategory(
            identifier: "WEATHER_TRIGGER",
            actions: [completeAction, snoozeAction, viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([triggerCategory])
    }
    
    func sendTriggerNotification(for result: TriggerEvaluationResult, isBackground: Bool) async throws {
        guard isConfigured else {
            throw WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Weather Condition Met!"
        content.body = result.triggerReason
        content.categoryIdentifier = "WEATHER_TRIGGER"
        content.sound = .default
        
        // Add weather context if available
        if let weatherData = result.weatherData {
            let weatherContext = "Current: \(Int(weatherData.temperature))°F • \(weatherData.weatherDescription.capitalized)"
            content.body += "\n\n\(weatherContext)"
        }
        
        // Add confidence and metadata
        if result.confidence > 0 {
            content.subtitle = "Confidence: \(Int(result.confidence * 100))%"
        }
        
        // Set badge
        content.badge = NSNumber(value: await getActiveTriggerCount() + 1)
        
        // Add user info for handling actions
        content.userInfo = [
            "reminder_id": result.reminderId.uuidString,
            "trigger_time": Date().timeIntervalSince1970,
            "confidence": result.confidence,
            "is_background": isBackground
        ]
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "trigger_\(result.reminderId.uuidString)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate delivery
        )
        
        let center = UNUserNotificationCenter.current()
        try await center.add(request)
        
        logger.info("Sent trigger notification for reminder \(result.reminderId)")
    }
    
    func sendForecastNotification(for result: TriggerEvaluationResult, hoursInAdvance: Int) async throws {
        guard isConfigured else {
            throw WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Weather Forecast Alert"
        content.body = "Your weather condition may be met in approximately \(hoursInAdvance) hours"
        content.categoryIdentifier = "WEATHER_TRIGGER"
        content.sound = .default
        content.subtitle = result.triggerReason
        
        // Schedule for delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "forecast_\(result.reminderId.uuidString)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        let center = UNUserNotificationCenter.current()
        try await center.add(request)
        
        logger.info("Sent forecast notification for reminder \(result.reminderId)")
    }
    
    func cancelNotifications(for reminderId: UUID) async {
        let center = UNUserNotificationCenter.current()
        
        // Get all pending notifications
        let pendingRequests = await center.pendingNotificationRequests()
        let identifiersToCancel = pendingRequests.compactMap { request in
            if request.identifier.contains(reminderId.uuidString) {
                return request.identifier
            }
            return nil
        }
        
        // Cancel matching notifications
        center.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        center.removeDeliveredNotifications(withIdentifiers: identifiersToCancel)
        
        logger.info("Cancelled notifications for reminder \(reminderId)")
    }
    
    private func getActiveTriggerCount() async -> Int {
        // This would typically query the active triggers from the database
        return await TriggerEngineManager.shared.triggeredReminders.count
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        guard let reminderIdString = userInfo["reminder_id"] as? String,
              let reminderId = UUID(uuidString: reminderIdString) else {
            logger.error("Invalid reminder ID in notification response")
            return
        }
        
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            await handleCompleteAction(reminderId: reminderId)
        case "SNOOZE_ACTION":
            await handleSnoozeAction(reminderId: reminderId, hours: 2)
        case "VIEW_ACTION":
            await handleViewAction(reminderId: reminderId)
        case UNNotificationDefaultActionIdentifier:
            await handleViewAction(reminderId: reminderId)
        default:
            logger.debug("Unknown notification action: \(response.actionIdentifier)")
        }
    }
    
    private func handleCompleteAction(reminderId: UUID) async {
        logger.info("User marked reminder \(reminderId) as complete")
        // Remove from triggered list
        await MainActor.run {
            TriggerEngineManager.shared.triggeredReminders.removeAll { $0 == reminderId }
        }
        
        // Cancel any pending notifications for this reminder
        await cancelNotifications(for: reminderId)
    }
    
    private func handleSnoozeAction(reminderId: UUID, hours: Int) async {
        logger.info("User snoozed reminder \(reminderId) for \(hours) hours")
        
        // Remove from current triggered list
        await MainActor.run {
            TriggerEngineManager.shared.triggeredReminders.removeAll { $0 == reminderId }
        }
        
        // Schedule re-evaluation after snooze period
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(hours * 3600)) {
            Task {
                // Re-evaluate this specific reminder after snooze
                // This would typically involve fetching the reminder from the database
                self.logger.info("Re-evaluating snoozed reminder \(reminderId)")
            }
        }
    }
    
    private func handleViewAction(reminderId: UUID) async {
        logger.info("User requested to view details for reminder \(reminderId)")
        // This would typically navigate to the reminder detail view
        // The UI layer would handle this navigation
    }
}
