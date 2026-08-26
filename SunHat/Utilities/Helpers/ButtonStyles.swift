//
//  ButtonStyles.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Button Style

struct EnhancedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Magical Button Style (for special actions)

struct MagicalButtonStyle: ButtonStyle {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .overlay(
                // Shimmer effect
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
                    .opacity(reduceMotion ? 0 : 1)
                    .offset(x: isAnimating ? 200 : -200)
                    .animation(
                        reduceMotion ? nil : .linear(duration: 2.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .clipped()
            )
            .onAppear {
                if !reduceMotion {
                    isAnimating = true
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.05 : 0.1),
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Subtle Button Style

struct SubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Gradient Button Style

struct GradientButtonStyle: ButtonStyle {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    init(colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // AnyShapeStyle pins `.opacity` to the ShapeStyle overload. As of the
                // Xcode 27 SDK LinearGradient satisfies both View and ShapeStyle, so a
                // bare `.opacity` here is ambiguous.
                AnyShapeStyle(
                    LinearGradient(
                        colors: colors,
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Weather-themed Button Style

struct WeatherButtonStyle: ButtonStyle {
    let weatherCondition: WeatherButtonCondition
    
    enum WeatherButtonCondition {
        case sunny
        case cloudy
        case rainy
        case snowy
        
        var colors: [Color] {
            switch self {
            case .sunny:
                return [.yellow, .orange]
            case .cloudy:
                return [.gray, .blue]
            case .rainy:
                return [.blue, .indigo]
            case .snowy:
                return [.white, .blue]
            }
        }
        
        var icon: String {
            switch self {
            case .sunny:
                return "sun.max.fill"
            case .cloudy:
                return "cloud.fill"
            case .rainy:
                return "cloud.rain.fill"
            case .snowy:
                return "cloud.snow.fill"
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // See note above: AnyShapeStyle disambiguates `.opacity` under the
                // Xcode 27 SDK, where LinearGradient is both a View and a ShapeStyle.
                AnyShapeStyle(
                    LinearGradient(
                        colors: weatherCondition.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Button("Primary Button") {}
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        
        Button("Enhanced Button") {}
            .buttonStyle(EnhancedButtonStyle())
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        
        Button("Magical Button") {}
            .buttonStyle(MagicalButtonStyle())
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.pink, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        
        Button("Weather Button") {}
            .buttonStyle(WeatherButtonStyle(weatherCondition: .sunny))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
