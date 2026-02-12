//
//  ReminderCreationTests.swift
//  SunHatTests
//
//  Created by Wesley Keetch on 2/12/26.
//

import XCTest
import SwiftUI
import SwiftData
import CoreLocation
@testable import SunHat

// MARK: - CustomReminder Model Tests

@MainActor
final class CustomReminderTests: XCTestCase {

    // MARK: - Default Values

    func testDefaultValues() {
        let reminder = CustomReminder()

        XCTAssertEqual(reminder.title, "")
        XCTAssertEqual(reminder.selectedIcon, "figure.walk")
        XCTAssertEqual(reminder.notes, "")
        XCTAssertEqual(reminder.minTemperature, 65)
        XCTAssertEqual(reminder.maxTemperature, 75)
        XCTAssertEqual(reminder.conditionMode, .include)
        XCTAssertEqual(reminder.preferredTimeRange, .allDay)
        XCTAssertTrue(reminder.respectQuietHours)
        XCTAssertTrue(reminder.selectedLocation.isCurrentLocation)
    }

    // MARK: - Display Title

    func testDisplayTitleWhenEmpty() {
        let reminder = CustomReminder()
        XCTAssertEqual(reminder.displayTitle, "New Reminder")
    }

    func testDisplayTitleWithCustomTitle() {
        var reminder = CustomReminder()
        reminder.title = "Morning Walk"
        XCTAssertEqual(reminder.displayTitle, "Morning Walk")
    }

    // MARK: - Temperature Description

    func testTemperatureRangeDescription() {
        var reminder = CustomReminder()
        reminder.temperatureType = .temperatureRange
        reminder.minTemperature = 60
        reminder.maxTemperature = 80
        XCTAssertEqual(reminder.temperatureDescription, "60\u{00B0} - 80\u{00B0}F")
    }

    func testExactTemperatureDescription() {
        var reminder = CustomReminder()
        reminder.temperatureType = .exactTemperature
        reminder.minTemperature = 72
        XCTAssertEqual(reminder.temperatureDescription, "72\u{00B0}F")
    }

    // MARK: - Sky Condition Description

    func testSkyConditionDescriptionIncludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.sunny]
        reminder.conditionMode = .include
        XCTAssertEqual(reminder.skyConditionDescription, "Sunny")
    }

    func testSkyConditionDescriptionExcludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.rainy]
        reminder.conditionMode = .exclude
        XCTAssertEqual(reminder.skyConditionDescription, "Not rainy")
    }

    func testSkyConditionDescriptionMultipleConditions() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.sunny, .partlyCloudy]
        reminder.conditionMode = .include
        let description = reminder.skyConditionDescription
        XCTAssertTrue(description.contains("Sunny"))
        XCTAssertTrue(description.contains("Partly Cloudy"))
    }

    func testSkyConditionDescriptionEmpty() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = []
        XCTAssertEqual(reminder.skyConditionDescription, "Any weather")
    }

    // MARK: - Sky Condition Matching

    func testMatchesSkyConditionIncludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.sunny, .partlyCloudy]
        reminder.conditionMode = .include

        XCTAssertTrue(reminder.matchesSkyCondition(for: .clear), "Clear should match Sunny in include mode")
        XCTAssertTrue(reminder.matchesSkyCondition(for: .partlyCloudy), "Partly Cloudy should match")
        XCTAssertFalse(reminder.matchesSkyCondition(for: .rain), "Rain should NOT match")
        XCTAssertFalse(reminder.matchesSkyCondition(for: .snow), "Snow should NOT match")
    }

    func testMatchesSkyConditionExcludeMode() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = [.rainy, .snowy]
        reminder.conditionMode = .exclude

        XCTAssertTrue(reminder.matchesSkyCondition(for: .clear), "Clear should match (not excluded)")
        XCTAssertTrue(reminder.matchesSkyCondition(for: .partlyCloudy), "Partly Cloudy should match (not excluded)")
        XCTAssertFalse(reminder.matchesSkyCondition(for: .rain), "Rain should NOT match (excluded)")
        XCTAssertFalse(reminder.matchesSkyCondition(for: .snow), "Snow should NOT match (excluded)")
    }

    func testMatchesSkyConditionEmptyInclude() {
        var reminder = CustomReminder()
        reminder.selectedSkyConditions = []
        reminder.conditionMode = .include

        // Empty include means "any weather"
        XCTAssertTrue(reminder.matchesSkyCondition(for: .clear))
        XCTAssertTrue(reminder.matchesSkyCondition(for: .rain))
    }

    // MARK: - Location Display Name

    func testLocationDisplayNameCurrentLocation() {
        let reminder = CustomReminder()
        XCTAssertEqual(reminder.locationDisplayName, "Current Location")
    }

    func testLocationDisplayNameManualLocation() {
        var reminder = CustomReminder()
        let manual = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            country: "US",
            administrativeArea: "CO"
        )
        reminder.selectedLocation = .manual(manual)
        XCTAssertEqual(reminder.locationDisplayName, "Denver, CO, US")
    }

    // MARK: - Icon Catalog

    func testAvailableIconsNotEmpty() {
        XCTAssertFalse(CustomReminder.availableIcons.isEmpty)
        XCTAssertGreaterThanOrEqual(CustomReminder.availableIcons.count, 40)
    }

    func testAvailableIconsContainsExpectedIcons() {
        let icons = CustomReminder.availableIcons
        XCTAssertTrue(icons.contains("figure.walk"))
        XCTAssertTrue(icons.contains("bicycle"))
        XCTAssertTrue(icons.contains("car.fill"))
        XCTAssertTrue(icons.contains("star.fill"))
    }

    // MARK: - Color Palette

    func testAvailableColorsNotEmpty() {
        XCTAssertFalse(CustomReminder.availableColors.isEmpty)
        XCTAssertEqual(CustomReminder.availableColors.count, 12)
    }

    func testAvailableColorsHaveNames() {
        for color in CustomReminder.availableColors {
            XCTAssertFalse(color.name.isEmpty)
        }
    }

    // MARK: - Preview Strings

    func testPreviewTitle() {
        var reminder = CustomReminder()
        reminder.title = "Hike"
        XCTAssertTrue(reminder.previewTitle.contains("Hike"))
    }

    func testPreviewBody() {
        var reminder = CustomReminder()
        reminder.title = "Walk"
        reminder.temperatureType = .temperatureRange
        reminder.minTemperature = 65
        reminder.maxTemperature = 75
        let body = reminder.previewBody
        XCTAssertTrue(body.contains("70"))
        XCTAssertTrue(body.lowercased().contains("walk"))
    }
}

// MARK: - ReminderLocationSelection Tests

@MainActor
final class ReminderLocationSelectionTests: XCTestCase {

    func testCurrentLocationDisplayName() {
        let selection = ReminderLocationSelection.currentLocation
        XCTAssertEqual(selection.displayName, "Current Location")
    }

    func testCurrentLocationIsCurrentLocation() {
        let selection = ReminderLocationSelection.currentLocation
        XCTAssertTrue(selection.isCurrentLocation)
    }

    func testManualLocationDisplayName() {
        let location = ManualLocationData(
            name: "New York",
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            country: "US",
            administrativeArea: "NY"
        )
        let selection = ReminderLocationSelection.manual(location)
        XCTAssertEqual(selection.displayName, "New York, NY, US")
    }

    func testManualLocationIsNotCurrentLocation() {
        let location = ManualLocationData(
            name: "Tokyo",
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        )
        let selection = ReminderLocationSelection.manual(location)
        XCTAssertFalse(selection.isCurrentLocation)
    }

    func testEquality() {
        XCTAssertEqual(ReminderLocationSelection.currentLocation, ReminderLocationSelection.currentLocation)

        let loc1 = ManualLocationData(
            name: "Paris",
            coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        )
        let selection1 = ReminderLocationSelection.manual(loc1)
        let selection2 = ReminderLocationSelection.manual(loc1)
        XCTAssertEqual(selection1, selection2)

        XCTAssertNotEqual(ReminderLocationSelection.currentLocation, selection1)
    }

    func testInequalityDifferentManualLocations() {
        let loc1 = ManualLocationData(
            name: "London",
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        )
        let loc2 = ManualLocationData(
            name: "Berlin",
            coordinate: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        )
        XCTAssertNotEqual(
            ReminderLocationSelection.manual(loc1),
            ReminderLocationSelection.manual(loc2)
        )
    }
}

// MARK: - SkyCondition Tests

@MainActor
final class SkyConditionTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(SkyCondition.allCases.count, 5)
    }

    func testDisplayNames() {
        XCTAssertEqual(SkyCondition.sunny.displayName, "Sunny")
        XCTAssertEqual(SkyCondition.partlyCloudy.displayName, "Partly Cloudy")
        XCTAssertEqual(SkyCondition.cloudy.displayName, "Cloudy")
        XCTAssertEqual(SkyCondition.rainy.displayName, "Rainy")
        XCTAssertEqual(SkyCondition.snowy.displayName, "Snowy")
    }

    func testIcons() {
        XCTAssertEqual(SkyCondition.sunny.icon, "sun.max.fill")
        XCTAssertEqual(SkyCondition.rainy.icon, "cloud.rain.fill")
        XCTAssertEqual(SkyCondition.snowy.icon, "cloud.snow.fill")
    }

    func testFromMockWeatherCondition() {
        XCTAssertEqual(SkyCondition.from(MockWeatherCondition.clear), .sunny)
        XCTAssertEqual(SkyCondition.from(MockWeatherCondition.partlyCloudy), .partlyCloudy)
        XCTAssertEqual(SkyCondition.from(MockWeatherCondition.cloudy), .cloudy)
        XCTAssertEqual(SkyCondition.from(MockWeatherCondition.rain), .rainy)
        XCTAssertEqual(SkyCondition.from(MockWeatherCondition.snow), .snowy)
    }

    func testFromWeatherCondition() {
        XCTAssertEqual(SkyCondition.from(WeatherCondition.clear), .sunny)
        XCTAssertEqual(SkyCondition.from(WeatherCondition.rain), .rainy)
        XCTAssertEqual(SkyCondition.from(WeatherCondition.snow), .snowy)
        XCTAssertEqual(SkyCondition.from(WeatherCondition.fog), .cloudy)
        XCTAssertEqual(SkyCondition.from(WeatherCondition.thunderstorm), .rainy)
    }

    func testCodable() throws {
        let original = SkyCondition.partlyCloudy
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkyCondition.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ConditionSelectionMode Tests

@MainActor
final class ConditionSelectionModeTests: XCTestCase {

    func testIncludeMode() {
        let mode = ConditionSelectionMode.include
        XCTAssertEqual(mode.rawValue, "include")
    }

    func testExcludeMode() {
        let mode = ConditionSelectionMode.exclude
        XCTAssertEqual(mode.rawValue, "exclude")
    }

    func testCodable() throws {
        let original = ConditionSelectionMode.exclude
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConditionSelectionMode.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - TimeRange Tests

@MainActor
final class TimeRangeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(TimeRange.allCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(TimeRange.morning.displayName, "Morning")
        XCTAssertEqual(TimeRange.afternoon.displayName, "Afternoon")
        XCTAssertEqual(TimeRange.evening.displayName, "Evening")
        XCTAssertEqual(TimeRange.allDay.displayName, "All Day")
    }

    func testIcons() {
        XCTAssertEqual(TimeRange.morning.icon, "sunrise.fill")
        XCTAssertEqual(TimeRange.afternoon.icon, "sun.max.fill")
        XCTAssertEqual(TimeRange.evening.icon, "sunset.fill")
        XCTAssertEqual(TimeRange.allDay.icon, "clock.fill")
    }

    func testHourRanges() {
        XCTAssertEqual(TimeRange.morning.hours, 6...11)
        XCTAssertEqual(TimeRange.afternoon.hours, 12...17)
        XCTAssertEqual(TimeRange.evening.hours, 18...21)
        XCTAssertEqual(TimeRange.allDay.hours, 6...21)
    }

    func testMorningDoesNotOverlapAfternoon() {
        let morningEnd = TimeRange.morning.hours.upperBound
        let afternoonStart = TimeRange.afternoon.hours.lowerBound
        XCTAssertLessThan(morningEnd, afternoonStart)
    }

    func testAllDayCoversOtherRanges() {
        let allDay = TimeRange.allDay.hours
        XCTAssertTrue(allDay.contains(TimeRange.morning.hours.lowerBound))
        XCTAssertTrue(allDay.contains(TimeRange.afternoon.hours.lowerBound))
        XCTAssertTrue(allDay.contains(TimeRange.evening.hours.lowerBound))
    }
}

// MARK: - TriggerLikelihood Tests

@MainActor
final class TriggerLikelihoodTests: XCTestCase {

    func testUnlikelyColor() {
        let likelihood = TriggerLikelihood(percentage: 0, description: "Unlikely", triggerDays: [])
        XCTAssertNotNil(likelihood.color)
    }

    func testLowChanceColor() {
        let likelihood = TriggerLikelihood(percentage: 20, description: "Low chance", triggerDays: [])
        XCTAssertNotNil(likelihood.color)
    }

    func testModerateColor() {
        let likelihood = TriggerLikelihood(percentage: 40, description: "Moderate", triggerDays: [])
        XCTAssertNotNil(likelihood.color)
    }

    func testGoodChanceColor() {
        let likelihood = TriggerLikelihood(percentage: 60, description: "Good chance", triggerDays: [])
        XCTAssertNotNil(likelihood.color)
    }

    func testVeryLikelyColor() {
        let likelihood = TriggerLikelihood(percentage: 90, description: "Very likely", triggerDays: [])
        XCTAssertNotNil(likelihood.color)
    }

    func testTriggerDaysTracked() {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let likelihood = TriggerLikelihood(
            percentage: 28.5,
            description: "Low chance",
            triggerDays: [today, tomorrow]
        )
        XCTAssertEqual(likelihood.triggerDays.count, 2)
        XCTAssertEqual(likelihood.percentage, 28.5)
    }
}

// MARK: - TemperatureConditionType Tests

@MainActor
final class TemperatureConditionTypeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(TemperatureConditionType.allCases.count, 2)
    }

    func testDisplayNames() {
        XCTAssertEqual(TemperatureConditionType.temperatureRange.displayName, "Temperature Range")
        XCTAssertEqual(TemperatureConditionType.exactTemperature.displayName, "Exact Temperature")
    }

    func testIcons() {
        XCTAssertEqual(TemperatureConditionType.temperatureRange.icon, "thermometer.medium")
        XCTAssertEqual(TemperatureConditionType.exactTemperature.icon, "thermometer")
    }
}

// MARK: - WeatherConditionType Tests

@MainActor
final class WeatherConditionTypeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(WeatherConditionType.allCases.count, 5)
    }

    func testDisplayNames() {
        XCTAssertEqual(WeatherConditionType.temperatureRange.displayName, "Temperature Range")
        XCTAssertEqual(WeatherConditionType.exactTemperature.displayName, "Exact Temperature")
        XCTAssertEqual(WeatherConditionType.sunny.displayName, "Sunny")
        XCTAssertEqual(WeatherConditionType.partlyCloudy.displayName, "Partly Cloudy")
        XCTAssertEqual(WeatherConditionType.rainy.displayName, "No Rain")
    }

    func testIcons() {
        XCTAssertFalse(WeatherConditionType.temperatureRange.icon.isEmpty)
        XCTAssertFalse(WeatherConditionType.sunny.icon.isEmpty)
    }
}

// MARK: - Reminder Creation ViewModel Tests

@MainActor
final class ReminderCreationViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: FirstReminderCreationViewModel!

    override func setUp() async throws {
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

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        viewModel = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertFalse(viewModel.isCreatingReminder)
        XCTAssertFalse(viewModel.showLocationPicker)
        XCTAssertNil(viewModel.selectedTemplate)
        XCTAssertTrue(viewModel.weatherForecast.isEmpty)
        XCTAssertNil(viewModel.triggerLikelihood)
    }

    // MARK: - Validation

    func testIsReminderValidEmptyTitle() {
        viewModel.customReminder.title = ""
        XCTAssertFalse(viewModel.isReminderValid)
    }

    func testIsReminderValidWhitespaceTitle() {
        viewModel.customReminder.title = "   "
        XCTAssertFalse(viewModel.isReminderValid)
    }

    func testIsReminderValidNonEmptyTitle() {
        viewModel.customReminder.title = "Morning Walk"
        XCTAssertTrue(viewModel.isReminderValid)
    }

    // MARK: - Location Selection

    func testSelectManualLocation() {
        let location = ManualLocationData(
            name: "Chicago",
            coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
            country: "US",
            administrativeArea: "IL"
        )

        viewModel.showLocationPicker = true
        viewModel.selectManualLocation(location)

        XCTAssertFalse(viewModel.customReminder.selectedLocation.isCurrentLocation)
        XCTAssertEqual(viewModel.customReminder.locationDisplayName, "Chicago, IL, US")
        XCTAssertFalse(viewModel.showLocationPicker)
    }

    func testSelectCurrentLocation() {
        let location = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        )
        viewModel.selectManualLocation(location)

        viewModel.showLocationPicker = true
        viewModel.selectCurrentLocation()

        XCTAssertTrue(viewModel.customReminder.selectedLocation.isCurrentLocation)
        XCTAssertEqual(viewModel.customReminder.locationDisplayName, "Current Location")
        XCTAssertFalse(viewModel.showLocationPicker)
    }

    // MARK: - Template Selection

    func testSelectTemplate() {
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

        XCTAssertEqual(viewModel.customReminder.title, "Walk")
        XCTAssertEqual(viewModel.customReminder.selectedIcon, "figure.walk")
        XCTAssertEqual(viewModel.customReminder.temperatureType, .temperatureRange)
        XCTAssertEqual(viewModel.customReminder.minTemperature, 60)
        XCTAssertEqual(viewModel.customReminder.maxTemperature, 80)
    }

    // MARK: - Reminder Creation

    func testCreateReminderWithManualLocation() throws {
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

        let descriptor = FetchDescriptor<WeatherReminder>()
        let reminders = try modelContext.fetch(descriptor)

        XCTAssertEqual(reminders.count, 1)

        let reminder = reminders.first!
        XCTAssertEqual(reminder.title, "Beach Day")
        XCTAssertTrue(reminder.isActive)

        XCTAssertNotNil(reminder.location)
        XCTAssertEqual(reminder.location?.city, "Miami")
        XCTAssertTrue(reminder.location?.isManuallyEntered ?? false)
        XCTAssertEqual(reminder.location?.state, "FL")
        XCTAssertEqual(reminder.location?.country, "US")
        XCTAssertEqual(reminder.location?.latitude ?? 0, 25.7617, accuracy: 0.001)

        XCTAssertNotNil(reminder.triggerCondition)
        XCTAssertEqual(reminder.triggerCondition?.triggerType, .temperatureRange)
        XCTAssertEqual(reminder.triggerCondition?.minTemperature, 75)
        XCTAssertEqual(reminder.triggerCondition?.maxTemperature, 90)

        XCTAssertEqual(reminder.triggerCondition?.selectedSkyConditions, [.sunny])
        XCTAssertEqual(reminder.triggerCondition?.conditionMode, .include)
    }

    func testCreateReminderWithExcludeSkyConditions() throws {
        viewModel.customReminder.title = "Dog Walk"
        viewModel.customReminder.selectedSkyConditions = [.rainy, .snowy]
        viewModel.customReminder.conditionMode = .exclude

        let location = ManualLocationData(
            name: "Seattle",
            coordinate: CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        )
        viewModel.selectManualLocation(location)
        viewModel.createReminder()

        let descriptor = FetchDescriptor<WeatherReminder>()
        let reminders = try modelContext.fetch(descriptor)
        let reminder = reminders.first!

        XCTAssertEqual(reminder.triggerCondition?.conditionMode, .exclude)
        XCTAssertTrue(reminder.triggerCondition?.selectedSkyConditions.contains(.rainy) ?? false)
        XCTAssertTrue(reminder.triggerCondition?.selectedSkyConditions.contains(.snowy) ?? false)
    }

    func testCreateReminderInvalidTitleDoesNotSave() throws {
        viewModel.customReminder.title = ""
        viewModel.createReminder()

        let descriptor = FetchDescriptor<WeatherReminder>()
        let reminders = try modelContext.fetch(descriptor)
        XCTAssertEqual(reminders.count, 0)
    }

    // MARK: - Forecast & Likelihood

    func testLoadWeatherForecast() {
        viewModel.loadWeatherForecast()

        let expectation = XCTestExpectation(description: "Forecast loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertFalse(self.viewModel.weatherForecast.isEmpty)
            XCTAssertEqual(self.viewModel.weatherForecast.count, 7)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
    }

    func testCalculateLikelihood() {
        let today = Date()
        viewModel.weatherForecast = (0..<7).map { i in
            WeatherForecastDay(
                date: Calendar.current.date(byAdding: .day, value: i, to: today)!,
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

        XCTAssertNotNil(viewModel.triggerLikelihood)
        XCTAssertGreaterThan(viewModel.triggerLikelihood!.percentage, 0)
    }
}

// MARK: - ManualLocationData Tests

@MainActor
final class ManualLocationDataTests: XCTestCase {

    func testInitialization() {
        let location = ManualLocationData(
            name: "Austin",
            coordinate: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            country: "US",
            administrativeArea: "TX"
        )

        XCTAssertEqual(location.name, "Austin")
        XCTAssertEqual(location.coordinate.latitude, 30.2672, accuracy: 0.001)
        XCTAssertEqual(location.coordinate.longitude, -97.7431, accuracy: 0.001)
        XCTAssertEqual(location.country, "US")
        XCTAssertEqual(location.administrativeArea, "TX")
    }

    func testDisplayNameFull() {
        let location = ManualLocationData(
            name: "Portland",
            coordinate: CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784),
            country: "US",
            administrativeArea: "OR"
        )
        XCTAssertEqual(location.displayName, "Portland, OR, US")
    }

    func testDisplayNameCityOnly() {
        let location = ManualLocationData(
            name: "Tokyo",
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        )
        XCTAssertEqual(location.displayName, "Tokyo")
    }

    func testCodable() throws {
        let original = ManualLocationData(
            name: "London",
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            country: "UK",
            administrativeArea: "England"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ManualLocationData.self, from: data)

        XCTAssertEqual(decoded.name, "London")
        XCTAssertEqual(decoded.country, "UK")
        XCTAssertEqual(decoded.coordinate.latitude, 51.5074, accuracy: 0.001)
    }

    func testUniqueIDs() {
        let loc1 = ManualLocationData(
            name: "A",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        let loc2 = ManualLocationData(
            name: "B",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        XCTAssertNotEqual(loc1.id, loc2.id)
    }
}
