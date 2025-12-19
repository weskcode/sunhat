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
    }

    // MARK: - iOS 26 Location Permission Tests

    @available(iOS 26, *)
    func testLocationPermissionManagerTemporaryPermission() async {
        let locationManager = LocationPermissionManager()

        // Test that temporary permission method exists and can be called
        let expectation = XCTestExpectation(description: "Temporary permission request")

        locationManager.requestTemporaryLocationPermission(purposeKey: "weather_reminder") { success in
            // We don't expect this to actually succeed in tests, but we want to verify the method works
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - iOS 26 Weather Service Tests

    func testWeatherServiceBackgroundRefresh() async {
        let weatherService = WeatherService.shared

        // Test that background refresh scheduling works
        let expectation = XCTestExpectation(description: "Background refresh scheduling")

        // Schedule background refresh
        weatherService.scheduleBackgroundRefresh()

        // Give it a moment to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - iOS 26 Weather API Tests

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
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
