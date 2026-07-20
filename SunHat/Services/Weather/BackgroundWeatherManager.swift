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
            await TriggerEngineManager.shared.evaluateAllReminders(isBackground: true)
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
    
    // MARK: - Public Interface
    
    func requestBackgroundRefreshPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            scheduleBackgroundRefresh()
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
    
    func manualRefresh() async {
        logger.info("Starting manual weather refresh")
        await WeatherService.shared.handleBackgroundRefresh()
        await TriggerEngineManager.shared.evaluateAllReminders()
        lastBackgroundRefresh = Date()
    }
    
    func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.taskIdentifier)
        logger.info("Cancelled scheduled background refresh")
    }
}

// MARK: - Background Refresh Status Extension

// Note: BGBackgroundRefreshStatus extension removed - use UIApplication.backgroundRefreshStatus instead
