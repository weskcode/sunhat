//
//  AllRemindersView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct AllRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var reminders: [WeatherReminder]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders) { reminder in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: reminder.category.iconName)
                                .foregroundColor(.blue)

                            Text(reminder.displayTitle)
                                .font(.headline)

                            Spacer()

                            if reminder.isCurrentlyActive {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        if let condition = reminder.triggerCondition {
                            Text("When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature, specifier: "%.1f")°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("Created: \(reminder.createdDate, format: .dateTime.month().day().hour().minute())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteReminders)
            }
            .navigationTitle("All Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteReminders(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(reminders[index])
            }
        }
    }
}

#Preview {
    AllRemindersView()
        .modelContainer(for: [WeatherReminder.self], inMemory: true)
}
