//
//  SettingsIconLabel.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// A settings row label in the style of the system Settings app: a small
/// colored rounded-square icon with a white SF Symbol, followed by the title.
struct SettingsIconLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
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
