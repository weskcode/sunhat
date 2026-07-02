//
//  SunHatMotion.swift
//  SunHat
//
//  Created by Codex on 6/27/26.
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

    static func emphasized(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.16) : .interpolatingSpring(duration: 0.34, bounce: 0.22)
    }

    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity)
    }
}

struct WeatherConditionLayer: View {
    let condition: WeatherCondition
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                draw(in: context, size: size, date: timeline.date)
            }
        }
        .opacity(reduceMotion ? 0.16 : 0.26)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: GraphicsContext, size: CGSize, date: Date) {
        guard size.width > 0, size.height > 0 else { return }

        switch condition {
        case .clear, .partlyCloudy:
            drawSun(in: context, size: size, date: date)
        case .rain, .drizzle, .thunderstorm:
            drawRain(in: context, size: size, date: date)
        case .snow, .sleet, .hail:
            drawSnow(in: context, size: size, date: date)
        case .cloudy, .overcast, .fog, .windy, .unknown:
            drawCloudBands(in: context, size: size, date: date)
        }
    }

    private func drawSun(in context: GraphicsContext, size: CGSize, date: Date) {
        let pulse = reduceMotion ? 0 : sin(date.timeIntervalSinceReferenceDate * 0.6) * 6
        let center = CGPoint(x: size.width * 0.82, y: size.height * 0.14)
        let radius = max(56, min(size.width, size.height) * 0.12 + pulse)

        var glow = Path()
        glow.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(glow, with: .radialGradient(
            Gradient(colors: [.yellow.opacity(0.34), .orange.opacity(0.04), .clear]),
            center: center,
            startRadius: 8,
            endRadius: radius
        ))
    }

    private func drawRain(in context: GraphicsContext, size: CGSize, date: Date) {
        let count = reduceMotion ? 10 : 18
        let phase = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate * 160

        for index in 0..<count {
            let x = (CGFloat(index) / CGFloat(count)) * size.width + CGFloat((index * 37) % 29)
            let y = CGFloat(phase + Double(index * 53)).truncatingRemainder(dividingBy: size.height + 80) - 40
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x - 8, y: y + 28))
            context.stroke(drop, with: .color(.blue.opacity(0.22)), lineWidth: 2)
        }
    }

    private func drawSnow(in context: GraphicsContext, size: CGSize, date: Date) {
        let count = reduceMotion ? 8 : 16
        let phase = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate * 34

        for index in 0..<count {
            let x = (CGFloat(index) / CGFloat(count)) * size.width + CGFloat((index * 31) % 23)
            let y = CGFloat(phase + Double(index * 47)).truncatingRemainder(dividingBy: size.height + 40) - 20
            var flake = Path()
            flake.addEllipse(in: CGRect(x: x, y: y, width: 4, height: 4))
            context.fill(flake, with: .color(.cyan.opacity(0.24)))
        }
    }

    private func drawCloudBands(in context: GraphicsContext, size: CGSize, date: Date) {
        let drift = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 0.08)) * 18

        for index in 0..<3 {
            let y = size.height * (0.14 + CGFloat(index) * 0.13)
            let rect = CGRect(x: -40 + drift + CGFloat(index * 24), y: y, width: size.width * 0.72, height: 54)
            var band = Path()
            band.addRoundedRect(in: rect, cornerSize: CGSize(width: 28, height: 28))
            context.fill(band, with: .linearGradient(
                Gradient(colors: [.gray.opacity(0.14), Color.secondary.opacity(0.04)]),
                startPoint: CGPoint(x: rect.minX, y: rect.midY),
                endPoint: CGPoint(x: rect.maxX, y: rect.midY)
            ))
        }
    }
}
