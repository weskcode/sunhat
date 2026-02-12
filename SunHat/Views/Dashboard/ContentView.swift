//
//  ContentView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if onboardingCoordinator.hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(onboardingCoordinator)
                } else {
                    OnboardingContainerView()
                        .environmentObject(onboardingCoordinator)
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - Legacy Content View (for reference/backup)

struct LegacyContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeatherReminder.createdDate, order: .reverse) private var reminders: [WeatherReminder]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(reminders) { reminder in
                    NavigationLink {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(reminder.displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if !reminder.reminderDescription.isEmpty {
                                Text(reminder.reminderDescription)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: reminder.category.iconName)
                                    .foregroundColor(.blue)
                                Text(reminder.category.displayName)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text(reminder.statusText)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(reminder.isCurrentlyActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            if let condition = reminder.triggerCondition {
                                HStack {
                                    Image(systemName: "thermometer")
                                        .foregroundColor(.orange)
                                    Text("When temperature is \(condition.comparisonType.rawValue) \(condition.targetTemperature, specifier: "%.1f")°")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text("Created: \(reminder.createdDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(Color(.tertiaryLabel))
                            
                            Spacer()
                        }
                        .padding()
                        .navigationTitle("Reminder Details")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: reminder.category.iconName)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                
                                Text(reminder.displayTitle)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if reminder.isCurrentlyActive {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                } else {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Text(reminder.shortDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            if let condition = reminder.triggerCondition {
                                Text("\(condition.targetTemperature, specifier: "%.0f")° \(condition.comparisonType.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: deleteReminders)
            }
            .navigationTitle("Weather Reminders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addReminder) {
                        Label("Add Reminder", systemImage: "plus")
                    }
                }
            }
        } detail: {
            VStack {
                Image(systemName: "thermometer.sun")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding()
                
                Text("Select a Weather Reminder")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Create temperature-triggered reminders for your outdoor activities, gardening, and more.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private func addReminder() {
        withAnimation {
            let newReminder = WeatherReminder(
                title: "New Weather Reminder",
                reminderDescription: "Remind me when the weather is right",
                category: .general
            )
            modelContext.insert(newReminder)
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
    ContentView()
        .modelContainer(for: WeatherReminder.self, inMemory: true)
}
