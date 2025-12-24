//
//  ReminderManagementComponents.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

// MARK: - Reminder Management Row

struct ReminderManagementRow: View {
    let reminder: WeatherReminder
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: () -> Void
    let onToggleActive: (Bool) -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            if isSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Category icon
            Image(systemName: reminder.category.iconName)
                .font(.title3)
                .foregroundColor(reminder.category == .general ? .blue : reminderStatusColor)
                .frame(width: 24)
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Title and status
                HStack {
                    Text(reminder.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(reminderStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(reminder.statusText)
                            .font(.caption2)
                            .foregroundColor(reminderStatusColor)
                    }
                }
                
                // Description or trigger condition
                Text(reminderDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Additional info row
                HStack {
                    if let condition = reminder.triggerCondition {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Text("\(Int(condition.targetTemperature))° \(condition.comparisonType.rawValue)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Last triggered or created date
                    Text(dateDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Toggle switch for active reminders (not in selection mode)
            if !isSelectionMode && reminder.canTrigger {
                Toggle("", isOn: .init(
                    get: { reminder.isActive },
                    set: { @Sendable newValue in onToggleActive(newValue) }
                ))
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            } else {
                showingDetails = true
            }
        }
        .sheet(isPresented: $showingDetails) {
            ReminderDetailView(reminder: reminder)
        }
    }
    
    private var reminderStatusColor: Color {
        if reminder.isCompleted {
            return .green
        } else if !reminder.isActive {
            return .gray
        } else if reminder.isPaused {
            return .orange
        } else if let snoozedUntil = reminder.snoozedUntil, snoozedUntil > Date() {
            return .blue
        } else {
            return .green
        }
    }
    
    private var reminderDescription: String {
        if !reminder.reminderDescription.isEmpty {
            return reminder.reminderDescription
        } else if let condition = reminder.triggerCondition {
            return "When temperature is \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°"
        } else {
            return "Weather reminder"
        }
    }
    
    private var dateDescription: String {
        if let lastTriggered = reminder.lastTriggered {
            return "Triggered \(relativeDateFormatter.localizedString(for: lastTriggered, relativeTo: Date()))"
        } else {
            return "Created \(relativeDateFormatter.localizedString(for: reminder.createdDate, relativeTo: Date()))"
        }
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}

// MARK: - Sort Options View

struct SortOptionsView: View {
    @Binding var selectedSort: SortOption
    @Binding var selectedOrder: SortOrder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sort By") {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(option.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSort = option
                        }
                    }
                }
                
                Section("Order") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        HStack {
                            Image(systemName: order.icon)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(order.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if selectedOrder == order {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOrder = order
                        }
                    }
                }
            }
            .navigationTitle("Sort Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Options View

struct FilterOptionsView: View {
    @Binding var selectedCategories: Set<ReminderCategory>
    @Binding var selectedStatuses: Set<ReminderStatus>
    @Binding var temperatureRange: ClosedRange<Double>
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempRange = 0.0...100.0
    
    var body: some View {
        NavigationView {
            Form {
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
                
                Section("Status") {
                    ForEach(ReminderStatus.allCases, id: \.self) { status in
                        HStack {
                            Image(systemName: status.icon)
                                .foregroundColor(status.color)
                                .frame(width: 20)
                            
                            Text(status.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if selectedStatuses.contains(status) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleStatus(status)
                        }
                    }
                }
                
                Section("Temperature Range") {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Temperature")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(Int(tempRange.lowerBound))° - \(Int(tempRange.upperBound))°F")
                                .font(.subheadline)
                                .foregroundColor(.blue)
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
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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

// MARK: - Filter Category Button

struct FilterCategoryButton: View {
    let category: ReminderCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : categoryColor)
                
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
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
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Reminder Detail View

struct ReminderDetailView: View {
    let reminder: WeatherReminder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: reminder.category.iconName)
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text(reminder.category.displayName)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Text(reminder.displayTitle)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if !reminder.reminderDescription.isEmpty {
                            Text(reminder.reminderDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Status section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(reminder.isCurrentlyActive ? Color.green : Color.gray)
                                .frame(width: 12, height: 12)
                            
                            Text(reminder.statusText)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Trigger condition section
                    if let condition = reminder.triggerCondition {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trigger Condition")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "thermometer")
                                        .foregroundColor(.orange)
                                    Text("Temperature: \(condition.comparisonType.rawValue) \(Int(condition.targetTemperature))°F")
                                        .font(.subheadline)
                                }
                                
                                if condition.useFeelsLike {
                                    Text("Uses 'feels like' temperature")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Statistics section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Statistics")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            StatCard(title: "Times Triggered", value: "\(reminder.triggerCount)")
                            StatCard(title: "Completed", value: "\(reminder.successfulCompletions)")
                            StatCard(title: "Skipped", value: "\(reminder.skippedCount)")
                            StatCard(title: "Notifications", value: "\(reminder.totalNotificationsSent)")
                        }
                    }
                    
                    // Dates section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timeline")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            DateRow(label: "Created", date: reminder.createdDate)
                            DateRow(label: "Last Modified", date: reminder.lastModified)
                            
                            if let lastTriggered = reminder.lastTriggered {
                                DateRow(label: "Last Triggered", date: lastTriggered)
                            }
                            
                            if let completedDate = reminder.completedDate {
                                DateRow(label: "Completed", date: completedDate)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reminder Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct DateRow: View {
    let label: String
    let date: Date
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(date, format: .dateTime.weekday().month().day().hour().minute())
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    ReminderManagementView()
        .modelContainer(for: [
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            ReminderHistory.self,
            NotificationConfig.self
        ], inMemory: true)
}
