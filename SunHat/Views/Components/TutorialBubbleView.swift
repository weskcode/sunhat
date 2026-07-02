//
//  TutorialBubbleView.swift
//  SunHat
//
//  Created by Wesley Keetch on 2/10/26.
//

import SwiftUI

struct TutorialBubbleView: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Bubble
            HStack(spacing: 10) {
                Button(action: onTap) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                            .foregroundStyle(.blue)

                        Text("Create your first reminder")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create your first reminder")
                .accessibilityHint("Opens the reminder creation flow")

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss hint")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            )

            // Arrow pointing down toward the FAB
            TrianglePointer()
                .fill(.ultraThinMaterial)
                .frame(width: 16, height: 8)
        }
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .task {
            if reduceMotion {
                isVisible = true
            } else {
                do {
                    try await Task.sleep(for: .milliseconds(400))
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isVisible = true
                    }
                } catch is CancellationError {
                    // View disappeared before the hint animation started.
                } catch {
                    isVisible = true
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Triangle Pointer Shape

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        TutorialBubbleView(onTap: {}, onDismiss: {})
            .padding()
    }
}

#Preview("Dark Mode") {
    VStack {
        Spacer()
        TutorialBubbleView(onTap: {}, onDismiss: {})
            .padding()
    }
    .preferredColorScheme(.dark)
}
