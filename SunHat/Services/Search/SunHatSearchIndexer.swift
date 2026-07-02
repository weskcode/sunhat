//
//  SunHatSearchIndexer.swift
//  SunHat
//
//  Created by Codex on 6/27/26.
//

import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

nonisolated enum SunHatSearchIndexer {
    static let reminderPrefix = "reminder"
    static let locationPrefix = "location"

    private static let domainIdentifier = "org.wesley.sunhat.search"

    @MainActor
    static func index(reminder: WeatherReminder) {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = reminder.displayTitle
        attributes.contentDescription = reminder.shortDescription
        attributes.keywords = [
            "SunHat",
            "weather reminder",
            reminder.category.displayName,
            reminder.statusText
        ] + reminder.tags
        attributes.identifier = reminder.id.uuidString
        attributes.relatedUniqueIdentifier = searchableIdentifier(prefix: reminderPrefix, id: reminder.id)

        let item = CSSearchableItem(
            uniqueIdentifier: searchableIdentifier(prefix: reminderPrefix, id: reminder.id),
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    @MainActor
    static func index(location: SavedLocation) {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = location.displayName
        attributes.contentDescription = location.shortAddress.isEmpty ? location.fullDisplayName : location.shortAddress
        attributes.keywords = [
            "SunHat",
            "weather location",
            location.source.displayName
        ]
        attributes.latitude = NSNumber(value: location.latitude)
        attributes.longitude = NSNumber(value: location.longitude)
        attributes.identifier = location.id.uuidString
        attributes.relatedUniqueIdentifier = searchableIdentifier(prefix: locationPrefix, id: location.id)

        let item = CSSearchableItem(
            uniqueIdentifier: searchableIdentifier(prefix: locationPrefix, id: location.id),
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func deleteReminder(id: UUID) {
        delete(prefix: reminderPrefix, id: id)
    }

    static func deleteLocation(id: UUID) {
        delete(prefix: locationPrefix, id: id)
    }

    static func deleteAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
    }

    static func destination(for uniqueIdentifier: String) -> SunHatSearchDestination? {
        if uniqueIdentifier.hasPrefix("\(reminderPrefix):") {
            return .reminders
        }

        if uniqueIdentifier.hasPrefix("\(locationPrefix):") {
            return .settings
        }

        return nil
    }

    private static func delete(prefix: String, id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [searchableIdentifier(prefix: prefix, id: id)]
        )
    }

    private static func searchableIdentifier(prefix: String, id: UUID) -> String {
        "\(prefix):\(id.uuidString)"
    }
}

nonisolated enum SunHatSearchDestination {
    case reminders
    case settings
}
