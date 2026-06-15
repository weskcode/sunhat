//
//  FirstReminderCreationPreview.swift
//  SunHat
//

import SwiftUI

#Preview {
    VStack(spacing: 20) {
        TitleNotesIconSection(
            title: .constant("Morning Walk"),
            notes: .constant(""),
            selectedIcon: .constant("figure.walk")
        )

        WeatherConditionBuilder(
            condition: .constant(.temperatureRange),
            minTemp: .constant(65),
            maxTemp: .constant(75),
            temperatureType: .constant(.temperatureRange),
            selectedSkyConditions: .constant([.sunny, .partlyCloudy]),
            conditionMode: .constant(.include)
        )
    }
    .padding()
}
