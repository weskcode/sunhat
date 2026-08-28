//
//  DetailedReminderViewModel.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import Combine
import os

@MainActor
final class DetailedReminderViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentWeatherData: WeatherData?
    @Published var triggerHistory: [ReminderHistory] = []
    @Published var livePrediction: LivePrediction?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    
    // MARK: - Private Properties
    
    private let reminder: WeatherReminder
    private var modelContext: ModelContext?
    private var weatherService = WeatherService.shared
    private var locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    private let timers = DetailedReminderTimers()
    
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "DetailedReminderViewModel")
    
    // MARK: - Initialization
    
    init(reminder: WeatherReminder) {
        self.reminder = reminder
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadUserPreferences()
        loadCurrentWeather()
    }
    
    func loadTriggerHistory() {
        guard let modelContext = modelContext else { return }
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let reminderID = reminder.id

        // Fetch all history entries without predicate to avoid Sendable keypath issues
        let descriptor = FetchDescriptor<ReminderHistory>()
        
        do {
            let allHistory = try modelContext.fetch(descriptor)
            // Filter by reminder ID and date programmatically
            self.triggerHistory = allHistory
                .filter { history in
                    history.weatherReminder?.id == reminderID
                }
                .filter { history in
                    history.timestamp >= thirtyDaysAgo
                }
                .sorted { $0.timestamp > $1.timestamp }
            logger.info("Loaded \(self.triggerHistory.count) history entries")
        } catch {
            logger.error("Failed to load trigger history: \(error.localizedDescription)")
            errorMessage = "Failed to load history"
        }
    }
    
    func startLivePrediction() {
        timers.predictionTimer?.invalidate()
        calculateLivePrediction()
        
        // Update prediction every 5 minutes
        timers.predictionTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.calculateLivePrediction()
            }
        }
    }
    
    func stopLivePrediction() {
        timers.predictionTimer?.invalidate()
        timers.predictionTimer = nil
    }

    func stopWeatherRefresh() {
        timers.weatherRefreshTimer?.invalidate()
        timers.weatherRefreshTimer = nil
    }
    
    func pauseReminder() {
        reminder.pause()
        saveContext()
    }
    
    func resumeReminder() {
        reminder.resume()
        saveContext()
    }
    
    func deleteReminder() async -> Bool {
        guard let modelContext = modelContext else { return false }
        let reminderId = reminder.id

        reminder.deleteOwnedData(from: modelContext)
        guard saveContext(reindexReminder: false) else {
            modelContext.rollback()
            return false
        }
        SunHatSearchIndexer.deleteReminder(id: reminderId)
        await TriggerNotificationManager.shared.cancelNotifications(for: reminderId)
        return true
    }
    
    func saveChanges(_ editedReminder: EditableReminder) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        do {
            // Update reminder properties
            reminder.title = editedReminder.title
            reminder.reminderDescription = editedReminder.description
            reminder.category = editedReminder.category
            reminder.lastModified = Date()
            
            // Update trigger condition
            if let condition = reminder.triggerCondition {
                condition.triggerType = editedReminder.triggerCondition.triggerType
                condition.targetTemperature = editedReminder.triggerCondition.targetTemperature
                condition.comparisonType = editedReminder.triggerCondition.comparisonType
                condition.temperatureTolerance = editedReminder.triggerCondition.temperatureTolerance
                condition.useFeelsLike = editedReminder.triggerCondition.useFeelsLike
                condition.minTemperature = editedReminder.triggerCondition.minTemperature
                condition.maxTemperature = editedReminder.triggerCondition.maxTemperature
            }
            
            // Update notification config
            if let config = reminder.notificationConfig {
                config.title = editedReminder.notificationConfig.title
                config.message = editedReminder.notificationConfig.message
                config.cooldownPeriodHours = editedReminder.notificationConfig.cooldownPeriodHours
            }
            
            // Update location if changed
            if editedReminder.location.hasChanged {
                let locationData = LocationData(
                    latitude: editedReminder.location.coordinate.latitude,
                    longitude: editedReminder.location.coordinate.longitude,
                    city: editedReminder.location.displayName
                )
                locationData.displayName = editedReminder.location.displayName
                reminder.location = locationData
            }
            
            try modelContext.save()
            SunHatSearchIndexer.index(reminder: reminder)
            
            // Add history entry
            reminder.addHistoryEntry(.modified, details: String(localized: "Reminder updated", comment: "Reminder history timeline entry"))
            
            // Reload current weather if location changed
            if editedReminder.location.hasChanged {
                loadCurrentWeather()
            }
            
            logger.info("Successfully saved reminder changes")
            return true
            
        } catch {
            logger.error("Failed to save changes: \(error.localizedDescription)")
            errorMessage = "Failed to save changes"
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Since WeatherReminder is a SwiftData @Model and not an ObservableObject,
        // we need to use a different approach to observe changes
        timers.weatherRefreshTimer?.invalidate()
        timers.weatherRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadCurrentWeather()
            }
        }
        timers.weatherRefreshTimer?.fire() // Trigger immediately on setup
    }
    
    private func loadUserPreferences() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        
        do {
            let preferences = try modelContext.fetch(descriptor)
            temperatureUnit = preferences.first?.temperatureUnit ?? .fahrenheit
        } catch {
            temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        }
    }
    
    private func loadCurrentWeather() {
        isLoading = true
        
        Task {
            do {
                guard let location = getCurrentLocation() else {
                    await MainActor.run {
                        errorMessage = "Add a location or enable Location Services to load accurate weather for this reminder."
                        isLoading = false
                    }
                    logger.warning("Skipped current weather load because no reminder or device location is available")
                    return
                }

                let weatherData = try await weatherService.fetchCurrentWeather(for: location)
                
                await MainActor.run {
                    currentWeatherData = weatherData
                    isLoading = false
                    calculateLivePrediction()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                logger.error("Failed to load current weather: \(error.localizedDescription)")
            }
        }
    }
    
    private func getCurrentLocation() -> CLLocation? {
        if let reminderLocation = reminder.location {
            return CLLocation(
                latitude: reminderLocation.latitude,
                longitude: reminderLocation.longitude
            )
        }

        return locationManager.location
    }
    
    private func calculateLivePrediction() {
        guard let condition = reminder.triggerCondition else { return }
        
        Task {
            do {
                // Fetch forecast data
                guard let location = getCurrentLocation() else {
                    logger.warning("Skipped live prediction because no reminder or device location is available")
                    return
                }

                let weatherData = try await weatherService.fetchWeatherData(for: location)
                
                // Calculate next trigger prediction
                let prediction = await calculateNextTrigger(
                    condition: condition,
                    forecast: weatherData.forecastDays
                )
                
                await MainActor.run {
                    livePrediction = prediction
                }
                
            } catch {
                logger.error("Failed to calculate live prediction: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateNextTrigger(
        condition: TriggerCondition,
        forecast: [ForecastDay]
    ) async -> LivePrediction {
        var nextTriggerDate: Date?
        var confidence: Double = 0.0
        var matchingDays = 0
        
        // Check next 7 days
        let sortedForecast = forecast.sorted { $0.date < $1.date }.prefix(7)
        
        for day in sortedForecast {
            let weatherData = createWeatherDataFromForecast(day)
            
            if weatherData.evaluateCondition(condition) {
                if nextTriggerDate == nil {
                    nextTriggerDate = day.date
                }
                matchingDays += 1
            }
        }
        
        // Calculate confidence based on matching days
        confidence = Double(matchingDays) / Double(min(sortedForecast.count, 7))
        
        return LivePrediction(
            nextTriggerDate: nextTriggerDate,
            confidence: confidence,
            matchingDays: matchingDays,
            totalDays: min(sortedForecast.count, 7),
            description: generatePredictionDescription(
                nextTriggerDate: nextTriggerDate,
                confidence: confidence
            )
        )
    }
    
    private func createWeatherDataFromForecast(_ day: ForecastDay) -> WeatherData {
        let weatherData = WeatherData(
            temperature: day.highTemperature,
            feelsLike: day.highTemperature, // Simplified
            humidity: day.humidity
        )
        weatherData.weatherCondition = WeatherCondition(rawValue: day.weatherCondition.rawValue) ?? .clear
        return weatherData
    }
    
    private func generatePredictionDescription(
        nextTriggerDate: Date?,
        confidence: Double
    ) -> String {
        if let nextDate = nextTriggerDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            
            let relativeString = formatter.localizedString(for: nextDate, relativeTo: Date())
            
            let confidenceText = confidence > 0.7 ? String(localized: "Very likely", comment: "Prediction confidence level for when a reminder will next trigger") :
                                confidence > 0.4 ? String(localized: "Likely", comment: "Prediction confidence level for when a reminder will next trigger") : String(localized: "Possibly", comment: "Prediction confidence level for when a reminder will next trigger")

            return String(localized: "\(confidenceText) to trigger \(relativeString)", comment: "Live prediction description, e.g. 'Very likely to trigger in 2 days'")
        } else {
            return String(localized: "No triggers expected in the next 7 days", comment: "Live prediction description shown when no trigger is expected in the forecast window")
        }
    }
    
    @discardableResult
    private func saveContext(reindexReminder: Bool = true) -> Bool {
        guard let modelContext = modelContext else { return false }
        
        do {
            try modelContext.save()
            if reindexReminder {
                SunHatSearchIndexer.index(reminder: reminder)
            }
            return true
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
            errorMessage = "Couldn't save changes. Please try again."
            return false
        }
    }

}

nonisolated private final class DetailedReminderTimers {
    var predictionTimer: Timer?
    var weatherRefreshTimer: Timer?

    deinit {
        predictionTimer?.invalidate()
        weatherRefreshTimer?.invalidate()
    }
}

// MARK: - Supporting Data Models

struct LivePrediction {
    let nextTriggerDate: Date?
    let confidence: Double
    let matchingDays: Int
    let totalDays: Int
    let description: String
    
    var confidenceColor: Color {
        switch confidence {
        case 0.7...1.0: return .green
        case 0.4..<0.7: return .orange
        case 0.1..<0.4: return .red
        default: return .gray
        }
    }
    
    var confidenceText: String {
        "\(Int(confidence * 100))%"
    }
}

struct EditableReminder {
    var title: String
    var description: String
    var category: ReminderCategory
    var triggerCondition: EditableTriggerCondition
    var notificationConfig: EditableNotificationConfig
    var location: EditableLocation
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        triggerCondition.isValid
    }
    
    init(from reminder: WeatherReminder) {
        self.title = reminder.title
        self.description = reminder.reminderDescription
        self.category = reminder.category
        self.triggerCondition = EditableTriggerCondition(from: reminder.triggerCondition)
        self.notificationConfig = EditableNotificationConfig(from: reminder.notificationConfig)
        self.location = EditableLocation(from: reminder.location)
    }
}

struct EditableTriggerCondition {
    var triggerType: TriggerType
    var targetTemperature: Double
    var comparisonType: ComparisonType
    var temperatureTolerance: Double
    var useFeelsLike: Bool
    var minTemperature: Double?
    var maxTemperature: Double?
    
    var isValid: Bool {
        targetTemperature >= -50 && targetTemperature <= 150
    }
    
    init(from condition: TriggerCondition?) {
        self.triggerType = condition?.triggerType ?? .exactTemperature
        self.targetTemperature = condition?.targetTemperature ?? 70.0
        self.comparisonType = condition?.comparisonType ?? .equals
        self.temperatureTolerance = condition?.temperatureTolerance ?? 1.0
        self.useFeelsLike = condition?.useFeelsLike ?? false
        self.minTemperature = condition?.minTemperature
        self.maxTemperature = condition?.maxTemperature
    }
}

struct EditableNotificationConfig {
    var title: String
    var message: String
    var cooldownPeriodHours: Int
    var enableBadge: Bool
    var enableSound: Bool
    
    init(from config: NotificationConfig?) {
        self.title = config?.title ?? ""
        self.message = config?.message ?? ""
        self.cooldownPeriodHours = config?.cooldownPeriodHours ?? 2
        self.enableBadge = true // Default value since NotificationConfig doesn't have this property
        self.enableSound = config?.customSound != nil // Use presence of customSound to determine if sound is enabled
    }
}

struct EditableLocation {
    var coordinate: CLLocationCoordinate2D
    var displayName: String
    var fullAddress: String?
    var isCurrentLocation: Bool
    var hasChanged: Bool = false
    
    init(from location: LocationData?) {
        if let location = location {
            self.coordinate = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            self.displayName = location.displayName.isEmpty ? location.city : location.displayName
            self.fullAddress = [location.city, location.state, location.country].filter { !$0.isEmpty }.joined(separator: ", ")
            self.isCurrentLocation = false
        } else {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            self.displayName = String(localized: "Current Location", comment: "Location label shown when using the device's current location")
            self.fullAddress = nil
            self.isCurrentLocation = true
        }
    }
}
