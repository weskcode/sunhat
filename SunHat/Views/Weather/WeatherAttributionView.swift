//
//  WeatherAttributionView.swift
//  SunHat
//
//  App Review Guideline 5.2.5: any screen displaying WeatherKit data must
//  show Apple's "Weather" mark and a link to the current data-source
//  attribution page. Fetched fresh (not hardcoded) since Apple can update
//  the mark asset and legal page without an app update.
//

import SwiftUI
import WeatherKit

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherKit.WeatherAttribution?

    var body: some View {
        Group {
            if let attribution {
                Link(destination: attribution.legalPageURL) {
                    AsyncImage(url: markURL(for: attribution)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                    .frame(height: 20)
                }
                .accessibilityLabel(Text("Weather data attribution", comment: "Accessibility label for the Apple Weather attribution link"))
            }
        }
        .task {
            attribution = try? await WeatherKit.WeatherService.shared.attribution
        }
    }

    private func markURL(for attribution: WeatherKit.WeatherAttribution) -> URL {
        colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
    }
}
