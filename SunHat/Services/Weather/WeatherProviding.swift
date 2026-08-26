//
//  WeatherProviding.swift
//  SunHat
//
//  Created by Codex on 6/2/26.
//

import Combine
import CoreLocation
import Foundation

@MainActor
protocol WeatherProviding: AnyObject {
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var lastUpdateTimePublisher: AnyPublisher<Date?, Never> { get }

    func fetchCurrentWeather(for location: CLLocation, forceRefresh: Bool) async throws -> WeatherData

    /// Real provider hourly forecast, or `[]` when unavailable. Implementations
    /// must never synthesize hours, the UI shows an unavailable state instead.
    func fetchHourlyForecast(for location: CLLocation) async -> [HourlyForecastDTO]
}

extension WeatherProviding {
    func fetchHourlyForecast(for location: CLLocation) async -> [HourlyForecastDTO] { [] }
}

extension WeatherService: WeatherProviding {
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    var lastUpdateTimePublisher: AnyPublisher<Date?, Never> {
        $lastUpdateTime.eraseToAnyPublisher()
    }
}
