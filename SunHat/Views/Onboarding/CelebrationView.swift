//
//  CelebrationView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

struct CelebrationView: View {
    @State private var showConfetti = false
    @State private var showCheckmark = false
    @State private var showText = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var confettiOpacity: Double = 1.0
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Confetti particles
            if showConfetti {
                GeometryReader { geometry in
                    ConfettiParticles(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                        .opacity(confettiOpacity)
                        .transition(.opacity)
                }
                .ignoresSafeArea()
            }
            
            // Main celebration content
            VStack(spacing: 30) {
                // Checkmark with pulse animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(pulseScale)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(showCheckmark ? 1.0 : 0.3)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: showCheckmark)
                .accessibilityHidden(true)
                
                // Celebration text with enhanced animations
                VStack(spacing: 16) {
                    // Main congratulations with bounce effect
                    Text("Congratulations! 🎉")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .scaleEffect(showText ? 1.0 : 0.8)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: showText)
                    
                    // Success message with slide up
                    Text("Your first weather reminder is ready!")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .offset(y: showText ? 0 : 30)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.4).delay(0.55), value: showText)
                    
                    // Description with fade in
                    Text("You'll be notified when conditions are perfect for your activity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.4).delay(0.7), value: showText)
                    
                    // Quick preview card
                    if showText {
                        HStack(spacing: 12) {
                            Image(systemName: "thermometer.sun.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your reminder is active!")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Monitoring weather conditions now")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "checkmark")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        .scaleEffect(showText ? 1.0 : 0.9)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.85), value: showText)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Magic sparkles
                HStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .scaleEffect(showText ? 1.0 : 0.5)
                            .opacity(showText ? 1.0 : 0.0)
                            .animation(
                                .easeOut(duration: 0.6)
                                .delay(0.5 + Double(index) * 0.05),
                                value: showText
                            )
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(30)
        }
        .onAppear {
            startCelebration()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Congratulations! Your first weather reminder is ready. You'll be notified when conditions are perfect for your activity.")
    }
    
    private func startCelebration() {
        if reduceMotion {
            showConfetti = false
            showCheckmark = true
            showText = true
            return
        }

        withAnimation(.easeOut(duration: 0.5)) {
            showConfetti = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation {
                showCheckmark = true
                pulseScale = 1.1
            }

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            withAnimation {
                showText = true
            }

            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                confettiOpacity = 0.0
            }
        }
    }
}

// MARK: - Confetti Particles

struct ConfettiParticles: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    @State private var particles: [ConfettiParticle] = []
    @State private var startDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan
    ]
    
    var body: some View {
        Group {
            if reduceMotion {
                particleLayer(elapsed: 0)
                    .opacity(0.35)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    particleLayer(elapsed: context.date.timeIntervalSince(startDate))
                }
            }
        }
        .task(id: reduceMotion) {
            startDate = Date()
            generateParticles()
        }
    }

    private func particleLayer(elapsed: TimeInterval) -> some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                ConfettiParticleView(
                    particle: particles[index].projected(
                        elapsed: elapsed,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight
                    )
                )
            }
        }
    }
    
    private func generateParticles() {
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...screenWidth),
                y: -20,
                color: colors.randomElement() ?? .blue,
                rotation: Double.random(in: 0...360),
                size: CGFloat.random(in: 8...16),
                velocityX: CGFloat.random(in: -50...50),
                velocityY: CGFloat.random(in: 100...200),
                angularVelocity: Double.random(in: -180...180)
            )
        }
    }
    
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    
    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size / 2)
            .rotationEffect(.degrees(particle.rotation))
            .position(x: particle.x, y: particle.y)
    }
}

struct ConfettiParticle {
    var x: CGFloat
    var y: CGFloat
    let color: Color
    var rotation: Double
    let size: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    let angularVelocity: Double
    
    func projected(elapsed: TimeInterval, screenWidth: CGFloat, screenHeight: CGFloat) -> ConfettiParticle {
        let cycle = max(1.4, Double(screenHeight) / max(Double(velocityY), 1))
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        let projectedX = (x + velocityX * CGFloat(t)).truncatingRemainder(dividingBy: max(screenWidth, 1))
        let gravityY = 0.5 * 300 * t * t

        return ConfettiParticle(
            x: projectedX < 0 ? projectedX + screenWidth : projectedX,
            y: y + velocityY * CGFloat(t) + CGFloat(gravityY),
            color: color,
            rotation: rotation + angularVelocity * t,
            size: size,
            velocityX: velocityX,
            velocityY: velocityY,
            angularVelocity: angularVelocity
        )
    }
}

// MARK: - Alternative Simple Celebration (for reduced motion)

struct SimpleCelebrationView: View {
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
                
                // Text
                VStack(spacing: 12) {
                    Text("Success!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("Your first reminder is ready")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .padding(30)
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CelebrationView()
}

#Preview("Simple") {
    SimpleCelebrationView()
}
