//
//  ReminderSummaryCard.swift
//  hatti
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

// MARK: - Reminder Summary Card

struct ReminderSummaryCard: View {
    let reminder: CustomReminder
    let triggerLikelihood: TriggerLikelihood?
    
    @State private var showContent = false
    @State private var showDetails = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with activity icon
            HStack(spacing: 16) {
                // Activity icon with glow effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    reminder.activity.color.opacity(0.3),
                                    reminder.activity.color.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(showContent ? 1.0 : 0.8)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showContent)
                    
                    Circle()
                        .fill(reminder.activity.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(reminder.activity.color.opacity(0.3), lineWidth: 2)
                        )
                    
                    Image(systemName: reminder.activity.icon)
                        .font(.title)
                        .foregroundColor(reminder.activity.color)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: showContent)
                }
                .accessibilityHidden(true)
                
                // Title and description
                VStack(alignment: .leading, spacing: 8) {
                    Text(reminder.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(x: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                    
                    Text("Weather-triggered reminder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(x: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
                    
                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Active & Monitoring")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.1))
                    )
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(x: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.7), value: showContent)
                }
                
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            // Divider
            Divider()
                .padding(.vertical, 20)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.8), value: showContent)
            
            // Conditions summary
            VStack(spacing: 16) {
                // Temperature condition
                ConditionSummaryRow(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: reminder.temperatureDescription,
                    color: .blue,
                    animationDelay: 0.9
                )
                
                // Time preference
                ConditionSummaryRow(
                    icon: reminder.preferredTimeRange.icon,
                    title: "Time",
                    value: reminder.preferredTimeRange.displayName,
                    color: .orange,
                    animationDelay: 1.0
                )
                
                // Quiet hours
                if reminder.respectQuietHours {
                    ConditionSummaryRow(
                        icon: "moon.zzz",
                        title: "Quiet Hours",
                        value: "Respected",
                        color: .purple,
                        animationDelay: 1.1
                    )
                }
            }
            .padding(.horizontal, 24)
            
            // Likelihood summary
            if let likelihood = triggerLikelihood {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical, 16)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next 7 Days")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(likelihood.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Circular progress
                        ZStack {
                            Circle()
                                .stroke(likelihood.color.opacity(0.2), lineWidth: 4)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: showContent ? likelihood.percentage / 100 : 0)
                                .stroke(likelihood.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1.5).delay(1.2), value: showContent)
                            
                            Text("\(Int(likelihood.percentage))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(likelihood.color)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(1.1), value: showContent)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    showDetails = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                        
                        Text("View Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Edit action
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                        
                        Text("Edit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(1.3), value: showContent)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .scaleEffect(showContent ? 1.0 : 0.95)
        .opacity(showContent ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
            } else {
                showContent = true
            }
        }
        .sheet(isPresented: $showDetails) {
            ReminderDetailsView(reminder: reminder, likelihood: triggerLikelihood)
        }
    }
}

// MARK: - Condition Summary Row

struct ConditionSummaryRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
            }
            .accessibilityHidden(true)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(.green)
                .scaleEffect(isVisible ? 1.0 : 0.5)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(animationDelay), value: isVisible)
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(x: isVisible ? 0 : 30)
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

// MARK: - Reminder Details View

struct ReminderDetailsView: View {
    let reminder: CustomReminder
    let likelihood: TriggerLikelihood?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(reminder.activity.color.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: reminder.activity.icon)
                                .font(.title)
                                .foregroundColor(reminder.activity.color)
                        }
                        
                        VStack(spacing: 8) {
                            Text(reminder.displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("Created just now")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Detailed conditions
                    VStack(spacing: 20) {
                        DetailSection(title: "Trigger Conditions") {
                            VStack(spacing: 12) {
                                DetailRow(
                                    icon: "thermometer.medium",
                                    title: "Temperature",
                                    value: reminder.temperatureDescription,
                                    color: .blue
                                )
                                
                                DetailRow(
                                    icon: reminder.preferredTimeRange.icon,
                                    title: "Time Range",
                                    value: reminder.preferredTimeRange.displayName,
                                    color: .orange
                                )
                                
                                if reminder.respectQuietHours {
                                    DetailRow(
                                        icon: "moon.zzz",
                                        title: "Quiet Hours",
                                        value: "Will respect your sleep schedule",
                                        color: .purple
                                    )
                                }
                            }
                        }
                        
                        if let likelihood = likelihood {
                            DetailSection(title: "Forecast Analysis") {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Trigger Likelihood")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(likelihood.description)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(likelihood.color)
                                    }
                                    
                                    HStack {
                                        Text("Expected Triggers")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("\(likelihood.triggerDays.count) days this week")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                        
                        DetailSection(title: "How It Works") {
                            VStack(alignment: .leading, spacing: 12) {
                                HowItWorksStep(
                                    number: 1,
                                    title: "Continuous Monitoring",
                                    description: "hatti checks weather conditions every 15 minutes"
                                )
                                
                                HowItWorksStep(
                                    number: 2,
                                    title: "Smart Notifications",
                                    description: "You'll get notified when conditions match your preferences"
                                )
                                
                                HowItWorksStep(
                                    number: 3,
                                    title: "Perfect Timing",
                                    description: "Notifications arrive at the optimal time for your activity"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
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

// MARK: - Supporting Views

struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct HowItWorksStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

//#Preview {
//    ReminderSummaryCard(
//        reminder: CustomReminder(),
//        triggerLikelihood: TriggerLikelihood(
//            percentage: 75,
//            triggerDays: [Date()],
//            description: "Good chance"
//        )
//    )
//    .padding()
//}
