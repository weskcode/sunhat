//
//  SunHatProductComponents.swift
//  SunHat
//
//  Created by Codex on 6/28/26.
//

import SwiftUI

struct SunHatPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(SunHatMotion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct SunHatCardSection<Content: View>: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var actionTitle: String?
    var actionSystemImage: String?
    var action: (() -> Void)?
    var tint: Color
    let content: Content

    init(
        title: String,
        systemImage: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        tint: Color = .accentColor,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.tint = tint
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AppFontStyle.headline.font)
                            .foregroundStyle(.primary)

                        if let subtitle {
                            Text(subtitle)
                                .font(AppFontStyle.caption.font)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: systemImage)
                        .font(AppFontStyle.subheadline.font)
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 8)

                if let action, let actionTitle {
                    Button(action: action) {
                        Label(actionTitle, systemImage: actionSystemImage ?? "chevron.right")
                            .labelStyle(.titleAndIcon)
                            .font(AppFontStyle.callout.font.weight(.medium))
                    }
                    .buttonStyle(SunHatPressButtonStyle())
                    .foregroundStyle(tint)
                    .accessibilityLabel(actionTitle)
                }
            }

            content
        }
        .padding(16)
        .glassEffect(.regular.tint(tint.opacity(0.05)), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

struct SunHatStatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(AppFontStyle.caption2.font.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .accessibilityElement(children: .combine)
    }
}

struct SunHatEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var actionSystemImage: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(AppFontStyle.title2.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                }
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text(title)
                    .font(AppFontStyle.headline.font)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(AppFontStyle.callout.font)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let action, let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage ?? "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(Color.accentColor)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(message)
    }
}
