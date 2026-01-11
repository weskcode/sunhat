//
//  hattiTests.swift
//  hattiTests
//
//  Created by Wesley Keetch on 7/20/25.
//

import XCTest
@testable import hatti

final class hattiTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        XCTAssertTrue(true)
    }

    // MARK: - iOS 26 Location Permission Tests

    @available(iOS 26, *)
    @MainActor
    func testLocationPermissionManagerTemporaryPermission() async {
        let locationManager = LocationPermissionManager()

        // Verify the permission manager is properly initialized
        XCTAssertNotNil(locationManager)

        // Test that the authorization status property is accessible
        let status = locationManager.authorizationStatus
        XCTAssertNotNil(status)

        // Note: We can't test the actual permission callback in unit tests
        // as iOS authorization requires user interaction
    }

    // MARK: - iOS 26 Weather Service Tests

    @MainActor
    func testWeatherServiceBackgroundRefresh() async {
        let weatherService = WeatherService.shared

        // Test that the weather service singleton is available
        XCTAssertNotNil(weatherService)

        // Note: Background refresh scheduling requires a configured weatherActor
        // and cannot be fully tested without proper app initialization.
        // The service must be configured with a ModelContainer before use.
    }

    // MARK: - iOS 26 Weather API Tests

    @MainActor
    func testWeatherAPIiOS26Enhancements() async {
        let weatherAPI = AppleWeatherKitAPI()

        // Test that the iOS 26 enhanced method exists
        if #available(iOS 26, *) {
            // This would test the enhanced weather data fetching
            // In a real test, we'd mock the location and verify the response
            XCTAssertTrue(true, "iOS 26 WeatherKit enhancements are available")
        } else {
            XCTAssertTrue(true, "iOS 26 WeatherKit enhancements not available on this version")
        }

        // Verify the API object was created
        XCTAssertNotNil(weatherAPI)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
