//
//  ManualCoordinateParsingTests.swift
//  SunHatTests
//
//  Regression coverage: users in decimal-comma locales (es-ES, de, fr) type
//  "-33,8688". Plain Double(_:) rejects that, which left Save disabled with no
//  explanation.
//

import Testing
@testable import SunHat

struct ManualCoordinateParsingTests {
    @Test("Accepts a decimal comma, surrounding whitespace and a typographic minus",
          arguments: [
            ("-33.8688", -33.8688),
            ("-33,8688", -33.8688),
            ("  151.2093 ", 151.2093),
            ("\u{2212}104,9903", -104.9903),
            ("0", 0.0),
          ])
    func parsesCommonInput(text: String, expected: Double) {
        #expect(ManualLocationEntrySheet.parseCoordinate(text) == expected)
    }

    @Test("Rejects input that isn't a single number", arguments: ["", "abc", "1,234.5", "12.3.4", "--1"])
    func rejectsInvalidInput(text: String) {
        #expect(ManualLocationEntrySheet.parseCoordinate(text) == nil)
    }
}
