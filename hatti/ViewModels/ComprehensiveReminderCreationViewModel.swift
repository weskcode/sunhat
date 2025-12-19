//
//  ComprehensiveReminderCreationViewModel.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
@preconcurrency import MapKit
import Combine
import os

@MainActor
final class ComprehensiveReminderCreationViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var naturalLanguageInput: String = ""
    @Published var isProcessingLanguage: Bool = false
    @Published var parsedLanguageInfo: ParsedLanguageInfo?
    @Published var smartSuggestions: [SmartSuggestion] = []
    
    @Published var targetTemperature: Double = 70.0
    @Published var temperatureRange: ClosedRange<Double> = 65.0...75.0
    @Published var useFeelsLike: Bool = false
    @Published var conditionType: TriggerType = .exactTemperature
    
    @Published var trendType: TrendType = .rising
    @Published var trendDuration: Int = 3
    @Published var seasonalType: SeasonalTriggerType = .springTransition
    @Published var historicalComparison: Bool = false
    
    @Published var selectedLocation: ReminderLocation = ReminderLocation.currentLocation
    @Published var selectedCategory: ActivityInterest = .exercise
    @Published var notificationTiming: NotificationTiming = .immediate
    
    @Published var triggerLikelihood: TriggerLikelihood?
    @Published var nextPossibleTriggerDate: Date?
    @Published var forecastData: [ForecastDay] = []
    
    @Published var isSaving: Bool = false
    @Published var validationError: String?
    
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var locationManager = CLLocationManager()
    private var weatherService = WeatherService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "com.hatti.app", category: "ComprehensiveReminderCreationViewModel")
    
    // Natural language processing
    private var languageProcessingTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var displayTemperature: Double {
        switch conditionType {
        case .exactTemperature:
            return convertTemperatureForDisplay(targetTemperature)
        case .temperatureRange:
            return convertTemperatureForDisplay((temperatureRange.lowerBound + temperatureRange.upperBound) / 2)
        default:
            return convertTemperatureForDisplay(targetTemperature)
        }
    }
    
    var isValidForPreview: Bool {
        !naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isValidForSave: Bool {
        !naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLocation.isValid
    }
    
    var generatedTitle: String {
        if let parsed = parsedLanguageInfo {
            return parsed.suggestedTitle
        }
        
        let activity = selectedCategory.displayName.lowercased()
        let temp = Int(displayTemperature)
        
        switch conditionType {
        case .exactTemperature:
            return "Perfect \(activity) weather at \(temp)°"
        case .temperatureRange:
            let low = Int(convertTemperatureForDisplay(temperatureRange.lowerBound))
            let high = Int(convertTemperatureForDisplay(temperatureRange.upperBound))
            return "Great \(activity) weather (\(low)°-\(high)°)"
        case .averageTemperature:
            return "\(trendType.displayName) temperatures for \(activity)"
        case .seasonalMarker:
            return "\(seasonalType.displayName) \(activity) reminder"
        default:
            return "Current conditions are perfect for your \(activity) activity!"
        }
    }
    
    var generatedMessage: String {
        if let parsed = parsedLanguageInfo {
            return parsed.suggestedMessage
        }
        
        return "Current conditions are perfect for your \(selectedCategory.displayName.lowercased()) activity!"
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
        setupBindings()
        loadTemperatureUnit()
    }
    
    // MARK: - Public Methods
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await weatherService.configure(modelContainer: modelContext.container)
            loadForecastData()
        }
    }
    
    func loadUserHistory() {
        Task {
            await generateSmartSuggestions()
        }
    }
    
    func loadCurrentLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let location = locationManager.location {
            Task {
                await updateLocationName(for: location)
            }
        }
    }
    
    func processNaturalLanguage(_ input: String) {
        // Cancel previous processing task
        languageProcessingTask?.cancel()
        
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            parsedLanguageInfo = nil
            return
        }
        
        languageProcessingTask = Task {
            await processLanguageInput(input)
        }
    }
    
    func applyParsedInfo(_ info: ParsedLanguageInfo) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if let temperature = info.extractedTemperature {
                targetTemperature = temperature
            }
            
            if let range = info.extractedTemperatureRange {
                temperatureRange = range
                conditionType = .temperatureRange
            } else if info.extractedTemperature != nil {
                conditionType = .exactTemperature
            }
            
            // Apply parsed suggestion
            selectedCategory = info.suggestedCategory ?? .exercise
            notificationTiming = info.suggestedTiming ?? .immediate
        }
        
        // Clear the parsed info after applying
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.parsedLanguageInfo = nil
            }
        }
    }
    
    func applySuggestion(_ suggestion: SmartSuggestion) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            naturalLanguageInput = suggestion.naturalLanguageText
            targetTemperature = suggestion.temperature
            temperatureRange = suggestion.temperatureRange ?? (suggestion.temperature - 5)...(suggestion.temperature + 5)
            conditionType = suggestion.conditionType
            selectedCategory = suggestion.category
            notificationTiming = suggestion.timing
        }
        
        // Process the natural language from suggestion
        processNaturalLanguage(suggestion.naturalLanguageText)
    }
    
    func buildTriggerCondition() -> TriggerCondition {
        let condition = TriggerCondition()
        
        switch conditionType {
        case .exactTemperature:
            condition.triggerType = .exactTemperature
            condition.targetTemperature = targetTemperature
            condition.comparisonType = .equals
        case .temperatureRange:
            condition.triggerType = .temperatureRange
            condition.minTemperature = temperatureRange.lowerBound
            condition.maxTemperature = temperatureRange.upperBound
            condition.comparisonType = .between
        case .consecutiveDays:
            condition.triggerType = .consecutiveDays
            condition.targetTemperature = targetTemperature
            condition.consecutiveDays = trendDuration
            condition.comparisonType = trendType == .rising ? .above : .below
        case .averageTemperature:
            condition.triggerType = .historicalComparison
            condition.targetTemperature = targetTemperature
            condition.consecutiveDays = trendDuration
            condition.comparisonType = trendType == .rising ? .above : .below
        case .seasonalMarker:
            condition.triggerType = .seasonalMarker
            condition.seasonalType = SeasonalType(rawValue: seasonalType.rawValue) ?? .springTransition
        default:
            break
        }
        
        condition.useFeelsLike = useFeelsLike
        
        return condition
    }
    
    func saveReminder() async -> Bool {
        guard isValidForSave, let modelContext = modelContext else {
            validationError = "Please complete all required fields"
            return false
        }
        
        isSaving = true
        validationError = nil
        
        do {
            // Create the weather reminder
            let reminder = WeatherReminder(
                title: generatedTitle,
                reminderDescription: naturalLanguageInput,
                category: ReminderCategory(rawValue: selectedCategory.rawValue) ?? .general
            )
            
            // Create trigger condition
            let triggerCondition = buildTriggerCondition()
            reminder.triggerCondition = triggerCondition
            
            // Create notification config
            let notificationConfig = NotificationConfig(
                title: generatedTitle,
                message: generatedMessage
            )
            notificationConfig.cooldownPeriodHours = notificationTiming.cooldownHours
            reminder.notificationConfig = notificationConfig
            
            // Set location if not current location
            if !selectedLocation.isCurrentLocation {
                let locationData = LocationData(
                    latitude: selectedLocation.coordinate.latitude,
                    longitude: selectedLocation.coordinate.longitude
                )
                locationData.city = selectedLocation.displayName.components(separatedBy: ", ").first ?? selectedLocation.displayName
                locationData.state = selectedLocation.displayName.components(separatedBy: ", ").last ?? ""
                locationData.displayName = selectedLocation.displayName
                reminder.location = locationData
            }
            
            // Insert into context
            modelContext.insert(reminder)
            do {
                try modelContext.save()
                logger.info("Successfully created reminder: \(self.generatedTitle)")
            } catch {
                logger.error("Failed to save reminder: \(error.localizedDescription)")
                throw error
            }
            
            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            isSaving = false
            return true
        } catch {
            logger.error("Failed to save reminder: \(error.localizedDescription)")
            validationError = "Failed to save reminder. Please try again."
            
            // Error haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            
            isSaving = false
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupBindings() {
        // Update trigger likelihood when parameters change
        Publishers.CombineLatest4(
            $targetTemperature,
            $temperatureRange,
            $conditionType,
            $forecastData
        )
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.calculateTriggerLikelihood()
        }
        .store(in: &cancellables)
        
        // Validate form when inputs change
        Publishers.CombineLatest3(
            $naturalLanguageInput,
            $selectedLocation,
            $isSaving
        )
        .map { input, location, saving in
            if saving { return nil }

            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Please describe what you'd like to be reminded about"
            }

            if !location.isValid {
                return "Please select a valid location"
            }

            return nil
        }
        .assign(to: \.validationError, on: self)
        .store(in: &cancellables)
    }
    
    private func loadTemperatureUnit() {
        guard let modelContext = modelContext else {
            temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
            return
        }
        
        let descriptor = FetchDescriptor<UserPreferences>()
        
        do {
            let preferences = try modelContext.fetch(descriptor)
            temperatureUnit = preferences.first?.temperatureUnit ?? (Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit)
        } catch {
            temperatureUnit = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
        }
    }
    
    private func convertTemperatureForDisplay(_ fahrenheit: Double) -> Double {
        switch temperatureUnit {
        case .fahrenheit:
            return fahrenheit
        case .celsius:
            return (fahrenheit - 32) * 5 / 9
        }
    }
    
    private func processLanguageInput(_ input: String) async {
        isProcessingLanguage = true
        
        // Simulate processing delay
        try? await Task.sleep(for: .milliseconds(800))
        
        guard !Task.isCancelled else {
            isProcessingLanguage = false
            return
        }
        
        await MainActor.run {
            parsedLanguageInfo = parseNaturalLanguage(input)
            isProcessingLanguage = false
        }
    }
    
    private func parseNaturalLanguage(_ input: String) -> ParsedLanguageInfo? {
        let lowercasedInput = input.lowercased()
        
        // Extract temperature information
        let temperaturePattern = #/(\d+)\s*(?:degrees?|°)\s*([cf])?/#
        var extractedTemp: Double?
        var extractedRange: ClosedRange<Double>?
        
        if let match = lowercasedInput.firstMatch(of: temperaturePattern) {
            let temp = Double(match.1) ?? 70.0
            let unit = match.2?.lowercased() ?? (temperatureUnit == .celsius ? "c" : "f")
            
            // Convert to Fahrenheit for internal storage
            extractedTemp = unit == "c" ? (temp * 9/5 + 32) : temp
        }
        
        // Look for range patterns
        let rangePattern = #/(\d+)\s*(?:to|-)\s*(\d+)\s*(?:degrees?|°)/#
        if let match = lowercasedInput.firstMatch(of: rangePattern) {
            let low = Double(match.1) ?? 65.0
            let high = Double(match.2) ?? 75.0
            extractedRange = low...high
        }
        
        // Extract activity category
        var suggestedCategory: ActivityInterest = .exercise
        
        for category in ActivityInterest.allCases {
            for keyword in category.displayName.lowercased().components(separatedBy: " ") {
                if lowercasedInput.contains(keyword) {
                    suggestedCategory = category
                    break
                }
            }
        }
        
        // Extract timing information
        var suggestedTiming: NotificationTiming = .immediate
        
        if lowercasedInput.contains("hour before") || lowercasedInput.contains("1 hour") {
            suggestedTiming = .oneHour
        } else if lowercasedInput.contains("30 min") || lowercasedInput.contains("half hour") {
            suggestedTiming = .thirtyMinutes
        } else if lowercasedInput.contains("15 min") {
            suggestedTiming = .fifteenMinutes
        } else if lowercasedInput.contains("2 hour") {
            suggestedTiming = .twoHours
        }
        
        // Generate suggestions
        let title = generateTitle(from: lowercasedInput, category: suggestedCategory, temperature: extractedTemp)
        let message = generateMessage(from: lowercasedInput, category: suggestedCategory)
        
        return ParsedLanguageInfo(
            originalInput: input,
            extractedTemperature: extractedTemp,
            extractedTemperatureRange: extractedRange,
            suggestedCategory: suggestedCategory,
            suggestedTiming: suggestedTiming,
            suggestedTitle: title,
            suggestedMessage: message,
            confidence: calculateConfidence(input: lowercasedInput)
        )
    }
    
    private func generateTitle(from input: String, category: ActivityInterest, temperature: Double?) -> String {
        let activity = category.displayName.lowercased()
        
        if let temp = temperature {
            let displayTemp = Int(convertTemperatureForDisplay(temp))
            return "Perfect \(activity) weather at \(displayTemp)°"
        }
        
        return "Great \(activity) weather!"
    }
    
    private func generateMessage(from input: String, category: ActivityInterest) -> String {
        let activity = category.displayName.lowercased()
        return "The weather conditions are ideal for your \(activity) activity. Time to get outside!"
    }
    
    private func calculateConfidence(input: String) -> Double {
        var confidence = 0.0
        
        // Base confidence
        confidence += 0.3
        
        // Temperature mentioned
        if input.contains(#/\d+\s*(?:degrees?|°)/#) {
            confidence += 0.3
        }
        
        // Activity mentioned
        for category in ActivityInterest.allCases {
            for keyword in category.displayName.lowercased().components(separatedBy: " ") {
                if input.lowercased().contains(keyword) {
                    confidence += 0.2
                    break
                }
            }
        }
        
        // Weather conditions mentioned
        let weatherKeywords = ["sunny", "cloudy", "rain", "hot", "cold", "warm", "cool"]
        for keyword in weatherKeywords {
            if input.lowercased().contains(keyword) {
                confidence += 0.1
                break
            }
        }
        
        // Timing mentioned
        if input.contains(#/(before|after|when|hour|minute)/#) {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    private func generateSmartSuggestions() async {
        guard let modelContext = modelContext else { return }
        
        // Fetch user's reminder history
        var descriptor = FetchDescriptor<WeatherReminder>()
        descriptor.includePendingChanges = true
        
        do {
            let allReminders = try modelContext.fetch(descriptor)
            let reminders = allReminders.sorted { $0.createdDate > $1.createdDate }
            let suggestions = await createSuggestionsFromHistory(reminders)
            
            await MainActor.run {
                smartSuggestions = suggestions
            }
        } catch {
            logger.error("Failed to load reminder history: \(error.localizedDescription)")
        }
    }
    
    private func createSuggestionsFromHistory(_ reminders: [WeatherReminder]) async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Add popular templates
        suggestions.append(contentsOf: createPopularSuggestions())
        
        // Add suggestions based on user history
        let categoryFrequency = Dictionary(grouping: reminders) { $0.category }
        let popularCategories = categoryFrequency.sorted { $0.value.count > $1.value.count }.prefix(3)
        
        for (category, categoryReminders) in popularCategories {
            if let avgTemp = averageTemperature(from: categoryReminders) {
                let suggestion = SmartSuggestion(
                    id: UUID(),
                    title: "Your usual \(category.displayName.lowercased())",
                    description: "Based on your history",
                    naturalLanguageText: "Remind me to \(category.displayName.lowercased()) when it's \(Int(avgTemp))°F",
                    category: ActivityInterest(rawValue: category.rawValue) ?? .exercise,
                    temperature: avgTemp,
                    conditionType: .exactTemperature,
                    timing: .immediate,
                    icon: category.iconName,
                    color: Color.blue
                )
                suggestions.append(suggestion)
            }
        }
        
        return Array(suggestions.prefix(6))
    }
    
    private func createPopularSuggestions() -> [SmartSuggestion] {
        return [
            SmartSuggestion(
                id: UUID(),
                title: "Morning Walk",
                description: "Perfect temperature for walking",
                naturalLanguageText: "Remind me to go for a walk when it's between 65-75°F in the morning",
                category: .exercise,
                temperature: 70.0,
                temperatureRange: 65.0...75.0,
                conditionType: .temperatureRange,
                timing: .immediate,
                icon: "figure.walk",
                color: .green
            ),
            SmartSuggestion(
                id: UUID(),
                title: "Outdoor Lunch",
                description: "Great weather for eating outside",
                naturalLanguageText: "Remind me to eat lunch outside when it's sunny and 75°F",
                category: .outdoorDining,
                temperature: 75.0,
                conditionType: .exactTemperature,
                timing: .thirtyMinutes,
                icon: "sun.max.fill",
                color: .orange
            )
        ]
    }
    
    private func averageTemperature(from reminders: [WeatherReminder]) -> Double? {
        let temperatures = reminders.compactMap { $0.triggerCondition?.targetTemperature }
        guard !temperatures.isEmpty else { return nil }
        return temperatures.reduce(0, +) / Double(temperatures.count)
    }
    
    private func loadForecastData() {
        // Load forecast for trigger likelihood calculation
        Task {
            // In a real implementation, fetch from weather service
            let forecast = generateMockForecast()
            await MainActor.run {
                forecastData = forecast
                calculateTriggerLikelihood()
            }
        }
    }
    
    private func generateMockForecast() -> [ForecastDay] {
        let today = Date()
        var forecast: [ForecastDay] = []
        
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: today) ?? today
            let baseTemp = 70.0 + Double.random(in: -15...15)
            
            let forecastDay = ForecastDay(
                date: date,
                highTemperature: baseTemp + Double.random(in: 5...10),
                lowTemperature: baseTemp - Double.random(in: 5...10)
            )
            
            forecast.append(forecastDay)
        }
        
        return forecast
    }
    
    private func calculateTriggerLikelihood() {
        guard !forecastData.isEmpty else { return }
        
        let condition = buildTriggerCondition()
        var triggerDays = 0
        var nextTriggerDate: Date?
        
        for day in forecastData {
            // Simulate weather data evaluation
            let willTrigger = evaluateCondition(condition, for: day)
            if willTrigger {
                triggerDays += 1
                if nextTriggerDate == nil {
                    nextTriggerDate = day.date
                }
            }
        }
        
        let percentage = Double(triggerDays) / Double(forecastData.count) * 100
        
        // Convert triggerDays count to an array of dates
        var triggerDates: [Date] = []
        for (_, day) in forecastData.enumerated() {
            if evaluateCondition(condition, for: day) {
                triggerDates.append(day.date)
            }
        }
        
        triggerLikelihood = TriggerLikelihood(
            percentage: percentage,
            description: likelihoodDescription(for: percentage),
            triggerDays: triggerDates
        )
        
        nextPossibleTriggerDate = nextTriggerDate
    }
    
    private func evaluateCondition(_ condition: TriggerCondition, for day: ForecastDay) -> Bool {
        switch condition.triggerType {
        case .exactTemperature:
            return abs(day.highTemperature - condition.targetTemperature) <= 3.0
        case .temperatureRange:
            if let min = condition.minTemperature, let max = condition.maxTemperature {
                return day.highTemperature >= min && day.highTemperature <= max
            }
            return false
        default:
            return false
        }
    }
    
    private func likelihoodDescription(for percentage: Double) -> String {
        switch percentage {
        case 0:
            return "Unlikely to trigger this week"
        case 1...25:
            return "Low chance of triggering"
        case 26...50:
            return "Moderate chance of triggering"
        case 51...75:
            return "Good chance of triggering"
        case 76...100:
            return "Very likely to trigger"
        default:
            return "Unknown"
        }
    }
    
    private func updateLocationName(for location: CLLocation) async {
        // Handle geocoding based on iOS version
        if #available(iOS 26.0, *) {
            // Use MapKit for iOS 26+
            #if canImport(MapKit)
            let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 100)
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                if let item = response.mapItems.first {
                    let city = item.placemark.locality ?? ""
                    let state = item.placemark.administrativeArea ?? ""

                    await MainActor.run {
                        selectedLocation = ReminderLocation(
                            coordinate: location.coordinate,
                            displayName: "\(city), \(state)",
                            fullAddress: [item.placemark.thoroughfare, item.placemark.locality, item.placemark.administrativeArea]
                                .compactMap { $0 }
                                .joined(separator: ", "),
                            isCurrentLocation: true
                        )
                    }
                }
            } catch {
                logger.warning("Failed to reverse geocode location: \(error.localizedDescription)")
                await fallbackGeocoding(location)
            }
            #else
            // Fallback to CLGeocoder if MapKit is not available
            await fallbackGeocoding(location)
            #endif
        } else {
            // Use CLGeocoder for iOS 25 and below
            await fallbackGeocoding(location)
        }
    }
    
    private func fallbackGeocoding(_ location: CLLocation) async {
        if #available(iOS 26.0, *) {
            // Use MapKit reverse geocoding for iOS 26+
            let request = MKLocalSearch.Request()
            request.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                if let placemark = response.mapItems.first?.placemark {
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""

                    await MainActor.run {
                        selectedLocation = ReminderLocation(
                            coordinate: location.coordinate,
                            displayName: "\(city), \(state)",
                            fullAddress: [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
                                .compactMap { $0 }
                                .joined(separator: ", "),
                            isCurrentLocation: true
                        )
                    }
                }
            } catch {
                logger.warning("Failed to reverse geocode location with MKReverseGeocodingRequest: \(error.localizedDescription)")
            }
        } else {
            // Use CLGeocoder for earlier iOS versions
            let geocoder = CLGeocoder()

            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""

                    await MainActor.run {
                        selectedLocation = ReminderLocation(
                            coordinate: location.coordinate,
                            displayName: "\(city), \(state)",
                            fullAddress: placemark.compactAddress,
                            isCurrentLocation: true
                        )
                    }
                }
            } catch {
                logger.warning("Failed to reverse geocode location with CLGeocoder: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ComprehensiveReminderCreationViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            await updateLocationName(for: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed: \(error.localizedDescription)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}

// MARK: - Supporting Extensions

extension CLPlacemark {
    var compactAddress: String? {
        let components = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea
        ].compactMap { $0 }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}
