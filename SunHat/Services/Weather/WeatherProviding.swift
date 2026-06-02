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
}

extension WeatherService: WeatherProviding {
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    var lastUpdateTimePublisher: AnyPublisher<Date?, Never> {
        $lastUpdateTime.eraseToAnyPublisher()
    }
}
