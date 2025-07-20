//
//  DetailedReminderViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import Combine
import os.log

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
    private var predictionTimer: Timer?
    
    private let logger = Logger(subsystem: "com.temptrigger.hatti", category: "DetailedReminderViewModel")
    
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
        
        let predicate = #Predicate<ReminderHistory> { history in
            history.weatherReminder?.id == reminder.id &&
            history.timestamp >= thirtyDaysAgo
        }
        
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\ReminderHistory.timestamp, order: .reverse)]
        )
        
        do {
            triggerHistory = try modelContext.fetch(descriptor)
            logger.info("Loaded \(triggerHistory.count) history entries")
        } catch {
            logger.error("Failed to load trigger history: \(error.localizedDescription)")
            errorMessage = "Failed to load history"
        }
    }
    
    func startLivePrediction() {
        calculateLivePrediction()
        
        // Update prediction every 5 minutes
        predictionTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.calculateLivePrediction()
            }
        }
    }
    
    func stopLivePrediction() {
        predictionTimer?.invalidate()
        predictionTimer = nil
    }
    
    func pauseReminder() {
        reminder.pause()
        saveContext()
    }
    
    func resumeReminder() {
        reminder.resume()
        saveContext()
    }
    
    func deleteReminder() {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(reminder)
        saveContext()
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
                config.enableBadge = editedReminder.notificationConfig.enableBadge
                config.enableSound = editedReminder.notificationConfig.enableSound
            }
            
            // Update location if changed
            if editedReminder.location.hasChanged {
                let locationData = LocationData(
                    latitude: editedReminder.location.coordinate.latitude,
                    longitude: editedReminder.location.coordinate.longitude,
                    name: editedReminder.location.displayName,
                    address: editedReminder.location.fullAddress
                )
                reminder.location = locationData
            }
            
            try modelContext.save()
            
            // Add history entry
            reminder.addHistoryEntry(.modified, details: "Reminder updated")
            
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
        // Reload weather data when reminder changes
        reminder.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.loadCurrentWeather()
            }
            .store(in: &cancellables)
    }
    
    private func loadUserPreferences() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        
        do {
            let preferences = try modelContext.fetch(descriptor)
            temperatureUnit = preferences.first?.temperatureUnit ?? .fahrenheit
        } catch {
            temperatureUnit = Locale.current.usesMetricSystem ? .celsius : .fahrenheit
        }
    }
    
    private func loadCurrentWeather() {
        isLoading = true
        
        Task {
            do {
                let location = getCurrentLocation()
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
    
    private func getCurrentLocation() -> CLLocation {
        if let reminderLocation = reminder.location {
            return CLLocation(
                latitude: reminderLocation.latitude,
                longitude: reminderLocation.longitude
            )
        } else {
            // Use device location or default
            return locationManager.location ?? CLLocation(latitude: 37.7749, longitude: -122.4194)
        }
    }
    
    private func calculateLivePrediction() {
        guard let condition = reminder.triggerCondition else { return }
        
        Task {
            do {
                // Fetch forecast data
                let location = getCurrentLocation()
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
            
            let confidenceText = confidence > 0.7 ? "Very likely" :
                                confidence > 0.4 ? "Likely" : "Possibly"
            
            return "\(confidenceText) to trigger \(relativeString)"
        } else {
            return "No triggers expected in the next 7 days"
        }
    }
    
    private func saveContext() {
        guard let modelContext = modelContext else { return }
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
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
        self.enableBadge = config?.enableBadge ?? true
        self.enableSound = config?.enableSound ?? true
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
            self.displayName = location.name ?? "Unknown Location"
            self.fullAddress = location.address
            self.isCurrentLocation = false
        } else {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            self.displayName = "Current Location"
            self.fullAddress = nil
            self.isCurrentLocation = true
        }
    }
}