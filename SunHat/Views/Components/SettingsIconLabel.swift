//
//  SettingsIconLabel.swift
//  SunHat
//
//  Created by Wesley Keetch on 6/12/26.
//

import SwiftUI

/// A settings row label in the style of the system Settings app: a small
/// colored rounded-square icon with a white SF Symbol, followed by the title.
struct SettingsIconLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    // A fixed-point icon frame stops scaling once the row's text grows with
    // Dynamic Type, which the accessibility audit flags as "Dynamic Type
    // font sizes are partially unsupported". @ScaledMetric ties the icon
    // frame to the same text-size setting so it grows with the row.
    @ScaledMetric(relativeTo: .body) private var iconDimension: CGFloat = 29
    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 14

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconDimension, height: iconDimension)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
        }
    }
}

#Preview {
    Form {
        Section {
            Toggle(isOn: .constant(true)) {
                SettingsIconLabel(title: "Allow Notifications", systemImage: "bell.badge.fill", color: .red)
            }
            SettingsIconLabel(title: "Location", systemImage: "location.fill", color: .blue)
            SettingsIconLabel(title: "Temperature Unit", systemImage: "thermometer.medium", color: .orange)
        }
    }
}
