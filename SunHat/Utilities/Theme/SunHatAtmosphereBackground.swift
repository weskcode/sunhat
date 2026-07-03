//
//  SunHatAtmosphereBackground.swift
//  SunHat
//
//  Created by Codex on 7/2/26.
//

import SwiftUI

struct SunHatAtmosphereBackground: View {
    var condition: WeatherCondition = .unknown
    var intensity: Double = 1

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                draw(in: context, size: size, date: timeline.date)
            }
        }
        .background(baseColor)
        .accessibilityHidden(true)
    }

    private var baseColor: Color {
        colorScheme == .dark ? Color(red: 0.03, green: 0.05, blue: 0.07) : Color(red: 0.93, green: 0.97, blue: 0.98)
    }

    private var skyGradient: Gradient {
        if colorScheme == .dark {
            Gradient(colors: [
                Color(red: 0.02, green: 0.04, blue: 0.07),
                Color(red: 0.05, green: 0.11, blue: 0.14),
                Color(red: 0.08, green: 0.17, blue: 0.17),
                Color(red: 0.18, green: 0.13, blue: 0.09)
            ])
        } else {
            Gradient(colors: [
                Color(red: 0.88, green: 0.96, blue: 0.99),
                Color(red: 0.78, green: 0.92, blue: 0.93),
                Color(red: 0.94, green: 0.89, blue: 0.75),
                Color(red: 0.99, green: 0.96, blue: 0.90)
            ])
        }
    }

    private var lineColor: Color {
        colorScheme == .dark ? .white.opacity(0.075) : Color(red: 0.10, green: 0.25, blue: 0.28).opacity(0.13)
    }

    private var horizonColor: Color {
        colorScheme == .dark ? Color(red: 0.95, green: 0.50, blue: 0.22) : Color(red: 0.99, green: 0.63, blue: 0.27)
    }

    private func draw(in context: GraphicsContext, size: CGSize, date: Date) {
        guard size.width > 0, size.height > 0 else { return }

        let rect = CGRect(origin: .zero, size: size)
        var background = Path()
        background.addRect(rect)
        context.fill(
            background,
            with: .linearGradient(
                skyGradient,
                startPoint: CGPoint(x: size.width * 0.15, y: 0),
                endPoint: CGPoint(x: size.width * 0.88, y: size.height)
            )
        )

        drawHorizon(in: context, size: size)
        drawForecastGrid(in: context, size: size)
        drawContourLines(in: context, size: size, date: date)
        drawConditionAccent(in: context, size: size, date: date)
    }

    private func drawHorizon(in context: GraphicsContext, size: CGSize) {
        let horizonRect = CGRect(
            x: -size.width * 0.20,
            y: size.height * 0.52,
            width: size.width * 1.40,
            height: size.height * 0.28
        )
        var horizon = Path()
        horizon.addEllipse(in: horizonRect)
        context.fill(
            horizon,
            with: .radialGradient(
                Gradient(colors: [
                    horizonColor.opacity(0.30 * intensity),
                    horizonColor.opacity(0.10 * intensity),
                    .clear
                ]),
                center: CGPoint(x: size.width * 0.52, y: size.height * 0.60),
                startRadius: size.width * 0.08,
                endRadius: size.width * 0.78
            )
        )
    }

    private func drawForecastGrid(in context: GraphicsContext, size: CGSize) {
        let top = size.height * 0.12
        let bottom = size.height * 0.96
        let step = max(size.width / 6, 56)

        for index in 0...7 {
            let x = CGFloat(index) * step - step * 0.35
            var line = Path()
            line.move(to: CGPoint(x: x, y: top))
            line.addLine(to: CGPoint(x: x + size.width * 0.20, y: bottom))
            context.stroke(line, with: .color(lineColor.opacity(0.34)), lineWidth: 0.7)
        }

        for index in 0...8 {
            let y = top + CGFloat(index) * ((bottom - top) / 8)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y - size.height * 0.035))
            context.stroke(line, with: .color(lineColor.opacity(0.26)), lineWidth: 0.7)
        }
    }

    private func drawContourLines(in context: GraphicsContext, size: CGSize, date: Date) {
        let phase = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 0.10)) * 12
        let count = 7

        for index in 0..<count {
            let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
            let baseY = size.height * (0.22 + progress * 0.58)
            var path = Path()
            path.move(to: CGPoint(x: -24, y: baseY + phase * (0.4 + progress)))
            path.addCurve(
                to: CGPoint(x: size.width + 24, y: baseY - 18 + phase * (1 - progress)),
                control1: CGPoint(x: size.width * 0.28, y: baseY - 36 - CGFloat(index * 2)),
                control2: CGPoint(x: size.width * 0.70, y: baseY + 42 + CGFloat(index * 3))
            )
            context.stroke(path, with: .color(lineColor.opacity(0.75 - progress * 0.30)), lineWidth: 1)
        }
    }

    private func drawConditionAccent(in context: GraphicsContext, size: CGSize, date: Date) {
        switch condition {
        case .rain, .drizzle, .thunderstorm:
            drawRainVectors(in: context, size: size, date: date)
        case .snow, .sleet, .hail:
            drawSnowCrystals(in: context, size: size, date: date)
        case .clear, .partlyCloudy:
            drawSolarArc(in: context, size: size, date: date)
        default:
            drawPressureBands(in: context, size: size, date: date)
        }
    }

    private func drawSolarArc(in context: GraphicsContext, size: CGSize, date: Date) {
        let drift = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 0.18)) * 5
        let center = CGPoint(x: size.width * 0.78, y: size.height * 0.20 + drift)
        let radius = min(size.width, size.height) * 0.16
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: .degrees(28), endAngle: .degrees(326), clockwise: false)
        context.stroke(arc, with: .color(horizonColor.opacity(0.30)), lineWidth: 18)
        context.stroke(arc, with: .color(.white.opacity(colorScheme == .dark ? 0.10 : 0.30)), lineWidth: 1)
    }

    private func drawRainVectors(in context: GraphicsContext, size: CGSize, date: Date) {
        let phase = reduceMotion ? 0 : CGFloat(date.timeIntervalSinceReferenceDate * 140).truncatingRemainder(dividingBy: 92)
        for index in 0..<22 {
            let x = CGFloat(index) * size.width / 18 - 40
            let y = CGFloat((index * 47) % 260) + phase
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x - 12, y: y + 38))
            context.stroke(drop, with: .color(Color.cyan.opacity(0.18)), lineWidth: 1.6)
        }
    }

    private func drawSnowCrystals(in context: GraphicsContext, size: CGSize, date: Date) {
        let phase = reduceMotion ? 0 : CGFloat(date.timeIntervalSinceReferenceDate * 20).truncatingRemainder(dividingBy: 80)
        for index in 0..<16 {
            let x = CGFloat((index * 73) % 360) / 360 * size.width
            let y = CGFloat((index * 41) % 520) + phase
            var flake = Path()
            flake.addEllipse(in: CGRect(x: x, y: y, width: 3.5, height: 3.5))
            context.fill(flake, with: .color(.white.opacity(0.24)))
        }
    }

    private func drawPressureBands(in context: GraphicsContext, size: CGSize, date: Date) {
        let drift = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 0.08)) * 18
        for index in 0..<4 {
            let rect = CGRect(
                x: -size.width * 0.15 + drift + CGFloat(index * 28),
                y: size.height * (0.18 + CGFloat(index) * 0.12),
                width: size.width * 0.78,
                height: 46
            )
            var band = Path()
            band.addRoundedRect(in: rect, cornerSize: CGSize(width: 24, height: 24))
            context.fill(
                band,
                with: .linearGradient(
                    Gradient(colors: [lineColor.opacity(0.62), lineColor.opacity(0.08)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                )
            )
        }
    }
}
