//
//  SunHatAtmospherePalette.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/3/26.
//

import SwiftUI

struct SunHatAtmospherePalette {
    let lightBase: Color
    let darkBase: Color
    let lightSky: [Color]
    let darkSky: [Color]
    let lightLine: Color
    let darkLine: Color
    let lightHorizon: Color
    let darkHorizon: Color
    let lightConditionAccent: Color
    let darkConditionAccent: Color

    func baseColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBase : lightBase
    }

    func skyColors(for colorScheme: ColorScheme) -> [Color] {
        colorScheme == .dark ? darkSky : lightSky
    }

    func lineColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkLine : lightLine
    }

    func horizonColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkHorizon : lightHorizon
    }

    func conditionAccent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkConditionAccent : lightConditionAccent
    }

    static let sunHatDefault = SunHatAtmospherePalette(
        lightBase: Color(red: 0.93, green: 0.97, blue: 0.98),
        darkBase: Color(red: 0.03, green: 0.05, blue: 0.07),
        lightSky: [
            Color(red: 0.88, green: 0.96, blue: 0.99),
            Color(red: 0.78, green: 0.92, blue: 0.93),
            Color(red: 0.94, green: 0.89, blue: 0.75),
            Color(red: 0.99, green: 0.96, blue: 0.90)
        ],
        darkSky: [
            Color(red: 0.02, green: 0.04, blue: 0.07),
            Color(red: 0.05, green: 0.11, blue: 0.14),
            Color(red: 0.08, green: 0.17, blue: 0.17),
            Color(red: 0.18, green: 0.13, blue: 0.09)
        ],
        lightLine: Color(red: 0.10, green: 0.25, blue: 0.28).opacity(0.13),
        darkLine: .white.opacity(0.075),
        lightHorizon: Color(red: 0.99, green: 0.63, blue: 0.27),
        darkHorizon: Color(red: 0.95, green: 0.50, blue: 0.22),
        lightConditionAccent: .cyan,
        darkConditionAccent: .cyan
    )

    static func weather(_ palette: WeatherBackdropPalette) -> SunHatAtmospherePalette {
        switch palette {
        case .calmBlue:
            return bluePalette(
                lightSky: [
                    Color(red: 0.86, green: 0.91, blue: 0.94),
                    Color(red: 0.70, green: 0.82, blue: 0.90),
                    Color(red: 0.36, green: 0.55, blue: 0.73),
                    Color(red: 0.12, green: 0.25, blue: 0.42)
                ],
                darkSky: [
                    Color(red: 0.04, green: 0.06, blue: 0.09),
                    Color(red: 0.06, green: 0.10, blue: 0.16),
                    Color(red: 0.07, green: 0.16, blue: 0.27),
                    Color(red: 0.08, green: 0.23, blue: 0.38)
                ],
                lightHorizon: Color(red: 0.36, green: 0.58, blue: 0.78),
                darkHorizon: Color(red: 0.16, green: 0.36, blue: 0.58),
                lightAccent: Color(red: 0.18, green: 0.48, blue: 0.82)
            )
        case .brightBlue:
            return bluePalette(
                lightSky: [
                    Color(red: 0.88, green: 0.96, blue: 1.00),
                    Color(red: 0.68, green: 0.87, blue: 0.98),
                    Color(red: 0.34, green: 0.66, blue: 0.92),
                    Color(red: 0.12, green: 0.35, blue: 0.65)
                ],
                darkSky: [
                    Color(red: 0.03, green: 0.07, blue: 0.12),
                    Color(red: 0.05, green: 0.14, blue: 0.24),
                    Color(red: 0.08, green: 0.25, blue: 0.45),
                    Color(red: 0.10, green: 0.38, blue: 0.64)
                ],
                lightHorizon: Color(red: 0.48, green: 0.72, blue: 0.94),
                darkHorizon: Color(red: 0.22, green: 0.52, blue: 0.82),
                lightAccent: Color(red: 0.02, green: 0.45, blue: 0.95)
            )
        case .overcastBlue:
            return bluePalette(
                lightSky: [
                    Color(red: 0.78, green: 0.82, blue: 0.86),
                    Color(red: 0.57, green: 0.68, blue: 0.78),
                    Color(red: 0.30, green: 0.43, blue: 0.58),
                    Color(red: 0.10, green: 0.19, blue: 0.32)
                ],
                darkSky: [
                    Color(red: 0.03, green: 0.04, blue: 0.06),
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.06, green: 0.12, blue: 0.20),
                    Color(red: 0.06, green: 0.17, blue: 0.30)
                ],
                lightHorizon: Color(red: 0.32, green: 0.45, blue: 0.62),
                darkHorizon: Color(red: 0.12, green: 0.27, blue: 0.45),
                lightAccent: Color(red: 0.18, green: 0.38, blue: 0.62)
            )
        case .stormBlue:
            return bluePalette(
                lightSky: [
                    Color(red: 0.62, green: 0.68, blue: 0.74),
                    Color(red: 0.36, green: 0.49, blue: 0.62),
                    Color(red: 0.14, green: 0.28, blue: 0.45),
                    Color(red: 0.05, green: 0.12, blue: 0.24)
                ],
                darkSky: [
                    Color(red: 0.01, green: 0.02, blue: 0.04),
                    Color(red: 0.03, green: 0.06, blue: 0.10),
                    Color(red: 0.04, green: 0.10, blue: 0.20),
                    Color(red: 0.04, green: 0.15, blue: 0.32)
                ],
                lightHorizon: Color(red: 0.18, green: 0.38, blue: 0.58),
                darkHorizon: Color(red: 0.08, green: 0.24, blue: 0.44),
                lightAccent: Color(red: 0.10, green: 0.36, blue: 0.68)
            )
        case .frozenBlue:
            return bluePalette(
                lightSky: [
                    Color(red: 0.88, green: 0.93, blue: 0.96),
                    Color(red: 0.68, green: 0.80, blue: 0.90),
                    Color(red: 0.36, green: 0.54, blue: 0.72),
                    Color(red: 0.10, green: 0.24, blue: 0.42)
                ],
                darkSky: [
                    Color(red: 0.03, green: 0.05, blue: 0.08),
                    Color(red: 0.05, green: 0.10, blue: 0.17),
                    Color(red: 0.06, green: 0.18, blue: 0.31),
                    Color(red: 0.07, green: 0.26, blue: 0.44)
                ],
                lightHorizon: Color(red: 0.52, green: 0.70, blue: 0.86),
                darkHorizon: Color(red: 0.18, green: 0.42, blue: 0.66),
                lightAccent: Color(red: 0.18, green: 0.50, blue: 0.82)
            )
        }
    }

    private static func bluePalette(
        lightSky: [Color],
        darkSky: [Color],
        lightHorizon: Color,
        darkHorizon: Color,
        lightAccent: Color
    ) -> SunHatAtmospherePalette {
        SunHatAtmospherePalette(
            lightBase: lightSky[0],
            darkBase: darkSky[0],
            lightSky: lightSky,
            darkSky: darkSky,
            lightLine: Color(red: 0.07, green: 0.19, blue: 0.33).opacity(0.15),
            darkLine: Color(red: 0.78, green: 0.90, blue: 1.00).opacity(0.09),
            lightHorizon: lightHorizon,
            darkHorizon: darkHorizon,
            lightConditionAccent: lightAccent,
            darkConditionAccent: Color(red: 0.36, green: 0.70, blue: 1.00)
        )
    }
}
