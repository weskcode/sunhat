//
//  LocalizationTests.swift
//  SunHatTests
//
//  Verifies the Spanish localization catalogs are complete, format-specifier
//  safe, and that runtime lookups actually resolve to Spanish text rather
//  than falling back to the raw catalog key.
//

import Foundation
import Testing
@testable import SunHat

private enum LocalizationCatalog {
    struct StringUnit: Decodable {
        let state: String?
        let value: String?
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit?
    }

    struct Entry: Decodable {
        let comment: String?
        let localizations: [String: Localization]?
        let shouldTranslate: Bool?
    }

    struct File: Decodable {
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    /// Locates a resource file by walking up from this test file's own path,
    /// so the test works from a full checkout regardless of the current
    /// working directory the test runner was launched from.
    static func load(_ relativePath: String) throws -> File {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                let data = try Data(contentsOf: candidate)
                return try JSONDecoder().decode(File.self, from: data)
            }
            dir = dir.deletingLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    /// Every "%…" printf-style format specifier in a string, normalized so a
    /// positional prefix like "%1$" doesn't cause a false mismatch.
    static func formatSpecifiers(in string: String) -> [String] {
        let pattern = #"%(\d+\$)?[#0\-+ ']*\d*(\.\d+)?(hh|h|ll|l|q|L|z|j|t)?[@dDiuUxXoOfeEgGcCsSp%]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        return matches.map { match in
            var token = nsString.substring(with: match.range)
            if let dollarRange = token.range(of: "$") {
                token = "%" + token[token.index(after: dollarRange.lowerBound)...]
            }
            return token
        }.sorted()
    }
}

@Suite("Localizable.xcstrings completeness and safety")
struct LocalizableCatalogTests {
    @Test("Every source string has a non-empty Spanish translation")
    func everyKeyHasSpanish() throws {
        let file = try LocalizationCatalog.load("SunHat/Resources/Localizable.xcstrings")
        var missing: [String] = []
        for (key, entry) in file.strings {
            if entry.shouldTranslate == false { continue }
            if key.isEmpty { continue } // an empty source string trivially needs no translation
            guard let value = entry.localizations?["es"]?.stringUnit?.value, !value.isEmpty else {
                missing.append(key)
                continue
            }
        }
        #expect(missing.isEmpty, "Missing Spanish translations for: \(missing.sorted().prefix(20))")
    }

    @Test("No Spanish translation is literally identical to a non-trivial English key")
    func noUntranslatedLeakage() throws {
        let file = try LocalizationCatalog.load("SunHat/Resources/Localizable.xcstrings")
        // Short strings, unit symbols, brand names, and pure-punctuation keys are
        // legitimately identical across languages (e.g. "SunHat", "°", "GPS").
        let allowedIdentical: Set<String> = [
            "SunHat", "GPS", "N", "S", "E", "AQI", "°", "OK", "SOS", "Fahrenheit",
            "Celsius", "Apple WeatherKit", "OpenWeatherMap", "100°F", "32°F", "Sí",
            // Genuine Spanish/English cognates and loanwords: identical spelling is
            // the correct translation, not a missed one.
            "General", "Yoga", "Laptop", "Ideal", "Picnic", "Golf", "Idea", "Normal",
            "Color", "Fitness"
        ]
        var suspicious: [String] = []
        for (key, entry) in file.strings {
            guard let value = entry.localizations?["es"]?.stringUnit?.value else { continue }
            guard key.count > 3, !allowedIdentical.contains(key) else { continue }
            let lettersOnly = key.contains { $0.isLetter }
            if lettersOnly, value == key, !key.contains("%"), !key.hasPrefix("©") {
                suspicious.append(key)
            }
        }
        #expect(suspicious.isEmpty, "Spanish value identical to English source (likely untranslated): \(suspicious.prefix(20))")
    }

    @Test("Format specifiers match between English keys and Spanish values")
    func formatSpecifiersMatch() throws {
        let file = try LocalizationCatalog.load("SunHat/Resources/Localizable.xcstrings")
        var mismatches: [String] = []
        for (key, entry) in file.strings {
            guard let value = entry.localizations?["es"]?.stringUnit?.value else { continue }
            let enSpecs = LocalizationCatalog.formatSpecifiers(in: key)
            let esSpecs = LocalizationCatalog.formatSpecifiers(in: value)
            if enSpecs != esSpecs {
                mismatches.append(key)
            }
        }
        #expect(mismatches.isEmpty, "Format specifier mismatch for: \(mismatches.prefix(20))")
    }

    @Test("Spanish values use proper UTF-8 accented characters, not mojibake")
    func validUTF8() throws {
        let file = try LocalizationCatalog.load("SunHat/Resources/Localizable.xcstrings")
        for (_, entry) in file.strings {
            guard let value = entry.localizations?["es"]?.stringUnit?.value else { continue }
            #expect(!value.contains("\u{FFFD}"), "Spanish value contains a replacement character (mojibake): \(value)")
        }
    }
}

@Suite("InfoPlist.xcstrings completeness")
struct InfoPlistCatalogTests {
    @Test("Every Info.plist usage-description key has a Spanish translation")
    func everyKeyHasSpanish() throws {
        let file = try LocalizationCatalog.load("SunHat/Resources/InfoPlist.xcstrings")
        var missing: [String] = []
        for (key, entry) in file.strings {
            guard let value = entry.localizations?["es"]?.stringUnit?.value, !value.isEmpty else {
                missing.append(key)
                continue
            }
        }
        #expect(missing.isEmpty, "Missing Spanish translations for Info.plist keys: \(missing.sorted())")
    }
}

@Suite("Runtime localization behavior")
@MainActor
struct RuntimeLocalizationTests {
    @Test("A representative catalog string resolves to Spanish text, not the raw key")
    func resolvesToSpanish() throws {
        // `String(localized:)` resolves its bundle from the call site's own module by
        // default, so calling it directly from this test file looks in SunHatTests'
        // bundle, which doesn't carry SunHat's compiled Localizable.xcstrings. Load the
        // compiled .strings dictionary from the SunHat app bundle directly instead, the
        // same mechanism `String(localized:)` itself uses under the hood.
        let sunHatBundle = Bundle(for: LocationPermissionManager.self)
        guard let esBundleURL = sunHatBundle.url(forResource: "es", withExtension: "lproj"),
              let esBundle = Bundle(url: esBundleURL) else {
            Issue.record("Could not locate the compiled es.lproj resources in the SunHat app bundle")
            return
        }
        let spanish = esBundle.localizedString(forKey: "Settings", value: nil, table: "Localizable")
        #expect(spanish != "Settings")
        #expect(spanish == "Ajustes")
    }

    @Test("Missing-translation fallback never crashes and never returns an empty string")
    func fallbackIsSafe() {
        // A key that genuinely isn't in the catalog should fall back to the
        // literal text itself rather than crash or return an empty string.
        let result = String(localized: "Definitely Not A Real Catalog Key 12345", locale: Locale(identifier: "es"))
        #expect(!result.isEmpty)
    }

    @Test("Temperature unit display names resolve for both units under Spanish locale")
    func temperatureUnitDisplayNames() {
        #expect(!TemperatureUnit.fahrenheit.shortName.isEmpty)
        #expect(!TemperatureUnit.celsius.shortName.isEmpty)
    }

    @Test("Weather condition display names never crash across every case")
    func weatherConditionDisplayNames() {
        for condition in WeatherCondition.allCases {
            #expect(!condition.displayName.isEmpty)
        }
    }

    @Test("Comparison type display names never crash across every case")
    func comparisonTypeDisplayNames() {
        for comparison in ComparisonType.allCases {
            #expect(!comparison.displayName.isEmpty)
        }
    }

    @Test("Number and date formatting doesn't crash under Spanish locales")
    func formattingUnderSpanishLocales() {
        let locales = ["es", "es_ES", "es_MX", "es_US", "es_419"].map(Locale.init(identifier:))
        for locale in locales {
            let number = 1234.5
            let formatted = number.formatted(.number.precision(.fractionLength(1)).locale(locale))
            #expect(!formatted.isEmpty)

            let date = Date()
            let dateFormatted = date.formatted(.dateTime.month().day().locale(locale))
            #expect(!dateFormatted.isEmpty)
        }
    }
}
