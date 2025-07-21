//
//  CelebrationView.swift
//  hatti
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
                ConfettiParticles()
                    .opacity(confettiOpacity)
                    .transition(.opacity)
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
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showCheckmark ? 1.0 : 0.3)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.2), value: showCheckmark)
                .accessibilityHidden(true)
                
                // Celebration text with enhanced animations
                VStack(spacing: 16) {
                    // Main congratulations with bounce effect
                    Text("Congratulations! 🎉")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .scaleEffect(showText ? 1.0 : 0.8)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.0), value: showText)
                    
                    // Success message with slide up
                    Text("Your first weather reminder is ready!")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .offset(y: showText ? 0 : 30)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(1.3), value: showText)
                    
                    // Description with fade in
                    Text("You'll be notified when conditions are perfect for your activity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(1.6), value: showText)
                    
                    // Quick preview card
                    if showText {
                        HStack(spacing: 12) {
                            Image(systemName: "thermometer.sun.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your reminder is active!")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("Monitoring weather conditions now")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "checkmark")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
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
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.9), value: showText)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Magic sparkles
                HStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.yellow)
                            .scaleEffect(showText ? 1.0 : 0.5)
                            .opacity(showText ? 1.0 : 0.0)
                            .animation(
                                .easeOut(duration: 0.6)
                                .delay(1.2 + Double(index) * 0.1),
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
            // Show all elements immediately for reduced motion
            showConfetti = true
            showCheckmark = true
            showText = true
            return
        }
        
        // Start confetti immediately
        withAnimation(.easeOut(duration: 0.5)) {
            showConfetti = true
        }
        
        // Show checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                showCheckmark = true
                pulseScale = 1.1
            }
        }
        
        // Show text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                showText = true
            }
        }
        
        // Fade out confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                confettiOpacity = 0.0
            }
        }
    }
}

// MARK: - Confetti Particles

struct ConfettiParticles: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?
    
    private let colors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan
    ]
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                if index < particles.count {
                    ConfettiParticleView(particle: particles[index])
                }
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func generateParticles() {
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
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
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        for index in particles.indices {
            particles[index].update()
            
            // Reset particle if it goes off screen
            if particles[index].y > UIScreen.main.bounds.height + 50 {
                particles[index] = ConfettiParticle(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
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
    
    mutating func update() {
        x += velocityX * 0.02
        y += velocityY * 0.02
        rotation += angularVelocity * 0.02
        
        // Apply gravity
        velocityY += 300 * 0.02
        
        // Apply air resistance
        velocityX *= 0.99
        velocityY *= 0.99
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
                        .foregroundColor(.white)
                }
                .accessibilityHidden(true)
                
                // Text
                VStack(spacing: 12) {
                    Text("Success!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Your first reminder is ready")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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