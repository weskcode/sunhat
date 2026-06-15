//
//  FirstReminderCreationViewModelActivityDefaultsTests.swift
//  SunHatTests
//

import SwiftUI
import Testing
@testable import SunHat

@MainActor
struct FirstReminderCreationViewModelActivityDefaultsTests {
    @Test(
        "Activity titles choose expected icon defaults",
        arguments: [
            ("Morning run", "figure.run"),
            ("Evening walk", "figure.walk"),
            ("Garden before sunset", "leaf.fill"),
            ("Pool day", "figure.pool.swim"),
            ("Photo walk", "camera.fill"),
            ("Bike commute", "bicycle"),
            ("Dog walk", "dog.fill")
        ]
    )
    func activityTitleChoosesExpectedIcon(title: String, expectedIcon: String) {
        let viewModel = FirstReminderCreationViewModel()

        viewModel.applyActivityDefaults(from: title)

        #expect(viewModel.customReminder.selectedIcon == expectedIcon)
    }

    @Test(
        "Activity titles choose expected color defaults",
        arguments: [
            ("Morning run", Color.blue),
            ("Evening walk", Color.green),
            ("Garden before sunset", Color.green),
            ("Pool day", Color.cyan),
            ("Photo shoot", Color.purple),
            ("Bike commute", Color.orange),
            ("Dog park", Color.orange)
        ]
    )
    func activityTitleChoosesExpectedColor(title: String, expectedColor: Color) {
        let viewModel = FirstReminderCreationViewModel()

        viewModel.applyActivityDefaults(from: title)

        #expect(viewModel.customReminder.selectedColor == expectedColor)
    }

    @Test("Unknown activity keeps existing defaults")
    func unknownActivityKeepsExistingDefaults() {
        let viewModel = FirstReminderCreationViewModel()
        viewModel.customReminder.selectedIcon = "star.fill"
        viewModel.customReminder.selectedColor = .indigo

        viewModel.applyActivityDefaults(from: "Check the mailbox")

        #expect(viewModel.customReminder.selectedIcon == "star.fill")
        #expect(viewModel.customReminder.selectedColor == .indigo)
    }

    @Test("Template selection applies activity appearance defaults")
    func templateSelectionAppliesActivityAppearanceDefaults() {
        let viewModel = FirstReminderCreationViewModel()
        let template = ReminderTemplate(
            id: UUID(),
            title: "Pool Template",
            description: "Pool weather",
            icon: "star.fill",
            color: .red,
            defaultTitle: "Pool day",
            iconName: "star.fill",
            condition: .temperatureRange,
            minTemperature: 75,
            maxTemperature: 90,
            exampleTrigger: "75-90°F"
        )

        viewModel.selectTemplate(template)

        #expect(viewModel.customReminder.selectedIcon == "figure.pool.swim")
        #expect(viewModel.customReminder.selectedColor == .cyan)
        #expect(viewModel.customReminder.temperatureType == .temperatureRange)
        #expect(viewModel.customReminder.minTemperature == 75)
        #expect(viewModel.customReminder.maxTemperature == 90)
    }
}
