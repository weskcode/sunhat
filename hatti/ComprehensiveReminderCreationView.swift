//
//  ComprehensiveReminderCreationView.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct ComprehensiveReminderCreationView: View {
    @StateObject private var viewModel = ComprehensiveReminderCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var showingLocationPicker = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isNaturalLanguageFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    backgroundGradient
                        .ignoresSafeArea()
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                                // Header section
                                headerSection
                                    .padding(.top, 8)
                                
                                // Natural language input section
                                naturalLanguageSection
                                    .id("naturalLanguage")
                                
                                // Smart suggestions (if available)
                                if !viewModel.smartSuggestions.isEmpty {
                                    smartSuggestionsSection
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                                
                                // Temperature trigger builder
                                temperatureTriggerSection
                                
                                // Condition type selector
                                conditionTypeSection
                                
                                // Location picker
                                locationPickerSection
                                
                                // Activity category selection
                                activityCategorySection
                                
                                // Notification timing options
                                notificationTimingSection
                                
                                // Preview section
                                if viewModel.isValidForPreview {
                                    previewSection
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                
                                // Save/Cancel actions
                                actionButtonsSection
                                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                            }
                            .padding(.horizontal, 16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: isNaturalLanguageFieldFocused) { _, focused in
                            if focused {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("naturalLanguage", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReminder()
                    }
                    .disabled(!viewModel.isValidForSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $viewModel.selectedLocation)
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadUserHistory()
                viewModel.loadCurrentLocation()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Smart Weather Reminder")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text("Create intelligent reminders based on weather conditions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Natural Language Input Section
    
    private var naturalLanguageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                icon: "text.bubble",
                title: "What would you like to be reminded about?",
                subtitle: "Describe your reminder in natural language"
            )
            
            VStack(spacing: 8) {
                TextField("Remind me when...", text: $viewModel.naturalLanguageInput, axis: .vertical)
                    .textFieldStyle(NaturalLanguageTextFieldStyle())
                    .focused($isNaturalLanguageFieldFocused)
                    .onChange(of: viewModel.naturalLanguageInput) { _, newValue in
                        viewModel.processNaturalLanguage(newValue)
                    }
                
                // AI-powered parsing indicator
                if viewModel.isProcessingLanguage {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Understanding your request...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .transition(.opacity)
                }
                
                // Parsed information display
                if let parsedInfo = viewModel.parsedLanguageInfo {
                    ParsedInfoView(info: parsedInfo) {
                        viewModel.applyParsedInfo(parsedInfo)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessingLanguage)
            .animation(.easeInOut(duration: 0.3), value: viewModel.parsedLanguageInfo != nil)
        }
        .sectionCardStyle()
    }
    
    // MARK: - Smart Suggestions Section
    
    private var smartSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                icon: "lightbulb",
                title: "Smart Suggestions",
                subtitle: "Based on your activity history"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.smartSuggestions, id: \.id) { suggestion in
                    SmartSuggestionCard(suggestion: suggestion) {
                        viewModel.applySuggestion(suggestion)
                    }
                }
            }
        }
        .sectionCardStyle()
    }
    
    // MARK: - Temperature Trigger Section
    
    private var temperatureTriggerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "thermometer.medium",
                title: "Temperature Trigger",
                subtitle: "Set the ideal temperature conditions"
            )
            
            VStack(spacing: 20) {
                // Visual temperature slider
                VisualTemperatureSlider(
                    value: $viewModel.targetTemperature,
                    range: $viewModel.temperatureRange,
                    conditionType: viewModel.conditionType,
                    temperatureUnit: viewModel.temperatureUnit
                )
                
                // Temperature display with feels like option
                VStack(spacing: 12) {
                    HStack {
                        Text("Target Temperature")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.displayTemperature))°\(viewModel.temperatureUnit.symbol.dropFirst())")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Toggle("Use 'feels like' temperature", isOn: $viewModel.useFeelsLike)
                        .font(.caption)
                }
            }
        }
        .sectionCardStyle()
    }
    
    // MARK: - Condition Type Section
    
    private var conditionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                icon: "slider.horizontal.3",
                title: "Condition Type",
                subtitle: "How should the temperature be evaluated?"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ConditionType.allCases, id: \.self) { type in
                    ConditionTypeCard(
                        type: type,
                        isSelected: viewModel.conditionType == type
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.conditionType = type
                        }
                    }
                }
            }
            
            // Additional condition parameters
            if viewModel.conditionType == .trend {
                TrendConditionParameters(
                    trendType: $viewModel.trendType,
                    trendDuration: $viewModel.trendDuration
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if viewModel.conditionType == .seasonal {
                SeasonalConditionParameters(
                    seasonalType: $viewModel.seasonalType,
                    historicalComparison: $viewModel.historicalComparison
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sectionCardStyle()
        .animation(.easeInOut(duration: 0.3), value: viewModel.conditionType)
    }
    
    // MARK: - Location Picker Section
    
    private var locationPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                icon: "location",
                title: "Location",
                subtitle: "Where should we monitor the weather?"
            )
            
            Button(action: {
                showingLocationPicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.selectedLocation.isCurrentLocation ? "location.fill" : "mappin.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedLocation.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let address = viewModel.selectedLocation.fullAddress {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sectionCardStyle()
    }
    
    // MARK: - Activity Category Section
    
    private var activityCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                icon: "heart",
                title: "Activity Category",
                subtitle: "What type of activity is this reminder for?"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    ActivityCategoryCard(
                        category: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
        }
        .sectionCardStyle()
    }
    
    // MARK: - Notification Timing Section
    
    private var notificationTimingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                icon: "bell.badge",
                title: "Notification Timing",
                subtitle: "When should we notify you?"
            )
            
            VStack(spacing: 12) {
                ForEach(NotificationTiming.allCases, id: \.self) { timing in
                    NotificationTimingRow(
                        timing: timing,
                        isSelected: viewModel.notificationTiming == timing
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.notificationTiming = timing
                        }
                    }
                }
            }
        }
        .sectionCardStyle()
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                icon: "eye",
                title: "Preview",
                subtitle: "How likely is this reminder to trigger?"
            )
            
            VStack(spacing: 16) {
                // Trigger likelihood display
                TriggerLikelihoodView(
                    likelihood: viewModel.triggerLikelihood,
                    nextTriggerDate: viewModel.nextPossibleTriggerDate
                )
                
                // 7-day forecast preview
                if !viewModel.forecastData.isEmpty {
                    ForecastPreviewView(
                        forecast: viewModel.forecastData,
                        triggerCondition: viewModel.buildTriggerCondition()
                    )
                }
                
                // Example notification
                ExampleNotificationView(
                    title: viewModel.generatedTitle,
                    message: viewModel.generatedMessage,
                    timing: viewModel.notificationTiming
                )
            }
        }
        .sectionCardStyle()
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary save button
            Button(action: {
                saveReminder()
            }) {
                HStack(spacing: 10) {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.9)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    
                    Text(viewModel.isSaving ? "Creating..." : "Create Reminder")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: viewModel.isValidForSave ? 
                            [Color.blue, Color.purple] : 
                            [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: viewModel.isValidForSave ? .blue.opacity(0.3) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isValidForSave || viewModel.isSaving)
            
            // Form validation errors
            if let validationError = viewModel.validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.validationError)
    }
    
    // MARK: - Helper Methods
    
    private func saveReminder() {
        Task {
            let success = await viewModel.saveReminder()
            if success {
                dismiss()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color.black,
                Color.blue.opacity(0.02),
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

struct SectionHeaderView: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct NaturalLanguageTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - View Modifier

extension View {
    func sectionCardStyle() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
}

// MARK: - Preview

#Preview {
    ComprehensiveReminderCreationView()
        .modelContainer(for: [
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            UserPreferences.self
        ], inMemory: true)
}