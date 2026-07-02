//
//  TriggerEngineManager.swift
//  SunHat
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
    private var modelContainer: ModelContainer?
    private var scheduledEvaluationTask: Task<Void, Never>?
    private let notificationManager = TriggerNotificationManager.shared
    private let backgroundTaskIdentifier = "org.wesley.sunhat.trigger-evaluation"
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "TriggerEngineManager")
    
    // Performance tracking
    @Published var evaluationCount = 0
    @Published var successfulTriggers = 0
    @Published var averageEvaluationTime: TimeInterval = 0
    
    private init() {
        registerBackgroundTask()
    }
    
    func configure(modelContainer: ModelContainer) async {
        self.modelContainer = modelContainer
        self.triggerEngine = await TriggerEngine.shared(modelContainer: modelContainer)
        await notificationManager.configure(modelContainer: modelContainer)
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

        logger.info("Starting manual evaluation of all reminders")

        let results = await triggerEngine.evaluateAllActiveReminders()
        await processEvaluationResults(results)

        let duration = Date().timeIntervalSince(startTime)
        updatePerformanceMetrics(duration: duration)

        lastEvaluationTime = Date()
        evaluationResults = results

        logger.info("Manual evaluation completed: \(results.count) reminders evaluated in \(duration)s")

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
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }

                await self.handleBackgroundEvaluation(refreshTask)
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

        guard let triggerEngine = triggerEngine else {
            logger.error("TriggerEngine not configured for background evaluation")
            task.setTaskCompleted(success: false)
            return
        }

        let startTime = Date()

        let workTask = Task {
            let results = await triggerEngine.evaluateAllActiveReminders()
            await processEvaluationResults(results, isBackground: true)
            return results
        }

        task.expirationHandler = {
            self.logger.warning("Background evaluation task expired")
            workTask.cancel()
        }

        let results = await workTask.value
        let duration = Date().timeIntervalSince(startTime)

        lastEvaluationTime = Date()
        evaluationResults = results
        updatePerformanceMetrics(duration: duration)

        logger.info("Background evaluation completed: \(results.count) reminders in \(duration)s")
        scheduleBackgroundEvaluation()
        task.setTaskCompleted(success: !workTask.isCancelled)
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
        // Honor the user's app-level notification preferences (master switch,
        // quiet hours, weekend rule, daily limit).
        if let modelContainer {
            let context = ModelContext(modelContainer)
            if let preferences = try? context.fetch(FetchDescriptor<UserPreferences>()).first,
               !preferences.allowsNotificationDelivery() {
                logger.info("Suppressed notification for \(result.reminderId) — notifications are off, quiet hours active, or daily limit reached")
                return
            }
        }

        do {
            try await notificationManager.sendTriggerNotification(for: result, isBackground: isBackground)
            logger.info("Sent notification for triggered reminder: \(result.reminderId)")
            recordDelivery()
        } catch {
            logger.error("Failed to send notification for reminder \(result.reminderId): \(error)")
        }
    }

    private func recordDelivery() {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)
        if let preferences = try? context.fetch(FetchDescriptor<UserPreferences>()).first {
            preferences.recordNotificationDelivered()
            try? context.save()
        }
    }

    private func updateReminderWithResult(_ result: TriggerEvaluationResult) async {
        guard let modelContainer else {
            logger.warning("Cannot persist trigger for \(result.reminderId) — ModelContainer not configured")
            return
        }
        let context = ModelContext(modelContainer)
        do {
            let id = result.reminderId
            let descriptor = FetchDescriptor<WeatherReminder>(
                predicate: #Predicate { $0.id == id }
            )
            guard let reminder = try context.fetch(descriptor).first else {
                logger.warning("Reminder \(result.reminderId) not found for trigger persistence")
                return
            }
            reminder.trigger()
            try context.save()
            logger.info("Persisted trigger cooldown for reminder \(result.reminderId)")
        } catch {
            logger.error("Failed to persist trigger for reminder \(result.reminderId): \(error)")
        }
    }
    
    private func scheduleNextEvaluations(_ results: [TriggerEvaluationResult]) async {
        // Find the earliest next evaluation time
        let nextEvaluationTimes = results.compactMap { $0.nextEvaluationTime }
        
        if let earliestNext = nextEvaluationTimes.min() {
            let timeInterval = earliestNext.timeIntervalSince(Date())
            
            if timeInterval > 0 && timeInterval < 24 * 3600 { // Within next 24 hours
                scheduledEvaluationTask?.cancel()
                let delayMilliseconds = max(1, Int(timeInterval * 1000))

                scheduledEvaluationTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: .milliseconds(delayMilliseconds))
                        guard !Task.isCancelled else { return }
                        await self?.evaluateAllReminders()
                    } catch { }
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
    
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "TriggerNotificationManager")
    private var isConfigured = false
    private var modelContainer: ModelContainer?
    
    private init() {}
    
    func configure(modelContainer: ModelContainer? = nil) async {
        if let modelContainer {
            self.modelContainer = modelContainer
        }

        await setupNotificationCategories()
        isConfigured = true
        logger.info("Notification categories configured")
    }
    
    private func setupNotificationCategories() async {
        let center = UNUserNotificationCenter.current()
        SunHatNotificationCategoryRegistry.register(center: center)
    }
    
    func sendTriggerNotification(for result: TriggerEvaluationResult, isBackground: Bool) async throws {
        guard isConfigured else {
            throw WeatherError.serviceUnavailable(provider: .appleWeatherKit)
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Weather Condition Met!"
        content.body = result.triggerReason
        content.categoryIdentifier = SunHatNotificationCategoryIdentifier.weatherTrigger
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
        content.categoryIdentifier = SunHatNotificationCategoryIdentifier.weatherTrigger
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
        case SunHatNotificationActionIdentifier.complete:
            await handleCompleteAction(reminderId: reminderId)
        case SunHatNotificationActionIdentifier.snooze:
            await handleSnoozeAction(reminderId: reminderId, hours: 2)
        case SunHatNotificationActionIdentifier.pause:
            await handlePauseAction(reminderId: reminderId)
        case SunHatNotificationActionIdentifier.view, SunHatNotificationActionIdentifier.viewForecast:
            await handleViewAction(reminderId: reminderId)
        case UNNotificationDefaultActionIdentifier:
            await handleViewAction(reminderId: reminderId)
        default:
            logger.debug("Unknown notification action: \(response.actionIdentifier)")
        }
    }
    
    private func handleCompleteAction(reminderId: UUID) async {
        logger.info("User marked reminder \(reminderId) as complete")
        await persistReminderAction(reminderId: reminderId) { actor in
            try await actor.completeReminder(id: reminderId)
        }

        // Remove from triggered list
        await MainActor.run {
            TriggerEngineManager.shared.triggeredReminders.removeAll { $0 == reminderId }
        }
        
        // Cancel any pending notifications for this reminder
        await cancelNotifications(for: reminderId)
    }
    
    private func handleSnoozeAction(reminderId: UUID, hours: Int) async {
        logger.info("User snoozed reminder \(reminderId) for \(hours) hours")
        await persistReminderAction(reminderId: reminderId) { actor in
            try await actor.snoozeReminder(id: reminderId, hours: hours)
        }
        
        // Remove from current triggered list
        await MainActor.run {
            TriggerEngineManager.shared.triggeredReminders.removeAll { $0 == reminderId }
        }
        
        // Schedule re-evaluation after snooze period
        Task {
            do {
                try await Task.sleep(for: .seconds(hours * 3600))
                guard !Task.isCancelled else { return }
                // Re-evaluate this specific reminder after snooze.
                // This would typically involve fetching the reminder from the database.
                self.logger.info("Re-evaluating snoozed reminder \(reminderId)")
            } catch { }
        }
    }

    private func handlePauseAction(reminderId: UUID) async {
        logger.info("User paused reminder \(reminderId)")
        await persistReminderAction(reminderId: reminderId) { actor in
            try await actor.pauseReminder(id: reminderId)
        }

        await MainActor.run {
            TriggerEngineManager.shared.triggeredReminders.removeAll { $0 == reminderId }
        }

        await cancelNotifications(for: reminderId)
    }
    
    private func handleViewAction(reminderId: UUID) async {
        logger.info("User requested to view details for reminder \(reminderId)")
        // This would typically navigate to the reminder detail view
        // The UI layer would handle this navigation
    }

    private func persistReminderAction(
        reminderId: UUID,
        action: @Sendable (WeatherModelActor) async throws -> Bool
    ) async {
        guard let modelContainer else {
            logger.warning("Cannot persist notification action without a model container: \(reminderId)")
            return
        }

        do {
            let modelActor = WeatherModelActor(modelContainer: modelContainer)
            _ = try await action(modelActor)
        } catch {
            logger.error("Failed to persist notification action for \(reminderId): \(error.localizedDescription)")
        }
    }
}
