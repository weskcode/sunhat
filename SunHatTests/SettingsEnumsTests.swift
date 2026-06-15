//
//  SettingsEnumsTests.swift
//  SunHatTests
//
//  Covers the settings-facing enums: notification timing intervals and
//  temperature unit presentation.
//

import Foundation
import Testing
@testable import SunHat

@MainActor
struct NotificationTimingTests {
    @Test("Immediate timing has a zero lead interval")
    func immediateIsZero() {
        #expect(NotificationTiming.immediate.timeInterval == 0)
    }

    @Test(
        "Each timing maps to the expected lead interval in seconds",
        arguments: [
            (NotificationTiming.fifteenMinutes, TimeInterval(900)),
            (.thirtyMinutes, TimeInterval(1_800)),
            (.oneHour, TimeInterval(3_600)),
            (.twoHours, TimeInterval(7_200)),
            (.fourHours, TimeInterval(14_400)),
            (.sixHours, TimeInterval(21_600)),
            (.twelveHours, TimeInterval(43_200)),
            (.oneDayBefore, TimeInterval(86_400))
        ]
    )
    func timingIntervals(timing: NotificationTiming, expected: TimeInterval) {
        #expect(timing.timeInterval == expected)
    }

    @Test("Lead intervals increase monotonically across the ordered cases")
    func intervalsAreMonotonic() {
        let intervals = NotificationTiming.allCases.map(\.timeInterval)
        #expect(intervals == intervals.sorted())
    }

    @Test("Every timing exposes a non-empty display name and icon")
    func everyTimingHasPresentation() {
        for timing in NotificationTiming.allCases {
            #expect(timing.displayName.isEmpty == false)
            #expect(timing.icon.isEmpty == false)
        }
    }
}

@MainActor
struct TemperatureUnitTests {
    @Test(
        "Each unit exposes the correct degree symbol",
        arguments: [
            (TemperatureUnit.fahrenheit, "°F"),
            (.celsius, "°C")
        ]
    )
    func unitSymbols(unit: TemperatureUnit, symbol: String) {
        #expect(unit.symbol == symbol)
    }

    @Test(
        "Each unit exposes the correct human-readable name",
        arguments: [
            (TemperatureUnit.fahrenheit, "Fahrenheit"),
            (.celsius, "Celsius")
        ]
    )
    func unitShortNames(unit: TemperatureUnit, name: String) {
        #expect(unit.shortName == name)
    }

    @Test("Temperature units round-trip through their raw values")
    func unitsRoundTripThroughRawValue() throws {
        for unit in TemperatureUnit.allCases {
            let restored = try #require(TemperatureUnit(rawValue: unit.rawValue))
            #expect(restored == unit)
        }
    }
}
