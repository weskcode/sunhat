//
//  NotificationPermissionView.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import UserNotifications
import Combine

struct NotificationPermissionView: View {
    @StateObject private var notificationManager = NotificationPermissionManager()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isRequestingPermission = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                progressIndicator
                permissionIntro
                notificationExample
                actions
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
            notificationManager.setupNotificationCategories()
        }
        .sensoryFeedback(.success, trigger: notificationManager.notificationStatus) { _, newValue in
            newValue == .authorized
        }
        .alert("Notification Access", isPresented: $notificationManager.showPermissionDeniedAlert) {
            Button("Open Settings") {
                notificationManager.openAppSettings()
            }
            Button("Continue Without Notifications", role: .cancel) {
                coordinator.nextStep()
            }
        } message: {
            Text("Allow notifications in Settings to receive weather reminders, or continue without them.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notification setup")
        .accessibilityHint("Step 3 of 4")
    }

    private var progressIndicator: some View {
        VStack(spacing: 8) {
            ProgressView(value: 3, total: 4)
                .frame(maxWidth: 160)

            Text("Step 3 of 4")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress, step 3 of 4")
    }

    private var permissionIntro: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Know when conditions are right")
                .font(dynamicTypeSize.isAccessibilitySize ? .title2 : .title)
                .bold()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Allow notifications so SunHat can tell you when the weather matches one of your tasks. You can change this later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
    }

    private var notificationExample: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SunHat")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Gardening conditions match")
                .font(.body.weight(.medium))

            Text("It is 72°F and sunny at your selected location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification. Gardening conditions match. It is 72 degrees and sunny at your selected location.")
    }

    private var actions: some View {
        VStack(spacing: 16) {
            Button(action: requestNotificationPermission) {
                HStack(spacing: 10) {
                    if isRequestingPermission {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isRequestingPermission ? "Requesting Permission" : "Enable Notifications")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.accentColor)
            .disabled(isRequestingPermission)

            Button("Not Now") {
                coordinator.nextStep()
            }
            .frame(minHeight: 44)
        }
    }

    private func requestNotificationPermission() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true

        notificationManager.requestNotificationPermission { granted in
            Task { @MainActor in
                isRequestingPermission = false
                if granted {
                    coordinator.nextStep()
                }
            }
        }
    }
}

@MainActor
final class NotificationPermissionManager: NSObject, ObservableObject {
    @Published var showPermissionDeniedAlert = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()

    override init() {
        super.init()
        checkNotificationStatus()
    }

    func setupNotificationCategories() {
        SunHatNotificationCategoryRegistry.register(center: notificationCenter)
    }

    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                await MainActor.run {
                    checkNotificationStatus()
                    if !granted {
                        showPermissionDeniedAlert = true
                    }
                    completion(granted)
                }
            } catch {
                await MainActor.run {
                    showPermissionDeniedAlert = true
                    completion(false)
                }
            }
        }
    }

    func checkNotificationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            UIApplication.shared.open(settingsURL)
        }
    }
}

enum NotificationCategory: String, CaseIterable {
    case weatherTrigger = "WEATHER_TRIGGER"
    case dailySummary = "DAILY_SUMMARY"
    case severeWeather = "SEVERE_WEATHER"
    case reminderCompleted = "REMINDER_COMPLETED"

    var displayName: String {
        switch self {
        case .weatherTrigger: "Weather Triggers"
        case .dailySummary: "Daily Summaries"
        case .severeWeather: "Severe Weather Alerts"
        case .reminderCompleted: "Reminder Completions"
        }
    }

    var description: String {
        switch self {
        case .weatherTrigger: "Notifications when weather conditions match your reminders"
        case .dailySummary: "Daily weather summaries and upcoming reminders"
        case .severeWeather: "Important alerts about severe weather affecting your reminders"
        case .reminderCompleted: "Confirmations when weather-based reminders are completed"
        }
    }
}

#Preview {
    NotificationPermissionView()
        .environmentObject(OnboardingCoordinator())
}
