//
//  UserPreferencesOnboardingView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData

struct UserPreferencesOnboardingView: View {
    @State private var viewModel = UserPreferencesViewModel()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                progressIndicator
                preferenceIntro
                unitSection
                finishButton
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .scrollIndicators(.hidden)
        .onAppear {
            viewModel.loadPreferences(from: modelContext)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Temperature unit setup")
        .accessibilityHint("Final onboarding step, step 4 of 4")
    }

    private var preferenceIntro: some View {
        VStack(spacing: 16) {
            Image(systemName: "thermometer.medium")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Choose your temperature unit")
                .font(dynamicTypeSize.isAccessibilitySize ? .title2 : .title)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("This controls how forecasts and weather conditions appear. You can change it later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
    }

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Temperature")
                .font(.headline)

            CompactTemperatureSelector(
                selectedUnit: $viewModel.preferences.temperatureUnit
            )
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
    }

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            ProgressView(value: 4, total: 4)
                .frame(maxWidth: 160)

            Text("Step 4 of 4")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress, final step, step 4 of 4")
    }

    private var finishButton: some View {
        Button(action: finishSetup) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(isSaving ? "Saving" : "Finish Setup")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.accentColor)
        .disabled(isSaving)
        .accessibilityLabel(isSaving ? String(localized: "Saving preferences", comment: "Accessibility label while onboarding preferences are being saved") : String(localized: "Finish setup", comment: "Accessibility label for the final onboarding button"))
    }

    private func finishSetup() {
        guard !isSaving else { return }
        isSaving = true

        Task { @MainActor in
            await viewModel.savePreferences(to: modelContext)
            isSaving = false
            coordinator.nextStep()
        }
    }
}

struct CompactTemperatureSelector: View {
    @Binding var selectedUnit: TemperatureUnit

    var body: some View {
        Picker("Temperature unit", selection: $selectedUnit) {
            ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                Text("\(unit.shortName) (\(unit.symbol))")
                    .tag(unit)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    UserPreferencesOnboardingView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: UserPreferences.self, inMemory: true)
}
