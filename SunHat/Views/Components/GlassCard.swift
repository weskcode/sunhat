//
//  GlassCard.swift
//  SunHat
//
//  iOS 26.4 Liquid Glass reusable card component
//

import SwiftUI

// MARK: - GlassCard

/// A Liquid Glass container card for iOS 26.4.
/// Wrap any content in `GlassCard` to get the system-standard glass surface
/// with consistent corner radius, spacing, and shadow.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: EdgeInsets
    let content: Content

    init(
        cornerRadius: CGFloat = 20,
        padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - GlassSection

/// A titled section card with Liquid Glass styling.
struct GlassSection<Content: View>: View {
    let title: String
    let icon: String
    var iconColor: Color
    let content: Content

    init(
        title: String,
        icon: String,
        iconColor: Color = .primary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(AppFontStyle.headline.font)
                .fontWeight(.semibold)
                .foregroundStyle(iconColor)

            content
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

// MARK: - GlassMetricBadge

/// A small pill/badge with a glass background for metric display.
struct GlassMetricBadge: View {
    let label: String
    let value: String
    var color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFontStyle.headline.font)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(AppFontStyle.caption2.font)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .capsule)
    }
}

// MARK: - GlassEffectContainer Variants

extension View {
    /// Applies a glass card appearance with the given shape.
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self.glassEffect(in: .rect(cornerRadius: cornerRadius))
    }

    /// Applies a glass capsule appearance.
    func glassCapsule() -> some View {
        self.glassEffect(in: .capsule)
    }

    /// Applies a glass circle appearance.
    func glassCircle() -> some View {
        self.glassEffect(in: .circle)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassEffectContainer {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Weather")
                            .font(AppFontStyle.headline.font)
                        Text("72°F — Partly Cloudy")
                            .font(AppFontStyle.title.font)
                            .fontWeight(.bold)
                    }
                }

                GlassSection(title: "Metrics", icon: "chart.bar.fill", iconColor: .blue) {
                    HStack {
                        GlassMetricBadge(label: "Humidity", value: "65%", color: .cyan)
                        GlassMetricBadge(label: "Wind", value: "12 mph", color: .green)
                        GlassMetricBadge(label: "UV", value: "4", color: .orange)
                    }
                }

                Button("Get Started") {}
                    .buttonStyle(.glass)
                    .tint(.blue)
            }
            .padding()
        }
        .padding()
    }
}
