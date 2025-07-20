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
        NavigationView {
            List {
                ForEach(reminders) { reminder in
                    ActiveReminderCard(reminder: reminder, weatherData: nil)
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