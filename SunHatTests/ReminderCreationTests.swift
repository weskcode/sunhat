//
//  ReminderCreationTests.swift
//  SunHatTests
//
//  Created by Wesley Keetch on 2/12/26.
//

import SwiftUI
import SwiftData
import CoreLocation
import Testing
@testable import SunHat

// MARK: - CustomReminder Model Tests

@MainActor
struct CustomReminderTests {

    // MARK: - Default Values

    @Test("Default values are set correctly on a fresh CustomReminder")
    func defaultValues() {
        let reminder = CustomReminder()

        #expect(reminder.title == "")
        #expect(reminder.selectedIcon == "figure.walk")
        #expect(reminder.notes == "")
        #expect(reminder.minTemperature == 65)
        #expect(reminder.maxTemperature == 75)
        #expect(reminder.conditionMode == .include)
        #expect(reminder.preferredTimeRange == .allDay)
        #expect(reminder.respectQuietHours == true)
        #expect(reminder.selectedLocation.isCurrentLocation == true)
    }

    // MARK: - Display Title

    @Test("Empty title falls back to New Reminder")
    func displayTitleWhenEmpty() {
        let reminder = CustomReminder()
        #expect(reminder.displayTitle == "New Reminder")
    }

    @Test("Custom title is used verbatim")
    func displayTitleWithCustomTitle() {
        var reminder = CustomReminder()
        reminder.title = "Morning Walk"
        #expect(reminder.displayTitle == "Morning Walk")
    }

    // MARK: - Temperature Description

    @Test("Range type shows min-max format")
    func temperatureRangeDescription() {
        var reminder = CustomReminder()
        reminder.temperatureType = .temperatureRange
        reminder.minTemperature = 60
        reminder.maxTemperature = 80
        #expect(reminder.temperatureDescription == "60\u{00B0} - 80\u{00B0}F")
    }

    @Test("Exact type shows single temperature")
    func exactTemperatureDescription() {
        var reminder = CustomReminder()
        reminder.temperatureType = .exactTemperature
        reminder.minTemperature = 72
        #expect(reminder.temperatureDescription == "72\u{00B0}F")
    }

    // MARK: - Sky Condition Description

    @Test("Include mode shows condition name")
    func skyConditionDescriptionIncludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.sunny]
        reminder.conditionMode = .include
        #expect(reminder.skyConditionDescription == "Sunny")
    }

    @Test("Exclude mode prefixes with Not")
    func skyConditionDescriptionExcludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.rainy]
        reminder.conditionMode = .exclude
        #expect(reminder.skyConditionDescription == "Not rainy")
    }

    @Test("Multiple conditions are listed")
    func skyConditionDescriptionMultipleConditions() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.sunny, .partlyCloudy]
        reminder.conditionMode = .include
        let description = reminder.skyConditionDescription
        #expect(description.contains("Sunny"))
        #expect(description.contains("Partly Cloudy"))
    }

    @Test("Empty conditions show Any weather")
    func skyConditionDescriptionEmpty() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = []
        #expect(reminder.skyConditionDescription == "Any weather")
    }

    // MARK: - Sky Condition Matching

    @Test("Include mode matches selected conditions")
    func matchesSkyConditionIncludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.sunny, .partlyCloudy]
        reminder.conditionMode = .include

        #expect(reminder.matchesSkyCondition(for: .clear) == true)
        #expect(reminder.matchesSkyCondition(for: .partlyCloudy) == true)
        #expect(reminder.matchesSkyCondition(for: .rain) == false)
        #expect(reminder.matchesSkyCondition(for: .snow) == false)
    }

    @Test("Exclude mode rejects selected conditions")
    func matchesSkyConditionExcludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.rainy, .snowy]
        reminder.conditionMode = .exclude

        #expect(reminder.matchesSkyCondition(for: .clear) == true)
        #expect(reminder.matchesSkyCondition(for: .partlyCloudy) == true)
        #expect(reminder.matchesSkyCondition(for: .rain) == false)
        #expect(reminder.matchesSkyCondition(for: .snow) == false)
    }

    @Test("Empty include matches any weather")
    func matchesSkyConditionEmptyInclude() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = []
        reminder.conditionMode = .include

        #expect(reminder.matchesSkyCondition(for: .clear) == true)
        #expect(reminder.matchesSkyCondition(for: .rain) == true)
    }

    // MARK: - Location Display Name

    @Test("Current location shows Current Location")
    func locationDisplayNameCurrentLocation() {
        let reminder = CustomReminder()
        #expect(reminder.locationDisplayName == "Current Location")
    }

    @Test("Manual location shows city, state, country")
    func locationDisplayNameManualLocation() {
        var reminder = CustomReminder()
        let manual = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            country: "US",
            administrativeArea: "CO"
        )
        reminder.selectedLocation = .manual(manual)
        #expect(reminder.locationDisplayName == "Denver, CO, US")
    }

    // MARK: - Icon Catalog

    @Test("Available icons contains at least 40 entries")
    func availableIconsNotEmpty() {
        #expect(CustomReminder.availableIcons.isEmpty == false)
        #expect(CustomReminder.availableIcons.count >= 40)
    }

    @Test("Expected icons are present in catalog")
    func availableIconsContainsExpectedIcons() {
        let icons = CustomReminder.availableIcons
        #expect(icons.contains("figure.walk"))
        #expect(icons.contains("bicycle"))
        #expect(icons.contains("car.fill"))
        #expect(icons.contains("star.fill"))
    }

    // MARK: - Color Palette

    @Test("Exactly 12 colors are available")
    func availableColorsNotEmpty() {
        #expect(CustomReminder.availableColors.isEmpty == false)
        #expect(CustomReminder.availableColors.count == 12)
    }

    @Test("Every color has a non-empty name")
    func availableColorsHaveNames() {
        for color in CustomReminder.availableColors {
            #expect(color.name.isEmpty == false)
        }
    }

    // MARK: - Preview Strings

    @Test("Preview title includes the reminder title")
    func previewTitle() {
        var reminder = CustomReminder()
        reminder.title = "Hike"
        #expect(reminder.previewTitle.contains("Hike"))
    }

    @Test("Preview body includes temperature and title")
    func previewBody() {
        var reminder = CustomReminder()
        reminder.title = "Walk"
        reminder.temperatureType = .temperatureRange
        reminder.minTemperature = 65
        reminder.maxTemperature = 75
        let body = reminder.previewBody
        #expect(body.contains("70"))
        #expect(body.lowercased().contains("walk"))
    }
}

// MARK: - ReminderLocationSelection Tests

@MainActor
struct ReminderLocationSelectionTests {

    @Test("Current location display name")
    func currentLocationDisplayName() {
        let selection = ReminderLocationSelection.currentLocation
        #expect(selection.displayName == "Current Location")
    }

    @Test("Current location flag is true")
    func currentLocationIsCurrentLocation() {
        let selection = ReminderLocationSelection.currentLocation
        #expect(selection.isCurrentLocation == true)
    }

    @Test("Manual location shows full display name")
    func manualLocationDisplayName() {
        let location = ManualLocationData(
            name: "New York",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            country: "US",
            administrativeArea: "NY"
        )
        let selection = ReminderLocationSelection.manual(location)
        #expect(selection.displayName == "New York, NY, US")
    }

    @Test("Manual location is not current location")
    func manualLocationIsNotCurrentLocation() {
        let location = ManualLocationData(
            name: "Tokyo",
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        )
        let selection = ReminderLocationSelection.manual(location)
        #expect(selection.isCurrentLocation == false)
    }

    @Test("Same-type selections are equal")
    func equality() {
        #expect(ReminderLocationSelection.currentLocation == ReminderLocationSelection.currentLocation)

        let loc1 = ManualLocationData(
            name: "Paris",
            coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        )
        let selection1 = ReminderLocationSelection.manual(loc1)
        let selection2 = ReminderLocationSelection.manual(loc1)
        #expect(selection1 == selection2)

        #expect(ReminderLocationSelection.currentLocation != selection1)
    }

    @Test("Different manual locations are not equal")
    func inequalityDifferentManualLocations() {
        let loc1 = ManualLocationData(
            name: "London",
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        )
        let loc2 = ManualLocationData(
            name: "Berlin",
            coordinate: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        )
        #expect(
            ReminderLocationSelection.manual(loc1) != ReminderLocationSelection.manual(loc2)
        )
    }
}

// MARK: - SkyCondition Tests

@MainActor
struct SkyConditionTests {

    @Test("All 5 sky conditions are present")
    func allCases() {
        #expect(SkyCondition.allCases.count == 5)
    }

    @Test("Display names match expected values")
    func displayNames() {
        #expect(SkyCondition.sunny.displayName == "Sunny")
        #expect(SkyCondition.partlyCloudy.displayName == "Partly Cloudy")
        #expect(SkyCondition.cloudy.displayName == "Cloudy")
        #expect(SkyCondition.rainy.displayName == "Rainy")
        #expect(SkyCondition.snowy.displayName == "Snowy")
    }

    @Test("Icons match expected SF Symbols")
    func icons() {
        #expect(SkyCondition.sunny.icon == "sun.max.fill")
        #expect(SkyCondition.rainy.icon == "cloud.rain.fill")
        #expect(SkyCondition.snowy.icon == "cloud.snow.fill")
    }

    @Test(
        "MockWeatherCondition maps to expected SkyCondition",
        arguments: [
            (MockWeatherCondition.clear, SkyCondition.sunny),
            (.partlyCloudy, .partlyCloudy),
            (.cloudy, .cloudy),
            (.rain, .rainy),
            (.snow, .snowy)
        ]
    )
    func fromMockWeatherCondition(mock: MockWeatherCondition, expected: SkyCondition) {
        #expect(SkyCondition.from(mock) == expected)
    }

    @Test(
        "WeatherCondition maps to expected SkyCondition",
        arguments: [
            (WeatherCondition.clear, SkyCondition.sunny),
            (.rain, .rainy),
            (.snow, .snowy),
            (.fog, .cloudy),
            (.thunderstorm, .rainy)
        ]
    )
    func fromWeatherCondition(condition: WeatherCondition, expected: SkyCondition) {
        #expect(SkyCondition.from(condition) == expected)
    }

    @Test("SkyCondition round-trips through Codable")
    func codable() throws {
        let original = SkyCondition.partlyCloudy
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkyCondition.self, from: data)
        #expect(original == decoded)
    }
}

// MARK: - ConditionSelectionMode Tests

@MainActor
struct ConditionSelectionModeTests {

    @Test("Include raw value")
    func includeMode() {
        #expect(ConditionSelectionMode.include.rawValue == "include")
    }

    @Test("Exclude raw value")
    func excludeMode() {
        #expect(ConditionSelectionMode.exclude.rawValue == "exclude")
    }

    @Test("ConditionSelectionMode round-trips through Codable")
    func codable() throws {
        let original = ConditionSelectionMode.exclude
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConditionSelectionMode.self, from: data)
        #expect(original == decoded)
    }
}

// MARK: - TimeRange Tests

@MainActor
struct TimeRangeTests {

    @Test("All 4 time ranges are present")
    func allCases() {
        #expect(TimeRange.allCases.count == 4)
    }

    @Test(
        "Display names match expected values",
        arguments: [
            (TimeRange.morning, "Morning"),
            (.afternoon, "Afternoon"),
            (.evening, "Evening"),
            (.allDay, "All Day")
        ]
    )
    func displayNames(range: TimeRange, expected: String) {
        #expect(range.displayName == expected)
    }

    @Test(
        "Icons match expected SF Symbols",
        arguments: [
            (TimeRange.morning, "sunrise.fill"),
            (.afternoon, "sun.max.fill"),
            (.evening, "sunset.fill"),
            (.allDay, "clock.fill")
        ]
    )
    func icons(range: TimeRange, expected: String) {
        #expect(range.icon == expected)
    }

    @Test(
        "Hour ranges match expected bounds",
        arguments: [
            (TimeRange.morning, 6...11),
            (.afternoon, 12...17),
            (.evening, 18...21),
            (.allDay, 6...21)
        ]
    )
    func hourRanges(range: TimeRange, expected: ClosedRange<Int>) {
        #expect(range.hours == expected)
    }

    @Test("Morning does not overlap afternoon")
    func morningDoesNotOverlapAfternoon() {
        #expect(TimeRange.morning.hours.upperBound < TimeRange.afternoon.hours.lowerBound)
    }

    @Test("All Day covers all other time ranges")
    func allDayCoversOtherRanges() {
        let allDay = TimeRange.allDay.hours
        #expect(allDay.contains(TimeRange.morning.hours.lowerBound))
        #expect(allDay.contains(TimeRange.afternoon.hours.lowerBound))
        #expect(allDay.contains(TimeRange.evening.hours.lowerBound))
    }
}

// MARK: - TriggerLikelihood Tests

@MainActor
struct TriggerLikelihoodTests {

    @Test("Every percentage tier produces a non-nil color")
    func colorsExist() {
        let percentages = [0, 20, 40, 60, 90]
        for pct in percentages {
            let likelihood = TriggerLikelihood(percentage: Double(pct), description: "", triggerDays: [])
            #expect(likelihood.color != nil)
        }
    }

    @Test("Trigger days are tracked correctly")
    func triggerDaysTracked() throws {
        let today = Date()
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let likelihood = TriggerLikelihood(
            percentage: 28.5,
            description: "Low chance",
            triggerDays: [today, tomorrow]
        )
        #expect(likelihood.triggerDays.count == 2)
        #expect(likelihood.percentage == 28.5)
    }
}

// MARK: - TemperatureConditionType Tests

@MainActor
struct TemperatureConditionTypeTests {

    @Test("Both condition types are present")
    func allCases() {
        #expect(TemperatureConditionType.allCases.count == 2)
    }

    @Test(
        "Display names and icons match",
        arguments: [
            (TemperatureConditionType.temperatureRange, "Temperature Range", "thermometer.medium"),
            (.exactTemperature, "Exact Temperature", "thermometer")
        ]
    )
    func displayNamesAndIcons(type: TemperatureConditionType, name: String, icon: String) {
        #expect(type.displayName == name)
        #expect(type.icon == icon)
    }
}

// MARK: - WeatherConditionType Tests

@MainActor
struct WeatherConditionTypeTests {

    @Test("All 5 weather condition types are present")
    func allCases() {
        #expect(WeatherConditionType.allCases.count == 5)
    }

    @Test(
        "Display names match expected values",
        arguments: [
            (WeatherConditionType.temperatureRange, "Temperature Range"),
            (.exactTemperature, "Exact Temperature"),
            (.sunny, "Sunny"),
            (.partlyCloudy, "Partly Cloudy"),
            (.rainy, "No Rain")
        ]
    )
    func displayNames(type: WeatherConditionType, expected: String) {
        #expect(type.displayName == expected)
    }

    @Test("Every type has a non-empty icon")
    func iconsNotEmpty() {
        for type in WeatherConditionType.allCases {
            #expect(type.icon.isEmpty == false)
        }
    }
}

// MARK: - Reminder Creation ViewModel Tests

@MainActor
struct ReminderCreationViewModelTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let viewModel: FirstReminderCreationViewModel

    init() throws {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self,
            UserPreferences.self,
            SavedLocation.self,
            LocationHistory.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        viewModel = FirstReminderCreationViewModel()
        viewModel.configure(modelContext: modelContext)
    }

    // MARK: - Initial State

    @Test("View model starts in expected default state")
    func initialState() {
        #expect(viewModel.isCreatingReminder == false)
        #expect(viewModel.showLocationPicker == false)
        #expect(viewModel.selectedTemplate == nil)
        #expect(viewModel.weatherForecast.isEmpty)
        #expect(viewModel.triggerLikelihood == nil)
    }

    // MARK: - Validation

    @Test("Empty title is invalid")
    func isReminderValidEmptyTitle() {
        viewModel.customReminder.title = ""
        #expect(viewModel.isReminderValid == false)
    }

    @Test("Whitespace-only title is invalid")
    func isReminderValidWhitespaceTitle() {
        viewModel.customReminder.title = "   "
        #expect(viewModel.isReminderValid == false)
    }

    @Test("Non-empty title is valid")
    func isReminderValidNonEmptyTitle() {
        viewModel.customReminder.title = "Morning Walk"
        #expect(viewModel.isReminderValid == true)
    }

    // MARK: - Location Selection

    @Test("Selecting a manual location updates the reminder")
    func selectManualLocation() {
        let location = ManualLocationData(
            name: "Chicago",
            coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
            country: "US",
            administrativeArea: "IL"
        )

        viewModel.showLocationPicker = true
        viewModel.selectManualLocation(location)

        #expect(viewModel.customReminder.selectedLocation.isCurrentLocation == false)
        #expect(viewModel.customReminder.locationDisplayName == "Chicago, IL, US")
        #expect(viewModel.showLocationPicker == false)
    }

    @Test("Reverting to current location clears manual selection")
    func selectCurrentLocation() {
        let location = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        )
        viewModel.selectManualLocation(location)

        viewModel.showLocationPicker = true
        viewModel.selectCurrentLocation()

        #expect(viewModel.customReminder.selectedLocation.isCurrentLocation == true)
        #expect(viewModel.customReminder.locationDisplayName == "Current Location")
        #expect(viewModel.showLocationPicker == false)
    }

    // MARK: - Template Selection

    @Test("Template applies its defaults to the reminder")
    func selectTemplate() {
        let template = ReminderTemplate(
            id: UUID(),
            title: "Outdoor Walk",
            description: "Go for a walk",
            icon: "figure.walk",
            color: .blue,
            defaultTitle: "Walk",
            iconName: "figure.walk",
            condition: .temperatureRange,
            minTemperature: 60,
            maxTemperature: 80,
            exampleTrigger: "65-75\u{00B0}F"
        )

        viewModel.selectTemplate(template)

        #expect(viewModel.customReminder.title == "Walk")
        #expect(viewModel.customReminder.selectedIcon == "figure.walk")
        #expect(viewModel.customReminder.temperatureType == .temperatureRange)
        #expect(viewModel.customReminder.minTemperature == 60)
        #expect(viewModel.customReminder.maxTemperature == 80)
    }

    // MARK: - Reminder Creation

    @Test("Creating a reminder with manual location persists correctly")
    func createReminderWithManualLocation() throws {
        viewModel.customReminder.title = "Beach Day"
        viewModel.customReminder.temperatureType = .temperatureRange
        viewModel.customReminder.minTemperature = 75
        viewModel.customReminder.maxTemperature = 90
        viewModel.customReminder.selectedSkyConditions = [.sunny]
        viewModel.customReminder.conditionMode = .include
        viewModel.customReminder.preferredTimeRange = .afternoon

        let manualLocation = ManualLocationData(
            name: "Miami",
            coordinate: CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918),
            country: "US",
            administrativeArea: "FL"
        )
        viewModel.selectManualLocation(manualLocation)
        viewModel.createReminder()

        let reminders = try modelContext.fetch(FetchDescriptor<WeatherReminder>())

        #expect(reminders.count == 1)

        let reminder = try #require(reminders.first)
        #expect(reminder.title == "Beach Day")
        #expect(reminder.isActive == true)

        let location = try #require(reminder.location)
        #expect(location.city == "Miami")
        #expect(location.isManuallyEntered == true)
        #expect(location.state == "FL")
        #expect(location.country == "US")

        let condition = try #require(reminder.triggerCondition)
        #expect(condition.triggerType == .temperatureRange)
        #expect(condition.minTemperature == 75)
        #expect(condition.maxTemperature == 90)
        #expect(condition.selectedSkyConditions == [.sunny])
        #expect(condition.conditionMode == .include)
    }

    @Test("Exclude sky conditions are persisted")
    func createReminderWithExcludeSkyConditions() throws {
        viewModel.customReminder.title = "Dog Walk"
        viewModel.customReminder.selectedSkyConditions = [.rainy, .snowy]
        viewModel.customReminder.conditionMode = .exclude

        let location = ManualLocationData(
            name: "Seattle",
            coordinate: CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        )
        viewModel.selectManualLocation(location)
        viewModel.createReminder()

        let reminders = try modelContext.fetch(FetchDescriptor<WeatherReminder>())
        let reminder = try #require(reminders.first)

        #expect(reminder.triggerCondition?.conditionMode == .exclude)
        #expect(reminder.triggerCondition?.selectedSkyConditions.contains(.rainy) == true)
        #expect(reminder.triggerCondition?.selectedSkyConditions.contains(.snowy) == true)
    }

    @Test("Invalid title prevents save")
    func createReminderInvalidTitleDoesNotSave() throws {
        viewModel.customReminder.title = ""
        viewModel.createReminder()

        let reminders = try modelContext.fetch(FetchDescriptor<WeatherReminder>())
        #expect(reminders.count == 0)
    }

    // MARK: - Forecast & Likelihood

    @Test("Loading weather without a location does not fabricate forecast data")
    func loadWeatherDoesNotFabricateForecast() async throws {
        viewModel.loadWeather()

        try await Task.sleep(for: .seconds(1))
        #expect(viewModel.weatherForecast.isEmpty)
        #expect(viewModel.triggerLikelihood == nil)
        #expect(viewModel.hasCurrentWeather == false)
    }

    @Test("Likelihood is calculated from forecast data")
    func calculateLikelihood() throws {
        let today = Date()
        viewModel.weatherForecast = try (0..<7).map { i in
            let date = try #require(Calendar.current.date(byAdding: .day, value: i, to: today))

            return WeatherForecastDay(
                date: date,
                highTemp: 70 + i * 2,
                lowTemp: 55 + i,
                weatherCondition: i < 5 ? .clear : .rain
            )
        }

        viewModel.customReminder.temperatureType = .temperatureRange
        viewModel.customReminder.minTemperature = 65
        viewModel.customReminder.maxTemperature = 80
        viewModel.customReminder.selectedSkyConditions = [.sunny]
        viewModel.customReminder.conditionMode = .include

        viewModel.calculateLikelihood()

        let likelihood = try #require(viewModel.triggerLikelihood)
        #expect(likelihood.percentage > 0)
    }
}

// MARK: - ManualLocationData Tests

@MainActor
struct ManualLocationDataTests {

    @Test("Initialization stores all properties")
    func initialization() {
        let location = ManualLocationData(
            name: "Austin",
            coordinate: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            country: "US",
            administrativeArea: "TX"
        )

        #expect(location.name == "Austin")
        #expect(location.country == "US")
        #expect(location.administrativeArea == "TX")
    }

    @Test("Full display name includes city, state, country")
    func displayNameFull() {
        let location = ManualLocationData(
            name: "Portland",
            coordinate: CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784),
            country: "US",
            administrativeArea: "OR"
        )
        #expect(location.displayName == "Portland, OR, US")
    }

    @Test("City-only location shows just the name")
    func displayNameCityOnly() {
        let location = ManualLocationData(
            name: "Tokyo",
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        )
        #expect(location.displayName == "Tokyo")
    }

    @Test("ManualLocationData round-trips through Codable")
    func codable() throws {
        let original = ManualLocationData(
            name: "London",
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            country: "UK",
            administrativeArea: "England"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ManualLocationData.self, from: data)

        #expect(decoded.name == "London")
        #expect(decoded.country == "UK")
    }

    @Test("Separate instances get unique IDs")
    func uniqueIDs() {
        let loc1 = ManualLocationData(
            name: "A",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        let loc2 = ManualLocationData(
            name: "B",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        #expect(loc1.id != loc2.id)
    }
}
