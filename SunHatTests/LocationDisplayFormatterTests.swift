//
//  LocationDisplayFormatterTests.swift
//  SunHatTests
//
//  Created by Codex on 6/3/26.
//

import Testing
@testable import SunHat

@MainActor
struct LocationDisplayFormatterTests {
    @Test("Neighborhood is preferred over city for current location display")
    func neighborhoodDisplayName() {
        let displayName = LocationDisplayFormatter.displayName(
            neighborhood: "Capitol Hill",
            city: "Seattle",
            administrativeArea: "WA"
        )

        #expect(displayName == "Capitol Hill")
    }

    @Test("City is used when no neighborhood is available")
    func cityDisplayName() {
        let displayName = LocationDisplayFormatter.displayName(
            neighborhood: nil,
            city: "Portland",
            administrativeArea: "OR"
        )

        #expect(displayName == "Portland")
    }

    @Test("Exact manual address is reduced to city")
    func exactManualAddressIsReduced() {
        let displayName = LocationDisplayFormatter.privacyPreservingName(
            from: "123 Main Street, Denver, CO"
        )

        #expect(displayName == "Denver")
    }

    @Test("Coordinate display is reduced to current location")
    func coordinateDisplayIsReduced() {
        let displayName = LocationDisplayFormatter.privacyPreservingName(
            from: "Current Location (37.77, -122.42)"
        )

        #expect(displayName == "Current Location")
    }
}
