//
//  FilterOptionsView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct FilterOptionsView: View {
    @Binding var selectedCategories: Set<ReminderCategory>
    @Binding var selectedStatuses: Set<ReminderStatus>
    @Binding var temperatureRange: ClosedRange<Double>

    @Environment(\.dismiss) private var dismiss
    @State private var tempRange = 0.0...100.0

    var body: some View {
        NavigationStack {
            Form {
                categoriesSection
                statusSection
                temperatureSection
            }
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All", action: clearAllFilters)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            tempRange = temperatureRange
        }
    }

    private var categoriesSection: some View {
        Section("Categories") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ReminderCategory.allCases, id: \.self) { category in
                    FilterCategoryButton(
                        category: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        toggleCategory(category)
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            ForEach(ReminderStatus.allCases, id: \.self) { status in
                Button {
                    toggleStatus(status)
                } label: {
                    HStack {
                        Image(systemName: status.icon)
                            .foregroundStyle(status.color)
                            .frame(width: 20)

                        Text(status.displayName)
                            .font(.subheadline)

                        Spacer()

                        if selectedStatuses.contains(status) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var temperatureSection: some View {
        Section("Temperature Range") {
            VStack(spacing: 16) {
                HStack {
                    Text("Temperature")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(Int(tempRange.lowerBound))° - \(Int(tempRange.upperBound))°F")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }

                RangeSlider(
                    range: $tempRange,
                    bounds: 0...110,
                    step: 1
                )
                .frame(height: 20)
            }
            .listRowBackground(Color.clear)
        }
    }

    private func toggleCategory(_ category: ReminderCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func toggleStatus(_ status: ReminderStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }

    private func clearAllFilters() {
        selectedCategories.removeAll()
        selectedStatuses.removeAll()
        tempRange = 0...100
    }

    private func applyFilters() {
        temperatureRange = tempRange
    }
}

private struct FilterCategoryButton: View {
    let category: ReminderCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : categoryColor)

                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? categoryColor : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch category {
        case .general: return .blue
        case .outdoor: return .green
        case .gardening: return .green
        case .exercise: return .red
        case .maintenance: return .orange
        case .travel: return .purple
        case .health: return .pink
        case .sports: return .cyan
        case .work: return .indigo
        case .seasonal: return .brown
        case .emergency: return .red
        case .custom: return .gray
        }
    }
}
