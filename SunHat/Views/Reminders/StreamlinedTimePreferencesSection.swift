//
//  StreamlinedTimePreferencesSection.swift
//  SunHat
//
//  Created by Claude on 6/12/26.
//

import SwiftUI

/// The "Time" card in the streamlined reminder creator — preferred time
/// range grid and the quiet-hours toggle.
struct StreamlinedTimePreferencesSection: View {
    @ObservedObject var viewModel: FirstReminderCreationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(icon: "clock.fill", title: "When")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(TimeRange.allCases, id: \.self) { timeRange in
                    timeRangeButton(for: timeRange)
                }
            }

            Divider()

            quietHoursToggle
        }
        .cardStyle()
    }

    private func timeRangeButton(for timeRange: TimeRange) -> some View {
        Button {
            withAnimation(selectionAnimation) {
                viewModel.customReminder.preferredTimeRange = timeRange
            }

            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            SelectableTileLabel(
                icon: timeRange.icon,
                title: timeRange.displayName,
                isSelected: viewModel.customReminder.preferredTimeRange == timeRange,
                tint: viewModel.customReminder.selectedColor,
                iconUsesTintWhenUnselected: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timeRange.displayName)
        .accessibilityAddTraits(viewModel.customReminder.preferredTimeRange == timeRange ? .isSelected : [])
    }

    private var quietHoursToggle: some View {
        Toggle(isOn: $viewModel.customReminder.respectQuietHours) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Respect Quiet Hours")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("Avoid notifications during sleep")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : .smooth(duration: 0.2)
    }
}
