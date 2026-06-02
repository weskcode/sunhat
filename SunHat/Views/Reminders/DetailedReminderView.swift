//
//  DetailedReminderView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import MapKit

struct DetailedReminderView: View {
    let reminder: WeatherReminder
    @StateObject private var viewModel: DetailedReminderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isEditMode = false
    @State private var showingDeleteConfirmation = false
    @State private var activeSheet: ActiveSheet?
    @State private var editedReminder: EditableReminder

    private enum ActiveSheet: Identifiable {
        case share
        case duplicate

        var id: Self { self }
    }
    
    // Animation states
    @State private var headerOffset: CGFloat = 0
    @State private var isAnimatingTransition = false
    
    init(reminder: WeatherReminder) {
        self.reminder = reminder
        self._viewModel = StateObject(wrappedValue: DetailedReminderViewModel(reminder: reminder))
        self._editedReminder = State(initialValue: EditableReminder(from: reminder))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()

                // Scroll view content
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            // Large weather condition display
                            weatherConditionHeader
                                .id("header")

                            // Main content
                            VStack(spacing: 24) {
                                // Live prediction section
                                if !isEditMode {
                                    livePredictionSection
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)
                                        ))
                                }

                                // Trigger conditions section
                                triggerConditionsSection

                                // Notification settings section
                                notificationSettingsSection

                                // Location settings section
                                locationSettingsSection

                                // History timeline section
                                if !isEditMode && !viewModel.triggerHistory.isEmpty {
                                    triggerHistorySection
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)
                                        ))
                                }

                                // Action buttons section
                                actionButtonsSection
                                    .padding(.bottom, 40)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }
                    .scrollTargetLayout()
                    .coordinateSpace(name: "scroll")
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            proxy.scrollTo("header", anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .animation(.smooth(duration: 0.5), value: isEditMode)
        .overlay(alignment: .topLeading) {
            // Custom navigation bar
            customNavigationBar
        }
        .confirmationDialog("Delete Reminder", isPresented: $showingDeleteConfirmation) {
            deleteConfirmationDialogButtons()
        } message: {
            Text("This action cannot be undone. The reminder and all its history will be permanently deleted.")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .share:
                ShareReminderView(reminder: reminder)
            case .duplicate:
                DuplicateReminderView(reminder: reminder)
            }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.loadTriggerHistory()
            viewModel.startLivePrediction()
        }
        .onDisappear {
            viewModel.stopLivePrediction()
        }
    }
    
    // MARK: - Custom Navigation Bar
    
    private var customNavigationBar: some View {
        HStack {
            // Back button
            Button(action: {
                if isEditMode {
                    cancelEditing()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isEditMode ? "xmark" : "chevron.left")
                        .font(AppFontStyle.title3.font)
                        .fontWeight(.medium)
                    
                    if !isEditMode {
                        Text("Back")
                            .font(.body)
                    }
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                if isEditMode {
                    // Save button
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(editedReminder.isValid ? Color.blue : Color.gray)
                    .clipShape(Capsule())
                    .disabled(!editedReminder.isValid)
                } else {
                    // Edit button
                    Button(action: {
                        enterEditMode()
                    }) {
                        Image(systemName: "pencil")
                            .font(AppFontStyle.title3.font)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // More options menu
                    Menu {
                        moreOptionsMenu
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(AppFontStyle.title3.font)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .zIndex(100)
    }
    
    // MARK: - Weather Condition Header
    
    private var weatherConditionHeader: some View {
        VStack(spacing: 0) {
            // Current weather display
            if let currentWeather = viewModel.currentWeatherData {
                VStack(spacing: 16) {
                    // Weather icon and temperature
                    HStack(spacing: 20) {
                        // Weather icon
                        Image(systemName: currentWeather.weatherCondition.icon)
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Int(currentWeather.temperature))°")
                                .font(.system(size: 48, weight: .thin, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Feels like \(Int(currentWeather.feelsLike))°")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Condition match indicator
                    ConditionMatchIndicator(
                        reminder: reminder,
                        currentWeather: currentWeather,
                        isEditMode: isEditMode
                    )
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
            } else {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Loading current weather...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: reminder.category.iconName)
                        .font(AppFontStyle.title3.font)
                        .foregroundColor(.blue)
                    
                    if isEditMode {
                        TextField("Reminder title", text: $editedReminder.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else {
                        Text(reminder.displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                
                if isEditMode {
                    TextField("Description (optional)", text: $editedReminder.description, axis: .vertical)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(3)
                } else if !reminder.reminderDescription.isEmpty {
                    Text(reminder.reminderDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.top, 80)
    }
    
    // MARK: - Live Prediction Section
    
    private var livePredictionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "crystal.ball",
                title: "Live Prediction",
                subtitle: "Next trigger forecast"
            )
            
            if let prediction = viewModel.livePrediction {
                LivePredictionCard(prediction: prediction)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Calculating prediction...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Trigger Conditions Section
    
    private var triggerConditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "slider.horizontal.3",
                title: "Trigger Conditions",
                subtitle: isEditMode ? "Tap to edit conditions" : "When this reminder activates"
            )
            
            if isEditMode {
                EditableTriggerConditionsView(
                    condition: $editedReminder.triggerCondition,
                    temperatureUnit: viewModel.temperatureUnit
                )
            } else {
                ReadOnlyTriggerConditionsView(
                    condition: reminder.triggerCondition,
                    temperatureUnit: viewModel.temperatureUnit
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Notification Settings Section
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "bell.badge",
                title: "Notification Settings",
                subtitle: isEditMode ? "Customize notification behavior" : "How you'll be notified"
            )
            
            if isEditMode {
                EditableNotificationSettingsView(
                    config: $editedReminder.notificationConfig
                )
            } else {
                ReadOnlyNotificationSettingsView(
                    config: reminder.notificationConfig
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Location Settings Section
    
    private var locationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "location",
                title: "Location",
                subtitle: isEditMode ? "Where to monitor weather" : "Monitoring location"
            )
            
            if isEditMode {
                EditableLocationView(
                    location: $editedReminder.location,
                    showingLocationPicker: .constant(false)
                )
            } else {
                ReadOnlyLocationView(
                    location: reminder.location
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Trigger History Section
    
    private var triggerHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "clock.arrow.circlepath",
                title: "Trigger History",
                subtitle: "Recent activity timeline"
            )
            
            TriggerHistoryTimeline(
                history: viewModel.triggerHistory,
                isCompact: false
            )
        }
        .cardStyle()
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !isEditMode {
                HStack(spacing: 12) {
                    // Duplicate button
                    Button(action: {
                        activeSheet = .duplicate
                    }) {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Share button
                    Button(action: {
                        activeSheet = .share
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Delete button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Reminder", systemImage: "trash")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - More Options Menu
    
    private var moreOptionsMenu: some View {
        Group {
            Button(action: {
                activeSheet = .duplicate
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            Button(action: {
                activeSheet = .share
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            if reminder.isActive {
                Button(action: {
                    viewModel.pauseReminder()
                }) {
                    Label("Pause", systemImage: "pause.circle")
                }
            } else {
                Button(action: {
                    viewModel.resumeReminder()
                }) {
                    Label("Resume", systemImage: "play.circle")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Delete Confirmation Dialog
    
    private func deleteConfirmationDialogButtons() -> some View {
        Group {
            Button("Delete", role: .destructive) {
                viewModel.deleteReminder()
                dismiss()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Helper Methods
    
    private func enterEditMode() {
        withAnimation(.smooth(duration: 0.5)) {
            isEditMode = true
            isAnimatingTransition = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimatingTransition = false
        }
    }
    
    private func cancelEditing() {
        editedReminder = EditableReminder(from: reminder)
        
        withAnimation(.smooth(duration: 0.5)) {
            isEditMode = false
            isAnimatingTransition = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimatingTransition = false
        }
    }
    
    private func saveChanges() {
        Task {
            let success = await viewModel.saveChanges(editedReminder)
            
            await MainActor.run {
                if success {
                    withAnimation(.smooth(duration: 0.5)) {
                        isEditMode = false
                        isAnimatingTransition = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimatingTransition = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.03),
                Color.black
            ] : [
                Color(red: 0.98, green: 0.99, blue: 1.0),
                Color(red: 0.96, green: 0.98, blue: 1.0),
                Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Supporting Views

struct ConditionMatchIndicator: View {
    let reminder: WeatherReminder
    let currentWeather: WeatherData
    let isEditMode: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(matchColor)
                .frame(width: 12, height: 12)
            
            Text(matchText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(matchColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(matchColor.opacity(0.1))
        )
        .scaleEffect(isEditMode ? 0.0 : 1.0)
        .opacity(isEditMode ? 0.0 : 1.0)
        .animation(.smooth(duration: 0.3), value: isEditMode)
    }
    
    private var matchColor: Color {
        guard let condition = reminder.triggerCondition else { return .gray }
        
        let matches = currentWeather.evaluateCondition(condition)
        return matches ? .green : .orange
    }
    
    private var matchText: String {
        guard let condition = reminder.triggerCondition else { return "No condition set" }
        
        let matches = currentWeather.evaluateCondition(condition)
        return matches ? "Conditions met!" : "Waiting for conditions"
    }
}

// MARK: - View Modifier

extension View {
    func cardStyle() -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
}

// MARK: - Preview

#Preview {
    let reminder = WeatherReminder(
        title: "Morning Walk",
        reminderDescription: "Perfect weather for a refreshing morning walk",
        category: .exercise
    )
    
    return DetailedReminderView(reminder: reminder)
        .modelContainer(for: [
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ReminderHistory.self,
            NotificationConfig.self
        ], inMemory: true)
}
