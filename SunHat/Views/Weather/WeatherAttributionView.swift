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
import OSLog

struct WeatherAttributionView: View {
    private static let logger = Logger(subsystem: "org.wesley.sunhat", category: "WeatherAttributionView")

    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherKit.WeatherAttribution?

    var body: some View {
        // The task is attached to this ZStack, not to the conditional Link
        // below, because a container whose only content is an `if` with no
        // `else` has no children while the condition is false — SwiftUI never
        // mounts it, so a `.task` there never runs. Color.clear keeps the
        // container real (and the 20pt height reserved) while the attribution
        // is still loading or unavailable.
        ZStack {
            if let attribution {
                Link(destination: attribution.legalPageURL) {
                    AsyncImage(url: markURL(for: attribution)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                }
                .accessibilityLabel(Text("Weather data attribution", comment: "Accessibility label for the Apple Weather attribution link"))
            } else {
                Color.clear
            }
        }
        .frame(height: 20)
        .task {
            do {
                attribution = try await WeatherKit.WeatherService.shared.attribution
            } catch {
                Self.logger.error("Failed to load WeatherKit attribution: \(error.localizedDescription)")
            }
        }
    }

    private func markURL(for attribution: WeatherKit.WeatherAttribution) -> URL {
        colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
    }
}
