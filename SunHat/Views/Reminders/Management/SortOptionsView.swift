//
//  SortOptionsView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct SortOptionsView: View {
    @Binding var selectedSort: SortOption
    @Binding var selectedOrder: SortOrder

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            sortOptionRow(
                                icon: option.icon,
                                title: option.displayName,
                                isSelected: selectedSort == option
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Order") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            selectedOrder = order
                        } label: {
                            sortOptionRow(
                                icon: order.icon,
                                title: order.displayName,
                                isSelected: selectedOrder == order
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Sort Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sortOptionRow(icon: String, title: String, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }
}
