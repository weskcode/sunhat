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
