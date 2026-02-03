//
//  FirstReminderCreationComponents.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

// MARK: - Activity Selector

struct ActivitySelector: View {
    @Binding var selectedActivity: ReminderActivity
    @Binding var customActivity: String
    
    @State private var showCustomInput = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Predefined activities
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ReminderActivity.allCases.filter { $0 != .custom }, id: \.self) { activity in
                    ActivityButton(
                        activity: activity,
                        isSelected: selectedActivity == activity
                    ) {
                        selectedActivity = activity
                        showCustomInput = false
                    }
                }
            }
            
            // Custom activity option
            VStack(spacing: 12) {
                Button(action: {
                    selectedActivity = .custom
                    showCustomInput = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.body)
                        
                        Text("Custom Activity")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedActivity == .custom ? .white : .blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedActivity == .custom ? Color.blue : Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if showCustomInput {
                    TextField("Enter activity name", text: $customActivity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onChange(of: selectedActivity) { _, newActivity in
            if newActivity != .custom {
                showCustomInput = false
            }
        }
    }
}

struct ActivityButton: View {
    let activity: ReminderActivity
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: activity.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : activity.color)
                
                Text(activity.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? activity.color : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(activity.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Weather Condition Builder

struct WeatherConditionBuilder: View {
    @Binding var condition: WeatherConditionType
    @Binding var minTemp: Double
    @Binding var maxTemp: Double
    
    var body: some View {
        VStack(spacing: 20) {
            // Condition type selector
            VStack(spacing: 12) {
                HStack {
                    Text("Condition Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(WeatherConditionType.allCases, id: \.self) { conditionType in
                        ConditionTypeButton(
                            conditionType: conditionType,
                            isSelected: condition == conditionType
                        ) {
                            condition = conditionType
                        }
                    }
                }
            }
            
            // Temperature range (if applicable)
            if condition == .temperatureRange || condition == .exactTemperature {
                VStack(spacing: 16) {
                    HStack {
                        Text("Temperature")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(minTemp))° - \(Int(maxTemp))°F")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    if condition == .temperatureRange {
                        TemperatureRangeSlider(
                            minTemp: $minTemp,
                            maxTemp: $maxTemp
                        )
                    } else {
                        SingleTemperatureSlider(
                            temperature: $minTemp
                        )
                    }
                }
            }
        }
    }
}

struct ConditionTypeButton: View {
    let conditionType: WeatherConditionType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: conditionType.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(conditionType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(conditionType.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TemperatureRangeSlider: View {
    @Binding var minTemp: Double
    @Binding var maxTemp: Double
    
    @State private var tempRange: ClosedRange<Double> = 65...75
    
    var body: some View {
        VStack(spacing: 12) {
            RangeSlider(
                range: $tempRange,
                bounds: 32...100,
                step: 1
            )
            .onChange(of: tempRange) { _, newRange in
                minTemp = newRange.lowerBound
                maxTemp = newRange.upperBound
            }
            .onAppear {
                tempRange = minTemp...maxTemp
            }
            
            HStack {
                Text("32°F")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("100°F")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SingleTemperatureSlider: View {
    @Binding var temperature: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("32°F")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(temperature))°F")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("100°F")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $temperature, in: 32...100, step: 1)
                .accentColor(Color.accentColor)
        }
    }
}

// MARK: - Range Slider Component

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    
    @State private var lowerThumbLocation: CGFloat = 0
    @State private var upperThumbLocation: CGFloat = 1
    @State private var lastLowerThumbLocation: CGFloat = 0
    @State private var lastUpperThumbLocation: CGFloat = 1
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - 44 // Account for thumb width
            
            ZStack(alignment: .leading) {
                // Track background
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 4)
                    .cornerRadius(2)
                    .offset(x: 22) // Center the track
                
                // Active range
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: (upperThumbLocation - lowerThumbLocation) * trackWidth, height: 4)
                    .cornerRadius(2)
                    .offset(x: 22 + lowerThumbLocation * trackWidth)
                
                // Lower thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                    .offset(x: lowerThumbLocation * trackWidth)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newLocation = max(0, min(upperThumbLocation, value.location.x / trackWidth))
                                lowerThumbLocation = newLocation
                                updateRange(trackWidth: trackWidth)
                            }
                    )
                
                // Upper thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                    .offset(x: upperThumbLocation * trackWidth + 22)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newLocation = max(lowerThumbLocation, min(1, (value.location.x - 22) / trackWidth))
                                upperThumbLocation = newLocation
                                updateRange(trackWidth: trackWidth)
                            }
                    )
            }
        }
        .frame(height: 44)
        .onAppear {
            updateThumbLocations()
        }
        .onChange(of: range) { _, _ in
            updateThumbLocations()
        }
    }
    
    private func updateThumbLocations() {
        let normalizedLower = (range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        let normalizedUpper = (range.upperBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        
        lowerThumbLocation = normalizedLower
        upperThumbLocation = normalizedUpper
    }
    
    private func updateRange(trackWidth: CGFloat) {
        let lowerValue = bounds.lowerBound + lowerThumbLocation * (bounds.upperBound - bounds.lowerBound)
        let upperValue = bounds.lowerBound + upperThumbLocation * (bounds.upperBound - bounds.lowerBound)
        
        let steppedLower = round(lowerValue / step) * step
        let steppedUpper = round(upperValue / step) * step
        
        range = steppedLower...steppedUpper
    }
}

// MARK: - Time Preferences Builder

struct TimePreferencesBuilder: View {
    @Binding var timeRange: TimeRange
    @Binding var quietHours: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Time range selector
            VStack(spacing: 12) {
                HStack {
                    Text("Preferred Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(TimeRange.allCases, id: \.self) { timeRangeOption in
                        TimeRangeButton(
                            timeRange: timeRangeOption,
                            isSelected: timeRange == timeRangeOption
                        ) {
                            timeRange = timeRangeOption
                        }
                    }
                }
            }
            
            // Quiet hours toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Respect Quiet Hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Avoid notifications during sleep hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $quietHours)
                    .labelsHidden()
            }
        }
    }
}

struct TimeRangeButton: View {
    let timeRange: TimeRange
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: timeRange.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .orange)
                
                Text(timeRange.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(timeRange.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Live Preview Card

struct LivePreviewCard: View {
    let reminder: CustomReminder
    
    @State private var isVisible = false
    @State private var pulseAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Image(systemName: "eye.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Text("Live Preview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Spacer()
                
                // Real-time indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(pulseAnimation ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text("LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Mock notification preview
            HStack(spacing: 12) {
                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "cloud.sun.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("SunHat")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("now")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(reminder.previewTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(reminder.previewBody)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isVisible = true
                }
                
                // Start pulse animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    pulseAnimation = true
                }
            } else {
                isVisible = true
                pulseAnimation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live preview: \(reminder.previewTitle). \(reminder.previewBody)")
    }
}

// MARK: - Reminder Preview Card

struct ReminderPreviewCard: View {
    let reminder: CustomReminder
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 20) {
            // Activity icon and title
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(reminder.activity.color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: reminder.activity.icon)
                        .font(.title2)
                        .foregroundColor(reminder.activity.color)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.displayTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(reminder.activityDisplayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Conditions
            VStack(spacing: 12) {
                ConditionRow(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: reminder.temperatureDescription,
                    color: .blue
                )
                
                ConditionRow(
                    icon: "clock",
                    title: "Time",
                    value: reminder.preferredTimeRange.displayName,
                    color: .orange
                )
                
                if reminder.respectQuietHours {
                    ConditionRow(
                        icon: "moon.zzz",
                        title: "Quiet Hours",
                        value: "Respected",
                        color: .purple
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

struct ConditionRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Forecast Likelihood View

struct ForecastLikelihoodView: View {
    let likelihood: TriggerLikelihood
    let forecast: [WeatherForecastDay]
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("7-Day Forecast")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text("Based on current weather forecast")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Enhanced likelihood summary with animation
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger Likelihood")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(likelihood.description)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(likelihood.color)
                    
                    // Next likely trigger
                    if let nextTriggerDay = likelihood.triggerDays.first {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            
                            Text("Next: \(nextTriggerDay, style: .date)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    CircularProgressView(
                        progress: likelihood.percentage / 100,
                        color: likelihood.color
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(likelihood.triggerDays.count) of 7 days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Forecast days
            VStack(spacing: 8) {
                ForEach(forecast.prefix(7), id: \.date) { day in
                    ForecastDayRow(
                        day: day,
                        willTrigger: likelihood.triggerDays.contains(day.date)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.6).delay(animationDelay)) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

struct ForecastDayRow: View {
    let day: WeatherForecastDay
    let willTrigger: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(day.dayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(day.shortDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)
            
            // Weather icon
            Image(systemName: day.weatherIcon)
                .font(.caption)
                .foregroundColor(day.weatherColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            
            // Temperature
            Text("\(day.highTemp)°")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 30, alignment: .trailing)
            
            Spacer()
            
            // Trigger indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(willTrigger ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Text(willTrigger ? "Will trigger" : "No trigger")
                    .font(.caption2)
                    .foregroundColor(willTrigger ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ActivitySelector(
            selectedActivity: .constant(.walking),
            customActivity: .constant("")
        )
        
        WeatherConditionBuilder(
            condition: .constant(.temperatureRange),
            minTemp: .constant(65),
            maxTemp: .constant(75)
        )
    }
    .padding()
}
