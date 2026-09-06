//
//  SunHatMotion.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/27/26.
//

import SwiftUI

enum SunHatMotion {
    static func reveal(reduceMotion: Bool, delay: TimeInterval = 0) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.12).delay(delay) : .smooth(duration: 0.38).delay(delay)
    }

    static func cardToggle(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.14) : .smooth(duration: 0.28)
    }

    static func press(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.08) : .smooth(duration: 0.16)
    }

    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity)
    }
}

extension AnyTransition {
    static var weatherSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
