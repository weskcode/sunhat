//
//  WelcomeViewComponents.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

// MARK: - Button Styles (using shared ButtonStyles from ButtonStyles.swift)

// MARK: - Weather Animation Components

struct AnimatedWeatherIcon: View {
    let systemName: String
    let color: Color
    let size: CGFloat
    let animationType: WeatherAnimationType
    
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @State private var scaleEffect: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    enum WeatherAnimationType {
        case rotation
        case pulse
        case float
        case glow
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(scaleEffect)
            .rotationEffect(.degrees(rotationAngle))
            .offset(offset)
            .shadow(color: color.opacity(0.3), radius: isAnimating ? 8 : 4)
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        isAnimating = true
        
        switch animationType {
        case .rotation:
            withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
        case .pulse:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scaleEffect = 1.1
            }
            
        case .float:
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                offset = CGSize(width: 0, height: -10)
            }
            
        case .glow:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                scaleEffect = 1.05
            }
        }
    }
}

// MARK: - Floating Particles Effect

struct FloatingParticles: View {
    let particleCount: Int
    let colors: [Color]

    @State private var particles: [Particle] = []
    @State private var screenSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles.indices, id: \.self) { index in
                    Circle()
                        .fill(particles[index].color.opacity(particles[index].opacity))
                        .frame(width: particles[index].size, height: particles[index].size)
                        .position(particles[index].position)
                        .blur(radius: particles[index].blur)
                }
            }
            .onAppear {
                screenSize = geometry.size
                generateParticles()
                startParticleAnimation()
            }
            .onChange(of: geometry.size) { _, newSize in
                screenSize = newSize
            }
        }
    }

    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenSize.width),
                    y: CGFloat.random(in: 0...screenSize.height)
                ),
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.2...0.6),
                blur: CGFloat.random(in: 0...3)
            )
        }
    }

    private func startParticleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.linear(duration: 0.1)) {
                    for index in particles.indices {
                        particles[index].position.y -= CGFloat.random(in: 0.5...2.0)
                        particles[index].position.x += CGFloat.random(in: -0.5...0.5)

                        // Reset particle if it goes off screen
                        if particles[index].position.y < -10 {
                            particles[index].position.y = screenSize.height + 10
                            particles[index].position.x = CGFloat.random(in: 0...screenSize.width)
                        }
                    }
                }
            }
        }
    }
}

struct Particle {
    var position: CGPoint
    let color: Color
    let size: CGFloat
    let opacity: Double
    let blur: CGFloat
}

// MARK: - Temperature Gauge Animation

struct TemperatureGauge: View {
    let temperature: Double
    let minTemp: Double
    let maxTemp: Double
    let isTriggered: Bool
    
    @State private var animatedTemperature: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Gauge background
            ZStack(alignment: .bottom) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 12, height: 80)
                
                // Temperature fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(temperatureGradient)
                    .frame(width: 12, height: temperatureFillHeight)
                    .animation(.easeInOut(duration: 1.0), value: animatedTemperature)
                
                // Trigger indicator
                if isTriggered {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .offset(y: -temperatureFillHeight + 4)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                }
            }
            
            // Temperature label
            Text("\(Int(animatedTemperature))°")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 1.0), value: animatedTemperature)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedTemperature = temperature
            }
            
            if isTriggered {
                isAnimating = true
            }
        }
    }
    
    private var temperatureFillHeight: CGFloat {
        let normalizedTemp = (animatedTemperature - minTemp) / (maxTemp - minTemp)
        return CGFloat(max(0, min(1, normalizedTemp)) * 80)
    }
    
    private var temperatureGradient: LinearGradient {
        let normalizedTemp = (temperature - minTemp) / (maxTemp - minTemp)
        
        if normalizedTemp < 0.3 {
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .bottom,
                endPoint: .top
            )
        } else if normalizedTemp < 0.7 {
            return LinearGradient(
                colors: [Color.green, Color.yellow],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }
}

// MARK: - Weather Transition Effect

struct WeatherTransitionView: View {
    let fromWeather: WeatherCondition
    let toWeather: WeatherCondition
    
    @State private var transitionProgress: Double = 0
    @State private var showSecondWeather = false
    
    var body: some View {
        ZStack {
            // First weather condition
            weatherIcon(for: fromWeather)
                .opacity(1.0 - transitionProgress)
                .scaleEffect(1.0 - transitionProgress * 0.3)
            
            // Second weather condition
            if showSecondWeather {
                weatherIcon(for: toWeather)
                    .opacity(transitionProgress)
                    .scaleEffect(0.7 + transitionProgress * 0.3)
            }
        }
        .task {
            await startTransition()
        }
    }
    
    private func weatherIcon(for condition: WeatherCondition) -> some View {
        Group {
            switch condition {
            case .clear:
                AnimatedWeatherIcon(systemName: "sun.max.fill", color: .yellow, size: 60, animationType: .rotation)
            case .partlyCloudy:
                AnimatedWeatherIcon(systemName: "cloud.sun.fill", color: .orange, size: 60, animationType: .float)
            case .cloudy:
                AnimatedWeatherIcon(systemName: "cloud.fill", color: .gray, size: 60, animationType: .pulse)
            case .rain:
                AnimatedWeatherIcon(systemName: "cloud.rain.fill", color: .blue, size: 60, animationType: .float)
            case .snow:
                AnimatedWeatherIcon(systemName: "cloud.snow.fill", color: .white, size: 60, animationType: .pulse)
            default:
                AnimatedWeatherIcon(systemName: "cloud.fill", color: .gray, size: 60, animationType: .glow)
            }
        }
    }
    
    private func startTransition() async {
        do {
            try await Task.sleep(for: .seconds(1))
            showSecondWeather = true

            withAnimation(.easeInOut(duration: 2.0)) {
                transitionProgress = 1.0
            }
        } catch is CancellationError {
            // View disappeared before the transition began.
        } catch {
            showSecondWeather = true
            transitionProgress = 1.0
        }
    }
}

// MARK: - Animated Background Gradient

struct AnimatedBackgroundGradient: View {
    @State private var gradientOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .hueRotation(.degrees(gradientOffset))
        .onAppear {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
        }
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black,
                Color.blue.opacity(0.3),
                Color.purple.opacity(0.2),
                Color.black
            ]
        } else {
            return [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.90, green: 0.95, blue: 1.0),
                Color(red: 0.85, green: 0.93, blue: 1.0),
                Color(red: 0.95, green: 0.97, blue: 1.0)
            ]
        }
    }
}

// MARK: - Accessibility Helpers

extension View {
    func customAccessibilityRespondsToInversion(_ responds: Bool = true) -> some View {
        self.accessibilityIgnoresInvertColors(!responds)
    }
    
    func customDynamicTypeSize(_ range: ClosedRange<DynamicTypeSize>) -> some View {
        self.dynamicTypeSize(range)
    }
}

// MARK: - Custom Transitions

extension AnyTransition {
    static var temperatureScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.1, anchor: .bottom).combined(with: .opacity),
            removal: .scale(scale: 1.5, anchor: .top).combined(with: .opacity)
        )
    }
}
