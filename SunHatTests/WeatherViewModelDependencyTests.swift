//
//  WeatherViewModelDependencyTests.swift
//  SunHatTests
//

import Combine
import CoreLocation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct WeatherViewModelDependencyTests {
    @Test("WeatherViewModel loads current weather through WeatherProviding")
    func weatherViewModelLoadsThroughWeatherProviding() async throws {
        let weatherData = WeatherData(
            temperature: 72,
            feelsLike: 74,
            humidity: 55
        )
        weatherData.weatherDescription = "Sunny"
        weatherData.weatherCondition = .clear

        let provider = FakeWeatherProvider(weatherData: weatherData)
        let locationManager = FakeLocationManager()

        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: locationManager
        )

        try await waitUntil {
            viewModel.currentTemperature == 72
        }

        #expect(provider.fetchCount == 1)
        #expect(viewModel.locationName == "Test City")
        #expect(viewModel.currentTemperature == 72)
        #expect(viewModel.feelsLikeTemperature == 74)
        #expect(viewModel.weatherDescription == "Sunny")
        #expect(viewModel.weatherIconName == "sun.max.fill")
    }

    @Test("WeatherViewModel refreshes through the selected manual location")
    func weatherViewModelRefreshesSelectedManualLocation() async throws {
        let weatherData = WeatherData(
            temperature: 68,
            feelsLike: 67,
            humidity: 50
        )
        weatherData.weatherDescription = "Clouds clearing"
        weatherData.weatherCondition = .partlyCloudy

        let provider = FakeWeatherProvider(weatherData: weatherData)
        let locationManager = FakeLocationManager()
        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: locationManager
        )

        try await waitUntil {
            provider.fetchCount == 1
        }

        let selectedLocation = ReminderLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            displayName: "New York",
            fullAddress: "New York, NY",
            isCurrentLocation: false
        )

        await viewModel.updateSelectedLocation(selectedLocation)

        try await waitUntil {
            provider.fetchCount == 2
        }

        let lastCoordinate = try #require(provider.lastCoordinate)
        #expect(abs(lastCoordinate.latitude - 40.7128) < 0.0001)
        #expect(abs(lastCoordinate.longitude - -74.0060) < 0.0001)
        #expect(viewModel.locationName == "New York")
    }

    @Test("Weather backdrop palette maps clear warm and cloudy cold conditions")
    func weatherBackdropPaletteMapping() {
        let warmClear = WeatherData(temperature: 82, feelsLike: 84, humidity: 44)
        warmClear.weatherCondition = .clear
        warmClear.cloudCover = 12

        let cloudyWarm = WeatherData(temperature: 82, feelsLike: 82, humidity: 65)
        cloudyWarm.weatherCondition = .cloudy
        cloudyWarm.cloudCover = 80

        let coldClear = WeatherData(temperature: 38, feelsLike: 34, humidity: 40)
        coldClear.weatherCondition = .clear
        coldClear.cloudCover = 8

        let rain = WeatherData(temperature: 61, feelsLike: 60, humidity: 88)
        rain.weatherCondition = .rain

        #expect(WeatherBackdropPalette.palette(for: warmClear) == .brightBlue)
        #expect(WeatherBackdropPalette.palette(for: cloudyWarm) == .overcastBlue)
        #expect(WeatherBackdropPalette.palette(for: coldClear) == .frozenBlue)
        #expect(WeatherBackdropPalette.palette(for: rain) == .stormBlue)
    }

    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            LocationData.self,
            UserPreferences.self,
            TriggerCondition.self,
            NotificationConfig.self,
            ReminderHistory.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let start = ContinuousClock.now

        while ContinuousClock.now - start < timeout {
            if condition() {
                return
            }

            try await Task.sleep(for: .milliseconds(20))
        }

        Issue.record("Condition was not met before timeout")
    }
}

@MainActor
private final class FakeWeatherProvider: WeatherProviding {
    @Published private var isLoading = false
    @Published private var lastUpdateTime: Date?

    private let weatherData: WeatherData
    private(set) var fetchCount = 0
    private(set) var lastCoordinate: CLLocationCoordinate2D?

    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    var lastUpdateTimePublisher: AnyPublisher<Date?, Never> {
        $lastUpdateTime.eraseToAnyPublisher()
    }

    init(weatherData: WeatherData) {
        self.weatherData = weatherData
    }

    func fetchCurrentWeather(for location: CLLocation, forceRefresh: Bool) async throws -> WeatherData {
        fetchCount += 1
        lastCoordinate = location.coordinate
        lastUpdateTime = Date()
        return weatherData
    }
}

private struct FakeLocationManager: LocationManaging {
    func currentLocation() async -> (location: CLLocation, name: String)? {
        (
            CLLocation(latitude: 37.3349, longitude: -122.0090),
            "Test City"
        )
    }
}
