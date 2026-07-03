//
//  DashboardMetricRow.swift
//  SunHat
//
//  Created by Codex on 7/3/26.
//

import SwiftUI

struct DashboardMetricRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(AppFontStyle.title3.font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(tint.opacity(0.12))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFontStyle.subheadline.font.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(primary)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Text(secondary)
                    .font(AppFontStyle.caption.font)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(primary), \(secondary)")
    }
}
