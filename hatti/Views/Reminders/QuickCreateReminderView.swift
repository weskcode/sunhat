//
//  QuickCreateReminderView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct QuickCreateReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var selectedCategory: ReminderCategory = .general
    @State private var targetTemperature: Double = 70.0
    @State private var comparisonType: ComparisonType = .above
    
    var body: some View {
        NavigationView {
            Form {
                Section("Reminder Details") {
                    TextField("What would you like to be reminded about?", text: $title)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ReminderCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                }
                
                Section("Temperature Trigger") {
                    HStack {
                        Text("When temperature is")
                        
                        Picker("Comparison", selection: $comparisonType) {
                            ForEach(ComparisonType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Slider(value: $targetTemperature, in: 0...100, step: 1)
                        Text("\(Int(targetTemperature))°F")
                            .frame(width: 50)
                    }
                }
            }
            .navigationTitle("Quick Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createReminder()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createReminder() {
        let reminder = WeatherReminder(
            title: title,
            reminderDescription: "",
            category: selectedCategory
        )
        
        // Create trigger condition
        let condition = TriggerCondition(
            triggerType: .exactTemperature,
            targetTemperature: targetTemperature,
            comparisonType: comparisonType
        )
        
        reminder.triggerCondition = condition
        
        modelContext.insert(reminder)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error
        }
    }
}

#Preview {
    QuickCreateReminderView()
        .modelContainer(for: [WeatherReminder.self, TriggerCondition.self], inMemory: true)
}