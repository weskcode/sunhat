//
//  ComparisonCard.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct ComparisonCard: View {
    let example: ComparisonExample
    let index: Int
    
    @State private var isHovered = false
    @State private var showWeatherAdvantage = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            // Card title
            Text(example.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            // Comparison container
            HStack(spacing: 12) {
                // Weather-based reminder (left side)
                weatherBasedCard
                    .frame(maxWidth: .infinity)
                
                // VS divider
                dividerView
                
                // Time-based reminder (right side)
                timeBasedCard
                    .frame(maxWidth: .infinity)
            }
            
            // Advantage callout
            if showWeatherAdvantage {
                advantageCallout
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
            radius: 12,
            x: 0,
            y: 4
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                showWeatherAdvantage.toggle()
            }
        }
        .onAppear {
            // Delay showing advantage callout for staggered effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 + Double(index) * 0.3) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showWeatherAdvantage = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(example.title) comparison")
        .accessibilityHint("Shows difference between weather-based and time-based reminders. Tap to toggle advantage explanation.")
        .accessibilityAction(named: "Toggle advantage explanation") {
            withAnimation(.easeInOut(duration: 0.4)) {
                showWeatherAdvantage.toggle()
            }
        }
    }
    
    // MARK: - Weather-Based Card
    
    private var weatherBasedCard: some View {
        VStack(spacing: 12) {
            // Icon with glow effect
            ZStack {
                // Glow background
                Circle()
                    .fill(example.weatherBased.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)
                
                // Icon
                Image(systemName: example.weatherBased.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                example.weatherBased.color,
                                example.weatherBased.color.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(example.weatherBased.color.opacity(0.1))
                    )
            }
            
            // Content
            VStack(spacing: 6) {
                Text("Smart")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(example.weatherBased.color)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(example.weatherBased.condition)
                    .font(dynamicTypeSize.isAccessibilitySize ? .caption : .footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(example.weatherBased.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 140 : 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather-based: \(example.weatherBased.condition), \(example.weatherBased.description)")
    }
    
    // MARK: - Time-Based Card
    
    private var timeBasedCard: some View {
        VStack(spacing: 12) {
            // Icon (less prominent)
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .blur(radius: 4)
                
                Image(systemName: example.timeBased.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.05))
                    )
            }
            
            // Content
            VStack(spacing: 6) {
                Text("Traditional")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(example.timeBased.time)
                    .font(dynamicTypeSize.isAccessibilitySize ? .caption : .footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(example.timeBased.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 140 : 120)
        .opacity(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time-based: \(example.timeBased.time), \(example.timeBased.description)")
    }
    
    // MARK: - Divider
    
    private var dividerView: some View {
        VStack(spacing: 8) {
            Text("VS")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 40)
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Advantage Callout
    
    private var advantageCallout: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Why weather-based works better")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(advantageText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Advantage: Why weather-based works better. \(advantageText)")
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.6),
                        Color.gray.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white,
                        Color.gray.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
    
    private var advantageText: String {
        switch index {
        case 0:
            return "Only reminds you when conditions are actually suitable for planting, saving you from cold weather disappointment."
        case 1:
            return "Ensures you exercise in comfortable conditions instead of forcing workouts in extreme weather."
        case 2:
            return "Opens your pool exactly when it's warm enough to enjoy, not on an arbitrary calendar date."
        default:
            return "Adapts to actual conditions instead of rigid schedules."
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(Array(comparisonExamples.enumerated()), id: \.offset) { index, example in
                ComparisonCard(example: example, index: index)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Dark Mode") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(Array(comparisonExamples.enumerated()), id: \.offset) { index, example in
                ComparisonCard(example: example, index: index)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

// MARK: - Comparison Examples for Preview

private let comparisonExamples: [ComparisonExample] = [
    ComparisonExample(
        title: "Gardening Reminder",
        weatherBased: WeatherBasedReminder(
            condition: "When it's above 60°F",
            description: "Perfect planting weather!",
            icon: "leaf.fill",
            color: .green
        ),
        timeBased: TimeBasedReminder(
            time: "Every Saturday 9 AM",
            description: "Check garden (even if it's 30°F)",
            icon: "clock.fill",
            color: .gray
        )
    ),
    ComparisonExample(
        title: "Outdoor Exercise",
        weatherBased: WeatherBasedReminder(
            condition: "When it's 65-80°F",
            description: "Ideal running conditions",
            icon: "figure.run",
            color: .blue
        ),
        timeBased: TimeBasedReminder(
            time: "Daily at 6 PM",
            description: "Go for a run (rain or shine)",
            icon: "clock.fill",
            color: .gray
        )
    ),
    ComparisonExample(
        title: "Pool Maintenance",
        weatherBased: WeatherBasedReminder(
            condition: "First day above 75°F",
            description: "Time to open the pool!",
            icon: "figure.pool.swim",
            color: .cyan
        ),
        timeBased: TimeBasedReminder(
            time: "April 15th",
            description: "Open pool (might still be cold)",
            icon: "calendar",
            color: .gray
        )
    )
]
