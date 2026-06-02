//
//  WeatherConditionBuilder.swift
//  SunHat
//

import SwiftUI

struct WeatherConditionBuilder: View {
    @Binding var condition: WeatherConditionType
    @Binding var minTemp: Double
    @Binding var maxTemp: Double
    @Binding var temperatureType: TemperatureConditionType
    @Binding var selectedSkyConditions: Set<SkyCondition>
    @Binding var conditionMode: ConditionSelectionMode

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                HStack {
                    Text("Temperature")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(temperatureType == .temperatureRange
                         ? "\(Int(minTemp))° - \(Int(maxTemp))°F"
                         : "\(Int(minTemp))°F")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                HStack(spacing: 12) {
                    ForEach(TemperatureConditionType.allCases, id: \.self) { type in
                        Button {
                            temperatureType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.body)
                                    .foregroundColor(temperatureType == type ? .white : .blue)

                                Text(type.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(temperatureType == type ? .white : .primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(temperatureType == type ? Color.blue : Color(.tertiarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(type.displayName)
                        .accessibilityAddTraits(temperatureType == type ? .isSelected : [])
                    }
                }

                if temperatureType == .temperatureRange {
                    TemperatureRangeSlider(minTemp: $minTemp, maxTemp: $maxTemp)
                } else {
                    SingleTemperatureSlider(temperature: $minTemp)
                }
            }

            Divider()

            VStack(spacing: 12) {
                HStack {
                    Text("Sky Conditions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()
                }

                HStack(spacing: 0) {
                    ConditionModeTab(
                        title: "Remind if",
                        icon: "checkmark.circle.fill",
                        isSelected: conditionMode == .include
                    ) {
                        conditionMode = .include
                    }

                    ConditionModeTab(
                        title: "Exclude if",
                        icon: "xmark.circle.fill",
                        isSelected: conditionMode == .exclude
                    ) {
                        conditionMode = .exclude
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.tertiarySystemBackground))
                )
                .clipShape(.rect(cornerRadius: 10))

                Text(conditionMode == .include
                     ? "Remind me when it's any of these:"
                     : "Remind me unless it's any of these:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FlowLayoutConditions(spacing: 8) {
                    ForEach(SkyCondition.allCases) { sky in
                        SkyConditionChip(
                            sky: sky,
                            isSelected: selectedSkyConditions.contains(sky),
                            mode: conditionMode
                        ) {
                            if selectedSkyConditions.contains(sky) {
                                selectedSkyConditions.remove(sky)
                            } else {
                                selectedSkyConditions.insert(sky)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ConditionModeTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                isSelected
                    ? (title == "Exclude if"
                       ? AnyShapeStyle(Color.gray.opacity(0.85))
                       : AnyShapeStyle(Color.blue))
                    : AnyShapeStyle(Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SkyConditionChip: View {
    let sky: SkyCondition
    let isSelected: Bool
    let mode: ConditionSelectionMode
    let onTap: () -> Void

    private var chipColor: Color {
        guard isSelected else { return Color(.tertiarySystemBackground) }
        return mode == .include ? sky.color : .gray.opacity(0.15)
    }

    private var borderColor: Color {
        guard isSelected else { return Color.clear }
        return mode == .include ? sky.color : .gray.opacity(0.4)
    }

    private var textColor: Color {
        guard isSelected else { return .primary }
        return mode == .include ? .white : .gray
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: sky.icon)
                    .font(.caption)
                    .foregroundColor(isSelected && mode == .include ? .white : sky.color)

                Text(sky.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                if isSelected && mode == .exclude {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected && mode == .include ? sky.color.opacity(0.85) : chipColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sky.displayName), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FlowLayoutConditions: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

struct ConditionTypeButton: View {
    let conditionType: WeatherConditionType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: conditionType.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)

                Text(conditionType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conditionType.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
