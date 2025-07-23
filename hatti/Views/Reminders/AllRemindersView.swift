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
                ForEach(reminders.map { reminder in
                    let desc = reminder.triggerCondition?.formatDescription() ?? "No condition set"
                    return WeatherReminderDisplay(
                        id: reminder.id,
                        title: reminder.title,
                        reminderDescription: reminder.reminderDescription,
                        category: reminder.category,
                        priority: reminder.priority,
                        isActive: reminder.isActive,
                        isCompleted: reminder.isCompleted,
                        isPaused: reminder.isPaused,
                        createdDate: reminder.createdDate,
                        lastTriggered: reminder.lastTriggered,
                        triggerCount: reminder.triggerCount,
                        nextEvaluationDate: reminder.nextEvaluationDate,
                        conditionDescription: desc
                    )
                }, id: \.id) { display in
                    ActiveReminderCard(reminder: display, weatherData: nil)
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
