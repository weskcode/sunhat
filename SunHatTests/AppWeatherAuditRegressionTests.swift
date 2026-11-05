import CoreLocation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct AppWeatherAuditRegressionTests {
    private func container() throws -> ModelContainer {
        let schema = SunHatModelSchema.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    @Test("Denied GPS permission never returns a cached fix")
    func deniedGPSDoesNotReturnStoredFix() async throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let manager = LocationPermissionManager(userDefaults: defaults)
        manager.currentLocation = CLLocation(latitude: 40.7, longitude: -74)
        manager.authorizationStatus = .denied
        let result = await LocationPermissionManagerAdapter(locationPermissionManager: manager).currentLocation()
        #expect(result == nil)
    }

    @Test("Disabled location services return without waiting for authorization")
    func disabledLocationServicesDoNotWaitForPermission() async throws {
        let manager = LocationPermissionManager(userDefaults: try #require(UserDefaults(suiteName: UUID().uuidString)))
        manager.authorizationStatus = .notDetermined
        manager.isLocationServicesEnabled = false
        #expect(await manager.resolveCurrentLocation() == nil)
    }

    @Test("Explicit device location does not substitute a preferred manual city")
    func explicitDeviceLocationIgnoresManualPreference() async throws {
        let manager = LocationPermissionManager(userDefaults: try #require(UserDefaults(suiteName: UUID().uuidString)))
        manager.authorizationStatus = .authorizedWhenInUse
        manager.manualLocation = ManualLocationData(name: "New York", coordinate: CLLocationCoordinate2D(latitude: 40.7, longitude: -74))
        manager.currentLocation = CLLocation(latitude: 41.8781, longitude: -87.6298)
        let location = await DefaultLocationManager(manager: manager).currentLocation()
        #expect(location?.location.coordinate.latitude == 41.8781)
    }

    @Test("GPS freshness rejects stale or invalid fixes")
    func rejectsStaleAndInvalidFixes() throws {
        let manager = LocationPermissionManager(userDefaults: try #require(UserDefaults(suiteName: UUID().uuidString)))
        manager.authorizationStatus = .authorizedWhenInUse
        let coordinate = CLLocationCoordinate2D(latitude: 40.7, longitude: -74)
        manager.currentLocation = CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: 100, verticalAccuracy: 100, timestamp: Date().addingTimeInterval(-3600))
        #expect(manager.freshCurrentLocation == nil)
        manager.currentLocation = CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: -1, verticalAccuracy: 100, timestamp: Date())
        #expect(manager.freshCurrentLocation == nil)
        manager.currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        #expect(manager.freshCurrentLocation != nil)
    }

    @Test("Weather refresh retains month history and removes samples older than 35 days")
    func retainsWeatherHistory() async throws {
        let store = try container()
        let context = store.mainContext
        let month = WeatherData(temperature: 65, feelsLike: 65, humidity: 50)
        month.timestamp = Date().addingTimeInterval(-30 * 86400)
        let expired = WeatherData(temperature: 60, feelsLike: 60, humidity: 50)
        expired.timestamp = Date().addingTimeInterval(-36 * 86400)
        let monthID = month.id
        let expiredID = expired.id
        context.insert(month)
        context.insert(expired)
        try context.save()
        let service = WeatherServiceActor(modelContext: context, providers: [MockWeatherAPI()])
        _ = try await service.fetchWeatherData(for: CLLocation(latitude: 40.7, longitude: -74), forceRefresh: true)
        let samples = try context.fetch(FetchDescriptor<WeatherData>())
        #expect(samples.contains { $0.id == monthID })
        #expect(!samples.contains { $0.id == expiredID })
    }

    @Test("Saved weather samples use approximate coordinates without changing reminders")
    func weatherHistoryUsesApproximateCoordinates() async throws {
        let store = try container()
        let location = CLLocation(latitude: 40.714321, longitude: -74.006789)
        let reminder = WeatherReminder(title: "Precise reminder")
        reminder.location = LocationData(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        store.mainContext.insert(reminder)
        try store.mainContext.save()
        let service = WeatherServiceActor(modelContext: store.mainContext, providers: [MockWeatherAPI()])
        let result = try await service.fetchWeatherData(for: location, forceRefresh: true)
        let saved = try #require(store.mainContext.fetch(FetchDescriptor<WeatherData>()).first)
        #expect(saved.locationLatitude == 40.71)
        #expect(saved.locationLongitude == -74.01)
        #expect(saved.location == nil)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<LocationData>()) == 1)
        #expect(reminder.location?.latitude == location.coordinate.latitude)
        #expect(reminder.location?.longitude == location.coordinate.longitude)
        #expect(result.temperature == 72)
    }

    @Test("Forced refreshes return fresh weather while history samples are limited to 15-minute intervals")
    func frequentRefreshesBoundHistorySamples() async throws {
        let store = try container()
        let provider = MockWeatherAPI()
        let service = WeatherServiceActor(modelContext: store.mainContext, providers: [provider])
        let location = CLLocation(latitude: 40.714321, longitude: -74.006789)
        let first = try await service.fetchWeatherData(for: location, forceRefresh: true)
        await provider.setMockWeatherData(WeatherDataDTO(
            temperature: 85, feelsLike: 87, humidity: 60, dewPoint: 55,
            pressure: 30, visibility: 10, uvIndex: 5, cloudCover: 30,
            windSpeed: 10, windDirection: 180, precipitationAmount: 0,
            precipitationType: .none, weatherCondition: .clear,
            dataSource: .openWeatherMap, accuracy: .medium, forecast: []
        ))
        let refreshed = try await service.fetchWeatherData(for: location, forceRefresh: true)
        #expect(refreshed.temperature == 85)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WeatherData>()) == 1)
        let cached = try #require(await service.getCachedWeatherData(for: location))
        #expect(cached.temperature == 85)
        #expect(cached.id == refreshed.id)
        let nearby = try #require(await service.getCachedWeatherData(for: CLLocation(latitude: 40.711, longitude: -74.004)))
        #expect(nearby.temperature == 85)
        first.timestamp = Date().addingTimeInterval(-16 * 60)
        try store.mainContext.save()
        _ = try await service.fetchWeatherData(for: location, forceRefresh: true)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WeatherData>()) == 2)
        _ = try await service.fetchWeatherData(for: CLLocation(latitude: 41.8781, longitude: -87.6298), forceRefresh: true)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WeatherData>()) == 3)
    }

    @Test("Offline fallback keeps the newest unsampled response for up to 24 hours")
    func offlineFallbackKeepsNewestResponse() async throws {
        let store = try container()
        let provider = MockWeatherAPI()
        var now = Date()
        let service = WeatherServiceActor(modelContext: store.mainContext, providers: [provider], now: { now })
        let location = CLLocation(latitude: 40.714321, longitude: -74.006789)
        _ = try await service.fetchWeatherData(for: location, forceRefresh: true)
        now = now.addingTimeInterval(14 * 60)
        await provider.setMockWeatherData(WeatherDataDTO(
            temperature: 85, feelsLike: 87, humidity: 60, dewPoint: 55,
            pressure: 30, visibility: 10, uvIndex: 5, cloudCover: 30,
            windSpeed: 10, windDirection: 180, precipitationAmount: 0,
            precipitationType: .none, weatherCondition: .clear,
            dataSource: .openWeatherMap, accuracy: .medium, forecast: []
        ))
        _ = try await service.fetchWeatherData(for: location, forceRefresh: true)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WeatherData>()) == 1)
        now = now.addingTimeInterval(16 * 60)
        _ = try await service.fetchWeatherData(for: CLLocation(latitude: 41.8781, longitude: -87.6298), forceRefresh: true)
        await provider.setShouldFail(true)
        let fallback = try await service.fetchWeatherData(for: location, forceRefresh: true)
        #expect(fallback.temperature == 85)
        #expect(await service.getCachedWeatherData(for: location) == nil)
        now = now.addingTimeInterval(25 * 60 * 60)
        #expect(await service.getCachedWeatherData(for: location, allowExpired: true) == nil)
    }

    @Test("Current-weather cache matches the one-kilometre history and card radius")
    func currentCacheUsesNearbyWeatherOnly() async throws {
        let store = try container()
        let service = WeatherServiceActor(modelContext: store.mainContext, providers: [MockWeatherAPI()])
        let location = CLLocation(latitude: 40.714321, longitude: -74.006789)
        _ = try await service.fetchWeatherData(for: location, forceRefresh: true)
        #expect(await service.getCachedWeatherData(for: location) != nil)
        #expect(await service.getCachedWeatherData(for: CLLocation(latitude: 40.75, longitude: -74.01)) == nil)
    }

    @Test("Clearing weather data prevents an in-flight response from restoring it")
    func clearingCacheInvalidatesPendingFetch() async throws {
        let store = try container()
        let provider = AuditSuspendedWeatherAPI(base: MockWeatherAPI())
        let service = WeatherServiceActor(modelContext: store.mainContext, providers: [provider])
        let location = CLLocation(latitude: 40.7, longitude: -74)
        let request = Task { _ = try await service.fetchWeatherData(for: location, forceRefresh: true) }
        defer {
            request.cancel()
            Task { await provider.finish() }
        }
        for _ in 0..<100 {
            if await provider.started { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(await provider.started)
        await service.clearCache()
        await provider.finish()
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WeatherData>()) == 0)
        #expect(await service.getCachedWeatherData(for: location) == nil)
    }

    @Test("Expired weather samples remove their forecast children")
    func expiredHistoryRemovesForecastChildren() async throws {
        let store = try container()
        let expired = WeatherData(temperature: 60, feelsLike: 60, humidity: 50)
        expired.timestamp = Date().addingTimeInterval(-36 * 86400)
        expired.forecastDays = [ForecastDay(date: expired.timestamp, highTemperature: 65, lowTemperature: 50)]
        store.mainContext.insert(expired)
        try store.mainContext.save()
        let service = WeatherServiceActor(modelContext: store.mainContext, providers: [MockWeatherAPI()])
        _ = try await service.fetchWeatherData(for: CLLocation(latitude: 40.7, longitude: -74), forceRefresh: true)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<ForecastDay>()) == 0)
    }

    @Test("History and forecasts find rounded samples without mixing distant locations")
    func roundedWeatherRemainsFindable() async throws {
        let store = try container()
        let location = CLLocation(latitude: 40.714321, longitude: -74.006789)
        let sample = WeatherData(temperature: 72, feelsLike: 74, humidity: 60)
        sample.locationLatitude = 40.71
        sample.locationLongitude = -74.01
        sample.forecastDays = [ForecastDay(date: Date(), highTemperature: 75, lowTemperature: 60)]
        store.mainContext.insert(sample)
        try store.mainContext.save()
        let actor = WeatherModelActor(modelContainer: store)
        #expect(try await actor.fetchHistoricalWeatherData(for: location).count == 1)
        #expect(try await actor.fetchForecastData(for: location).count == 1)
        let distant = CLLocation(latitude: 41.8781, longitude: -87.6298)
        #expect(try await actor.fetchHistoricalWeatherData(for: distant).isEmpty)
        #expect(try await actor.fetchForecastData(for: distant).isEmpty)
    }

    @Test("Editing threshold bypasses an earlier cached match")
    func editingThresholdChangesEvaluation() async throws {
        let store = try container()
        let reminder = WeatherReminder(title: "Threshold test")
        let condition = TriggerCondition(triggerType: .exactTemperature, targetTemperature: 60, comparisonType: .above)
        reminder.triggerCondition = condition
        reminder.location = LocationData(latitude: 40.7, longitude: -74)
        store.mainContext.insert(reminder)
        try store.mainContext.save()
        let engine = await TriggerEngine.shared(modelContainer: store, weatherAPI: MockWeatherAPI())
        let before = try #require(await engine.evaluateReminder(reminderId: reminder.id))
        #expect(before.triggered)
        condition.targetTemperature = 100
        try store.mainContext.save()
        let after = try #require(await engine.evaluateReminder(reminderId: reminder.id))
        #expect(!after.triggered)
    }

    @Test("Zero-width ranges produce finite confidence")
    func pointRangeHasFiniteConfidence() async throws {
        let store = try container()
        let reminder = WeatherReminder(title: "Point range")
        let condition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        condition.minTemperature = 72
        condition.maxTemperature = 72
        reminder.triggerCondition = condition
        reminder.location = LocationData(latitude: 40.7, longitude: -74)
        store.mainContext.insert(reminder)
        try store.mainContext.save()
        let engine = await TriggerEngine.shared(modelContainer: store, weatherAPI: MockWeatherAPI())
        let result = try #require(await engine.evaluateReminder(reminderId: reminder.id))
        #expect(result.triggered)
        #expect(result.confidence.isFinite)
    }

    @Test("Range editing requires real ordered bounds")
    func rangeEditorValidatesBounds() {
        let condition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        var editable = EditableTriggerCondition(from: condition)
        #expect(!editable.isValid)
        editable.minTemperature = 85
        editable.maxTemperature = 150
        #expect(editable.isValid)
        editable.maxTemperature = 80
        #expect(!editable.isValid)
    }

    @Test("Live predictions respect comparison and sky filters")
    func predictionRespectsComparisonAndSky() {
        let condition = TriggerCondition(triggerType: .exactTemperature, targetTemperature: 80, comparisonType: .above)
        let weather = WeatherData(temperature: 90, feelsLike: 92, humidity: 50)
        weather.weatherCondition = .rain
        #expect(weather.evaluateCondition(condition))
        condition.selectedSkyConditions = [.sunny]
        #expect(!weather.evaluateCondition(condition))
        condition.conditionMode = .exclude
        #expect(weather.evaluateCondition(condition))
    }

    @Test("Failed edits restore only their own models and preserve unrelated pending work")
    func failedSaveRestoresOwnEdits() async throws {
        struct SaveFailure: Error {}
        let store = try container()
        let context = store.mainContext
        let reminder = WeatherReminder(title: "Original")
        reminder.triggerCondition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        reminder.triggerCondition?.minTemperature = 85
        reminder.triggerCondition?.maxTemperature = 100
        let location = LocationData(latitude: 40.7, longitude: -74)
        reminder.location = location
        context.insert(reminder)
        try context.save()
        let unrelated = WeatherReminder(title: "Unrelated pending task")
        context.insert(unrelated)
        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: context)
        defer { viewModel.stopWeatherRefresh(); viewModel.stopLivePrediction() }
        var edit = EditableReminder(from: reminder)
        edit.title = "Failed edit"
        edit.triggerCondition.maxTemperature = 150
        edit.location.coordinate = CLLocationCoordinate2D(latitude: 34.05, longitude: -118.24)
        edit.location.hasChanged = true
        let saved = await viewModel.saveChanges(edit, persist: { _ in throw SaveFailure() })
        #expect(!saved)
        #expect(reminder.title == "Original")
        #expect(reminder.triggerCondition?.maxTemperature == 100)
        #expect(reminder.location === location)
        #expect(reminder.notificationConfig == nil)
        #expect(reminder.history.isEmpty)
        #expect(unrelated.modelContext != nil)
        try context.save()
        let reminders = try context.fetch(FetchDescriptor<WeatherReminder>())
        #expect(reminders.contains { $0.title == "Unrelated pending task" })
        #expect(!reminders.contains { $0.title == "Failed edit" })
    }

    @Test("Range edits save actual minimum and maximum above 100 degrees")
    func rangeEditsSaveRealBounds() async throws {
        let store = try container()
        let reminder = WeatherReminder(title: "Hot day")
        reminder.triggerCondition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        reminder.triggerCondition?.minTemperature = 85
        reminder.triggerCondition?.maxTemperature = 100
        reminder.location = LocationData(latitude: 40.7, longitude: -74)
        store.mainContext.insert(reminder)
        try store.mainContext.save()
        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: store.mainContext)
        defer { viewModel.stopWeatherRefresh(); viewModel.stopLivePrediction() }
        var edit = EditableReminder(from: reminder)
        edit.triggerCondition.minTemperature = 90
        edit.triggerCondition.maxTemperature = 150
        #expect(await viewModel.saveChanges(edit))
        #expect(reminder.triggerCondition?.minTemperature == 90)
        #expect(reminder.triggerCondition?.maxTemperature == 150)
    }

    @Test("Creation waits for a fresh resolved location before saving")
    func creationWaitsForLocation() async throws {
        let store = try container()
        let resolver = AuditSuspendedLocationResolver()
        let viewModel = FirstReminderCreationViewModel(locationResolver: resolver)
        viewModel.configure(modelContext: store.mainContext)
        viewModel.customReminder.title = "Fresh location"
        let creation = Task { await viewModel.createReminder() }
        defer { resolver.finish() }
        for _ in 0..<100 {
            if resolver.started { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(resolver.started)
        #expect(viewModel.isCreatingReminder)
        #expect(try store.mainContext.fetch(FetchDescriptor<WeatherReminder>()).isEmpty)
        resolver.finish()
        #expect(await creation.value)
        let saved = try #require(store.mainContext.fetch(FetchDescriptor<WeatherReminder>()).first)
        #expect(saved.location?.latitude == 40.7)
        #expect(!viewModel.isCreatingReminder)
    }

    @Test("Cancelling creation while locating saves nothing")
    func cancelledCreationSavesNothing() async throws {
        let store = try container()
        let resolver = AuditCancellableLocationResolver()
        let viewModel = FirstReminderCreationViewModel(locationResolver: resolver)
        viewModel.configure(modelContext: store.mainContext)
        viewModel.customReminder.title = "Cancelled task"
        let creation = Task { await viewModel.createReminder() }
        for _ in 0..<100 {
            if resolver.started { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        creation.cancel()
        #expect(!(await creation.value))
        #expect(try store.mainContext.fetch(FetchDescriptor<WeatherReminder>()).isEmpty)
        #expect(!viewModel.isCreatingReminder)
        #expect(viewModel.creationErrorMessage == nil)
    }

    @Test("Slider stops are whole degrees inside the supported physical range", arguments: [TemperatureUnit.fahrenheit, .celsius])
    func sliderStopsMatchLabels(unit: TemperatureUnit) {
        let range = TemperatureSliderBounds.range(for: unit)
        #expect(range.lowerBound.rounded() == range.lowerBound)
        #expect(range.upperBound.rounded() == range.upperBound)
        #expect(unit.toFahrenheit(range.lowerBound) >= -50)
        #expect(unit.toFahrenheit(range.upperBound) <= 150)
    }

    @Test("Unknown NSError domains are not mistaken for location denial")
    func unknownErrorDomainStaysUnknown() {
        let error = NSError(domain: "ExampleWeatherError", code: 1)
        guard case .unknown(let underlying) = AppleWeatherKitAPI().mapWeatherKitError(error) else {
            Issue.record("An unrelated error code must preserve the underlying error")
            return
        }
        #expect((underlying as NSError).domain == "ExampleWeatherError")
    }

    @Test("URL connectivity errors are classified using their domain")
    func urlConnectivityErrorIsNetworkUnavailable() {
        let error = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
        guard case .networkUnavailable = AppleWeatherKitAPI().mapWeatherKitError(error) else {
            Issue.record("URL connectivity errors should offer network recovery")
            return
        }
    }

    @Test("Retained historical weather is not returned as an expired current cache")
    func historicalSampleIsNotCurrentWeather() async throws {
        let store = try container()
        let historical = WeatherData(temperature: 60, feelsLike: 60, humidity: 50)
        historical.timestamp = Date().addingTimeInterval(-30 * 86400)
        historical.locationLatitude = 40.7
        historical.locationLongitude = -74
        store.mainContext.insert(historical)
        try store.mainContext.save()
        let service = WeatherServiceActor(modelContext: store.mainContext)
        let cached = await service.getCachedWeatherData(for: CLLocation(latitude: 40.7, longitude: -74), allowExpired: true)
        #expect(cached == nil)
    }

    @Test("Failed edits preserve nil conditions and custom delivery hours")
    func failedEditPreservesCustomHours() async throws {
        struct SaveFailure: Error {}
        let store = try container()
        let reminder = WeatherReminder(title: "Original")
        let config = NotificationConfig(title: "", message: "")
        config.avoidNighttime = true
        config.preferredStartHour = 7
        config.preferredEndHour = 21
        reminder.notificationConfig = config
        store.mainContext.insert(reminder)
        try store.mainContext.save()
        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: store.mainContext)
        defer { viewModel.stopWeatherRefresh(); viewModel.stopLivePrediction() }
        var edit = EditableReminder(from: reminder)
        edit.title = "Failed edit"
        edit.notificationConfig.preferredTimeRange = .morning
        #expect(!(await viewModel.saveChanges(edit, persist: { _ in throw SaveFailure() })))
        #expect(reminder.triggerCondition == nil)
        #expect(reminder.notificationConfig === config)
        #expect(config.avoidNighttime)
        #expect(config.preferredStartHour == 7)
        #expect(config.preferredEndHour == 21)
    }

    @Test("Daily predictions ignore past days and describe today's match by day")
    func dailyPredictionDoesNotSayHoursAgo() async throws {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let reminder = WeatherReminder(title: "Daily prediction")
        let condition = TriggerCondition(triggerType: .temperatureRange, comparisonType: .between)
        condition.minTemperature = 65
        condition.maxTemperature = 75
        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.stopWeatherRefresh()
        defer { viewModel.stopLivePrediction() }
        let prediction = await viewModel.calculateNextTrigger(condition: condition, forecast: [ForecastDay(date: yesterday, highTemperature: 70, lowTemperature: 50), ForecastDay(date: today, highTemperature: 70, lowTemperature: 50)], now: now)
        #expect(prediction.totalDays == 1)
        #expect(prediction.matchingDays == 1)
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        #expect(prediction.description.contains(formatter.localizedString(from: DateComponents(day: 0))))
    }

    @Test("Provider optional sun times and gust survive conversion")
    func sunAndGustSurviveDTOConversion() async throws {
        var dto = try await MockWeatherAPI().fetchWeatherData(for: CLLocation(latitude: 40.7, longitude: -74))
        dto.sunrise = Date()
        dto.sunset = Date().addingTimeInterval(36000)
        dto.windGust = 25
        let data = dto.toWeatherData()
        #expect(data.sunrise == dto.sunrise)
        #expect(data.sunset == dto.sunset)
        #expect(data.windGust == 25)
    }
}

private actor AuditSuspendedWeatherAPI: WeatherAPI {
    nonisolated let provider: WeatherProvider = .openWeatherMap
    nonisolated var isAvailable: Bool { get async { true } }
    private let base: MockWeatherAPI
    private(set) var started = false
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(base: MockWeatherAPI) {
        self.base = base
    }

    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherDataDTO {
        try await base.fetchCurrentWeather(for: location)
    }

    func fetchForecast(for location: CLLocation, days: Int) async throws -> [ForecastDayDTO] {
        try await base.fetchForecast(for: location, days: days)
    }

    func fetchWeatherData(for location: CLLocation) async throws -> WeatherDataDTO {
        started = true
        if !released {
            await withCheckedContinuation { continuation = $0 }
        }
        return try await base.fetchWeatherData(for: location)
    }

    func finish() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class AuditSuspendedLocationResolver: LocationManaging {
    private(set) var started = false
    private var continuation: CheckedContinuation<(location: CLLocation, name: String)?, Never>?

    func currentLocation() async -> (location: CLLocation, name: String)? {
        started = true
        return await withCheckedContinuation { continuation = $0 }
    }

    func finish() {
        continuation?.resume(returning: (CLLocation(latitude: 40.7, longitude: -74), "Test city"))
        continuation = nil
    }
}

@MainActor
private final class AuditCancellableLocationResolver: LocationManaging {
    private(set) var started = false

    func currentLocation() async -> (location: CLLocation, name: String)? {
        started = true
        do { try await Task.sleep(for: .seconds(30)) }
        catch { return nil }
        return nil
    }
}
