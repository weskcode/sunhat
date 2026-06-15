//
//  TimePreferencesBuilder.swift
//  SunHat
//

import SwiftUI

struct TimePreferencesBuilder: View {
    @Binding var timeRange: TimeRange
    @Binding var quietHours: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                HStack {
                    Text("Preferred Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(TimeRange.allCases, id: \.self) { timeRangeOption in
                        TimeRangeButton(
                            timeRange: timeRangeOption,
                            isSelected: timeRange == timeRangeOption
                        ) {
                            timeRange = timeRangeOption
                        }
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Respect Quiet Hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text("Avoid notifications during sleep hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $quietHours)
                    .labelsHidden()
            }
        }
    }
}

private struct TimeRangeButton: View {
    let timeRange: TimeRange
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: timeRange.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .orange)

                Text(timeRange.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timeRange.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
