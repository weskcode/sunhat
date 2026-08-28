//
//  LocationDisplayFormatter.swift
//  SunHat
//
//  Created by Codex on 6/3/26.
//

import CoreLocation
import Foundation
import MapKit

enum LocationDisplayFormatter {
    private static var currentLocationLabel: String {
        String(localized: "Current Location", comment: "Displayed in place of an exact location when using GPS")
    }

    static func reverseGeocodedName(for location: CLLocation) async -> String {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return currentLocationLabel
        }

        do {
            let mapItems = try await request.mapItems
            return mapItems.compactMap(displayName(from:)).first ?? currentLocationLabel
        } catch {
            return currentLocationLabel
        }
    }

    static func displayName(from mapItem: MKMapItem) -> String? {
        if let cityName = cleaned(mapItem.addressRepresentations?.cityName) {
            return cityName
        }

        if let contextualCity = cleaned(mapItem.addressRepresentations?.cityWithContext) {
            return privacyPreservingName(from: contextualCity)
        }

        if let shortAddress = cleaned(mapItem.address?.shortAddress) {
            return privacyPreservingName(from: shortAddress)
        }

        return nil
    }

    static func displayName(
        neighborhood: String?,
        city: String?,
        administrativeArea: String?
    ) -> String {
        let cleanNeighborhood = cleaned(neighborhood)
        let cleanCity = cleaned(city)

        if let cleanNeighborhood,
           cleanNeighborhood.localizedCaseInsensitiveCompare(cleanCity ?? "") != .orderedSame {
            return cleanNeighborhood
        }

        if let cleanCity {
            return cleanCity
        }

        return cleaned(administrativeArea) ?? currentLocationLabel
    }

    static func privacyPreservingName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return currentLocationLabel
        }

        if trimmed.localizedCaseInsensitiveContains("current location") {
            return currentLocationLabel
        }

        let components = trimmed
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !components.isEmpty else {
            return currentLocationLabel
        }

        if components.count == 1 {
            return looksLikeExactAddress(components[0]) ? currentLocationLabel : components[0]
        }

        if looksLikeExactAddress(components[0]) {
            return components.dropFirst().first ?? currentLocationLabel
        }

        return components[0]
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func looksLikeExactAddress(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        let streetMarkers = [
            " street", " st", " avenue", " ave", " boulevard", " blvd",
            " road", " rd", " drive", " dr", " lane", " ln",
            " court", " ct", " circle", " cir", " place", " pl",
            " way", " terrace", " ter"
        ]

        if value.rangeOfCharacter(from: .decimalDigits) != nil {
            return true
        }

        return streetMarkers.contains { marker in
            lowercased.hasSuffix(marker) || lowercased.contains("\(marker) ")
        }
    }
}
