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

    @Test("Weekly forecast uses provider forecast days without fabricated padding")
    func weeklyForecastUsesProviderForecastDays() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))

        let weatherData = WeatherData(
            temperature: 72,
            feelsLike: 74,
            humidity: 55
        )
        weatherData.weatherDescription = "Sunny"
        weatherData.weatherCondition = .clear
        weatherData.forecastDays = [
            makeForecastDay(
                date: tomorrow,
                highTemperature: 78,
                lowTemperature: 61,
                condition: .partlyCloudy,
                description: "Partly cloudy",
                precipitationProbability: 25
            ),
            makeForecastDay(
                date: today,
                highTemperature: 76,
                lowTemperature: 58,
                condition: .clear,
                description: "Sunny",
                precipitationProbability: 5
            )
        ]

        let provider = FakeWeatherProvider(weatherData: weatherData)
        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: FakeLocationManager()
        )

        try await waitUntil {
            viewModel.weeklyForecast.count == 2
        }

        #expect(viewModel.weeklyForecast.map(\.date) == [today, tomorrow])
        #expect(viewModel.weeklyForecast.map(\.condition) == ["Sunny", "Partly cloudy"])
        #expect(viewModel.weeklyForecast.map(\.highTemp) == [76, 78])
        #expect(viewModel.weeklyForecast.map(\.lowTemp) == [58, 61])
        #expect(viewModel.weeklyForecast.map(\.precipitationProbability) == [5, 25])
    }

    @Test("Weekly forecast remains empty when provider has no forecast days")
    func weeklyForecastEmptyWhenProviderHasNoForecastDays() async throws {
        let weatherData = WeatherData(
            temperature: 72,
            feelsLike: 74,
            humidity: 55
        )

        let provider = FakeWeatherProvider(weatherData: weatherData)
        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: FakeLocationManager()
        )

        try await waitUntil {
            provider.fetchCount == 1
        }

        #expect(viewModel.weeklyForecast.isEmpty)
    }

    @Test("Hourly forecast maps real provider hours without synthesis")
    func hourlyForecastMapsProviderHours() async throws {
        let calendar = Calendar.current
        let hourStart = try #require(calendar.dateInterval(of: .hour, for: Date())?.start)
        let nextHour = try #require(calendar.date(byAdding: .hour, value: 1, to: hourStart))

        let provider = FakeWeatherProvider(weatherData: WeatherData(temperature: 72, feelsLike: 74, humidity: 55))
        provider.hourlyToReturn = [
            HourlyForecastDTO(date: hourStart, temperature: 71, precipitationChance: 10, weatherCondition: .clear),
            HourlyForecastDTO(date: nextHour, temperature: 73, precipitationChance: 35, weatherCondition: .partlyCloudy)
        ]

        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: FakeLocationManager()
        )

        try await waitUntil {
            viewModel.hourlyForecast.count == 2
        }

        #expect(viewModel.hourlyForecast.map(\.temperature) == [71, 73])
        #expect(viewModel.hourlyForecast.map(\.precipitationProbability) == [10, 35])
        #expect(viewModel.hourlyForecast.map(\.hour) == [hourStart, nextHour])
    }

    @Test("Hourly forecast stays empty when the provider has no hourly data")
    func hourlyForecastEmptyWithoutProviderHours() async throws {
        let provider = FakeWeatherProvider(weatherData: WeatherData(temperature: 72, feelsLike: 74, humidity: 55))
        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: FakeLocationManager()
        )

        try await waitUntil {
            provider.fetchCount == 1
        }
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.hourlyForecast.isEmpty)
    }

    @Test("Threshold notices are branded as SunHat advisories, not official warnings")
    func thresholdNoticesAreBrandedAdvisories() async throws {
        let hotWeather = WeatherData(temperature: 101, feelsLike: 104, humidity: 30)
        hotWeather.uvIndex = 10
        hotWeather.weatherCondition = .clear

        let provider = FakeWeatherProvider(weatherData: hotWeather)
        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: FakeLocationManager()
        )

        try await waitUntil {
            viewModel.weatherAlerts.count == 2
        }

        #expect(viewModel.weatherAlerts.allSatisfy { $0.title.hasPrefix("SunHat") })
        #expect(viewModel.weatherAlerts.allSatisfy { $0.severity == .advisory })
        #expect(!viewModel.weatherAlerts.contains { $0.title.contains("Warning") })
    }

    @Test("Historical comparisons stay nil without stored history — no placeholder values")
    func historicalComparisonsNilWithoutStoredHistory() async throws {
        let provider = FakeWeatherProvider(weatherData: WeatherData(temperature: 72, feelsLike: 74, humidity: 55))
        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: FakeLocationManager()
        )

        try await waitUntil {
            provider.fetchCount == 1
        }
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.yesterdayTemp == nil)
        #expect(viewModel.lastWeekTemp == nil)
        #expect(viewModel.historicalAvgTemp == nil)
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

    @Test("hasWeatherData becomes false when the weather fetch fails")
    func hasWeatherDataFalseAfterFetchFailure() async throws {
        let provider = FakeWeatherProvider(weatherData: WeatherData(temperature: 70, feelsLike: 70, humidity: 50))
        provider.errorToThrow = WeatherError.networkUnavailable
        let locationManager = FakeLocationManager()

        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: locationManager
        )

        try await waitUntil { provider.fetchCount == 1 }
        // Give the failed load a moment to finish updating published state.
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.hasWeatherData == false)
        #expect(viewModel.isLoading == false)
    }

    @Test("hasWeatherData becomes false when no location is available")
    func hasWeatherDataFalseWhenLocationUnavailable() async throws {
        let provider = FakeWeatherProvider(weatherData: WeatherData(temperature: 70, feelsLike: 70, humidity: 50))
        let locationManager = NilLocationManager()

        let viewModel = WeatherViewModel(
            modelContainer: try makeModelContainer(),
            weatherService: provider,
            locationManager: locationManager
        )

        // No location means the fetch is never attempted.
        try await Task.sleep(for: .milliseconds(50))

        #expect(provider.fetchCount == 0)
        #expect(viewModel.hasWeatherData == false)
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

    private func makeForecastDay(
        date: Date,
        highTemperature: Double,
        lowTemperature: Double,
        condition: WeatherCondition,
        description: String,
        precipitationProbability: Int
    ) -> ForecastDay {
        let forecast = ForecastDay(
            date: date,
            highTemperature: highTemperature,
            lowTemperature: lowTemperature,
            weatherCondition: condition
        )
        forecast.weatherDescription = description
        forecast.precipitationProbability = precipitationProbability
        return forecast
    }
}

@MainActor
private final class FakeWeatherProvider: WeatherProviding {
    @Published private var isLoading = false
    @Published private var lastUpdateTime: Date?

    private let weatherData: WeatherData
    var errorToThrow: (any Error)?
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
        if let errorToThrow {
            throw errorToThrow
        }
        lastUpdateTime = Date()
        return weatherData
    }

    var hourlyToReturn: [HourlyForecastDTO] = []

    func fetchHourlyForecast(for location: CLLocation) async -> [HourlyForecastDTO] {
        hourlyToReturn
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

private struct NilLocationManager: LocationManaging {
    func currentLocation() async -> (location: CLLocation, name: String)? {
        nil
    }
}
