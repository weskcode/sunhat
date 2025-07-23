//
//  NotificationPreferencesView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NotificationPreferencesViewModel()
    
    @State private var showingResetAlert = false
    @State private var showingSoundPicker = false
    @State private var selectedReminderType: String = "general"
    
    var body: some View {
        NavigationView {
            Form {
                // Quiet Hours Section
                quietHoursSection
                
                // Notification Organization Section
                notificationOrganizationSection
                
                // Sound and Vibration Section
                soundAndVibrationSection
                
                // Lock Screen Behavior Section
                lockScreenBehaviorSection
                
                // Critical Alerts Section
                criticalAlertsSection
                
                // Preview Examples Section
                previewExamplesSection
                
                // Reset Section
                resetSection
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveSettings()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all notification preferences to their default values. This action cannot be undone.")
            }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(
                    selectedSound: viewModel.selectedSoundForType(selectedReminderType),
                    reminderType: selectedReminderType
                ) { sound in
                    viewModel.setSound(sound, for: selectedReminderType)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        Section {
            Toggle("Enable Quiet Hours", isOn: $viewModel.quietHoursEnabled)
                .foregroundColor(.primary)
            
            if viewModel.quietHoursEnabled {
                HStack {
                    Text("Start Time")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: $viewModel.quietHoursStart,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                
                HStack {
                    Text("End Time")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: $viewModel.quietHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Period")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.quietHoursDescription)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        } header: {
            Label("Quiet Hours", systemImage: "moon.fill")
        } footer: {
            Text("Notifications will be silenced during quiet hours unless marked as critical alerts.")
        }
    }
    
    // MARK: - Notification Organization Section
    
    private var notificationOrganizationSection: some View {
        Section {
            Picker("Grouping", selection: $viewModel.notificationGrouping) {
                SwiftUI.ForEach(NotificationGrouping.allCases, id: \.self) { grouping in
                    VStack(alignment: .leading) {
                        Text(grouping.displayName)
                            .font(.body)
                        Text(grouping.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(grouping)
                }
            }
            .pickerStyle(.navigationLink)
            
            HStack {
                Text("Maximum Daily Notifications")
                
                Spacer()
                
                Stepper(
                    "\(viewModel.maximumDailyNotifications)",
                    value: $viewModel.maximumDailyNotifications,
                    in: 1...50
                )
            }
            
            Toggle("Allow Weekend Notifications", isOn: $viewModel.allowWeekendNotifications)
        } header: {
            Label("Organization", systemImage: "folder.fill")
        } footer: {
            Text("Control how notifications are grouped and delivered throughout the day.")
        }
    }
    
    // MARK: - Sound and Vibration Section
    
    private var soundAndVibrationSection: some View {
        Section {
            // Vibration Pattern
            Picker("Vibration Pattern", selection: $viewModel.vibrationPattern) {
                SwiftUI.ForEach(VibrationPattern.allCases, id: \.self) { pattern in
                    HStack {
                        Image(systemName: pattern.icon)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pattern.displayName)
                                .font(.body)
                            Text(pattern.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(pattern)
                }
            }
            .pickerStyle(.navigationLink)
            
            // Sound Settings per Reminder Type
            Group {
                SwiftUI.ForEach(["general", "exercise", "gardening", "maintenance"], id: \.self) { type in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(type.capitalized)
                                .font(.body)
                            Text("Sound for \(type) reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(viewModel.selectedSoundForType(type).displayName) {
                            selectedReminderType = type
                            showingSoundPicker = true
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
        } header: {
            Label("Sound & Vibration", systemImage: "speaker.wave.2.fill")
        } footer: {
            Text("Customize notification sounds for different types of reminders and set vibration patterns.")
        }
    }
    
    // MARK: - Lock Screen Behavior Section
    
    private var lockScreenBehaviorSection: some View {
        Section {
            Picker("Lock Screen Behavior", selection: $viewModel.lockScreenBehavior) {
                SwiftUI.ForEach(LockScreenBehavior.allCases, id: \.self) { behavior in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: behavior.icon)
                                .foregroundColor(.blue)
                            Text(behavior.displayName)
                                .font(.body)
                        }
                        Text(behavior.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(behavior)
                }
            }
            .pickerStyle(.navigationLink)
            
        } header: {
            Label("Lock Screen", systemImage: "lock.fill")
        } footer: {
            Text("Control how notification previews appear when your device is locked.")
        }
    }
    
    // MARK: - Critical Alerts Section
    
    private var criticalAlertsSection: some View {
        Section {
            Toggle("Enable Critical Alerts", isOn: $viewModel.criticalAlertsEnabled)
            
            if viewModel.criticalAlertsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Critical Alert Features")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Bypasses Do Not Disturb and Focus modes")
                        Text("• Plays sound even when device is silenced")
                        Text("• Requires special permission from Apple")
                        Text("• Use sparingly for urgent weather conditions")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
        } header: {
            Label("Critical Alerts", systemImage: "exclamationmark.triangle.fill")
        } footer: {
            Text("Critical alerts override system settings and should only be used for severe weather warnings.")
        }
    }
    
    // MARK: - Preview Examples Section
    
    private var previewExamplesSection: some View {
        Section {
            VStack(spacing: 12) {
                NotificationPreviewCard(
                    title: "Perfect Weather Alert",
                    message: "Great conditions for your morning walk! 72°F with light breeze.",
                    time: "9:15 AM",
                    grouping: viewModel.notificationGrouping,
                    lockScreenBehavior: viewModel.lockScreenBehavior
                )
                
                NotificationPreviewCard(
                    title: "Garden Watering Time",
                    message: "Temperature dropped to 68°F - ideal for watering your plants.",
                    time: "6:30 PM",
                    grouping: viewModel.notificationGrouping,
                    lockScreenBehavior: viewModel.lockScreenBehavior
                )
            }
            .padding(.vertical, 4)
        } header: {
            Label("Preview", systemImage: "eye.fill")
        } footer: {
            Text("Examples of how your notifications will appear with current settings.")
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        Section {
            Button("Reset to Defaults") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .center)
        } footer: {
            Text("This will reset all notification preferences to their original default values.")
        }
    }
}

// MARK: - Notification Preview Card

struct NotificationPreviewCard: View {
    let title: String
    let message: String
    let time: String
    let grouping: NotificationGrouping
    let lockScreenBehavior: LockScreenBehavior
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "app.badge.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("TempTrigger")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if lockScreenBehavior != .hideDetails {
                    Text(lockScreenBehavior == .showPreviews ? message : "Notification content hidden")
                        .font(.caption)
                        .foregroundColor(lockScreenBehavior == .showPreviews ? .secondary : Color(.tertiaryLabel))
                        .lineLimit(2)
                }
            }
            
            if grouping != .none {
                HStack {
                    Image(systemName: grouping.icon)
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text("Grouped with similar \(grouping.displayName.lowercased())")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Sound Picker View

struct SoundPickerView: View {
    let selectedSound: NotificationSound
    let reminderType: String
    let onSoundSelected: (NotificationSound) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var playingSound: NotificationSound?
    
    var body: some View {
        NavigationView {
            List {
                SwiftUI.ForEach(NotificationSound.allCases, id: \.self) { sound in
                    HStack {
                        Image(systemName: sound.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sound.displayName)
                                .font(.body)
                            
                            if sound == .none {
                                Text("No sound")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if sound == .default {
                                Text("System default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if sound != .none && sound != .default {
                            Button(action: {
                                playSound(sound)
                            }) {
                                Image(systemName: playingSound == sound ? "stop.circle.fill" : "play.circle")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if selectedSound == sound {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSoundSelected(sound)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Select Sound")
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
    
    private func playSound(_ sound: NotificationSound) {
        if playingSound == sound {
            // Stop playing
            playingSound = nil
            AudioServicesDisposeSystemSoundID(1000)
        } else {
            // Start playing
            playingSound = sound
            if sound.fileName != nil {
                // Play custom sound file
                AudioServicesPlaySystemSound(1007) // Placeholder system sound
            } else {
                AudioServicesPlaySystemSound(1007) // Default notification sound
            }
            
            // Auto-stop after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if playingSound == sound {
                    playingSound = nil
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationPreferencesView()
        .modelContainer(for: [UserPreferences.self], inMemory: true)
}