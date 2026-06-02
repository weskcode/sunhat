//
//  GlassCreateTaskButton.swift
//  SunHat
//

import SwiftUI

struct GlassCreateTaskButton: View {
    let action: () -> Void

    var body: some View {
        Button("Create Task", systemImage: "plus", action: action)
            .font(.title3.bold())
            .labelStyle(.iconOnly)
            .frame(minWidth: 56, minHeight: 56)
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .accessibilityLabel("Create task")
            .accessibilityHint("Creates a new weather-triggered task")
            .accessibilityInputLabels(["Create task", "Add task", "New task"])
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue.opacity(0.35), .orange.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        GlassCreateTaskButton {}
    }
}
