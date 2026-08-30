//
//  LocationSearchComponents.swift
//  SunHat
//
//  Supporting views and sample data for ManualLocationEntryView's search
//  results and popular-city suggestions.
//

import SwiftUI
import CoreLocation

// MARK: - Supporting Views

struct LocationResultCard: View {
    let result: LocationSearchResult
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Location icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: "location.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                .accessibilityHidden(true)

                // Location details
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.city)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = result.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.displayName)")
        .accessibilityHint("Select this city for weather data")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PopularCityCard: View {
    let city: PopularCity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(city.flag)
                    .font(.title)
                    .accessibilityHidden(true)

                Text(city.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(city.country)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(city.name), \(city.country)")
        .accessibilityHint("Search for this city")
    }
}

// MARK: - Supporting Data Structures

struct LocationSearchResult: Identifiable {
    let id = UUID()
    let city: String
    let state: String?
    let country: String?
    let coordinate: CLLocationCoordinate2D

    var displayName: String {
        var components = [city]
        if let state = state {
            components.append(state)
        }
        if let country = country {
            components.append(country)
        }
        return components.joined(separator: ", ")
    }

    var subtitle: String? {
        var components: [String] = []
        if let state = state {
            components.append(state)
        }
        if let country = country {
            components.append(country)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

struct PopularCity: Identifiable {
    let id = UUID()
    let name: String
    let country: String
    let flag: String
    let coordinate: CLLocationCoordinate2D

    var displayName: String {
        "\(name), \(country)"
    }
}

// MARK: - Sample Data

let popularCities: [PopularCity] = [
    PopularCity(name: "New York", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
    PopularCity(name: "Los Angeles", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
    PopularCity(name: "Chicago", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)),
    PopularCity(name: "Houston", country: "USA", flag: "🇺🇸", coordinate: CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698)),
    PopularCity(name: "London", country: "UK", flag: "🇬🇧", coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
    PopularCity(name: "Paris", country: "France", flag: "🇫🇷", coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
    PopularCity(name: "Tokyo", country: "Japan", flag: "🇯🇵", coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
    PopularCity(name: "Sydney", country: "Australia", flag: "🇦🇺", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093))
]
