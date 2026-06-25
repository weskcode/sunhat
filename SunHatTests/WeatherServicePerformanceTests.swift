//
//  WeatherServicePerformanceTests.swift
//  SunHatTests
//

import XCTest
@testable import SunHat

@MainActor
final class WeatherServicePerformanceTests: XCTestCase {

    func testPerformanceWeatherDataCreation() {
        measure {
            for _ in 0..<1000 {
                let _ = WeatherData(
                    temperature: Double.random(in: -20...120),
                    feelsLike: Double.random(in: -20...120),
                    humidity: Int.random(in: 0...100)
                )
            }
        }
    }
}
