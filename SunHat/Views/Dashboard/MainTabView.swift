//
//  MainTabView.swift
//  SunHat
//
//  Created by Wesley Keetch on 12/23/25.
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showingCreate = false
    @State private var reminderPath: [UUID] = []
    @StateObject private var lifecyclePrompts = AppLifecyclePromptCoordinator()
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private enum AppTab: Hashable {
        case home
        case weather
        case reminders
        case settings
        case add
    }

    // Intercept selection of the `.add` "tab" without ever changing the real
    // selection, so the trailing glass button acts as a button (opens the create
    // sheet) and the current tab stays put. Using a custom binding avoids the
    // re-entrancy of reverting the selection inside `.onChange`.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .add {
                    showingCreate = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                DashboardView()
            }

            Tab("Weather", systemImage: "cloud.sun", value: AppTab.weather) {
                WeatherView()
            }

            Tab("Reminders", systemImage: "list.bullet.rectangle", value: AppTab.reminders) {
                NavigationStack(path: $reminderPath) {
                    AllRemindersView()
                        .navigationDestination(for: UUID.self) { reminderID in
                            NotificationReminderDestination(reminderID: reminderID)
                        }
                }
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }

            // `role: .search` renders as a detached circular glass button on the
            // trailing side of the tab bar (the slot Apple Music uses for search).
            // We repurpose it as "New Task": selecting it opens the create sheet and
            // reverts the selection, so it behaves like a button rather than a tab.
            Tab("New Task", systemImage: "plus", value: AppTab.add, role: .search) {
                Color.clear
            }
        }
        .tint(Color.accentColor)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingCreate) {
            StreamlinedReminderCreationView(onReminderCreated: {
                if !onboardingCoordinator.hasCreatedFirstReminder {
                    onboardingCoordinator.markFirstReminderCreated()
                }
            })
        }
        .task {
            consumePendingIntentDestination()
            consumePendingNotificationDestination()
            await lifecyclePrompts.recordForegroundOpenIfNeeded(
                hasPositiveEngagementSignal: onboardingCoordinator.hasCreatedFirstReminder
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
            consumePendingIntentDestination()
            consumePendingNotificationDestination()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NotificationNavigationHandoff.didStoreDestination
            )
        ) { _ in
            consumePendingNotificationDestination()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sunHatShowRemindersTab)) { _ in
            selectedTab = .reminders
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                Task {
                    await lifecyclePrompts.recordForegroundOpenIfNeeded(
                        hasPositiveEngagementSignal: onboardingCoordinator.hasCreatedFirstReminder
                    )
                }
            case .background:
                lifecyclePrompts.endForegroundSession()
            default:
                break
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            routeSearchActivity(userActivity)
        }
        .alert("Turn On Weather Reminders?", isPresented: $lifecyclePrompts.showsNotificationPrompt) {
            Button("Not Now", role: .cancel) {
                lifecyclePrompts.handleNotificationPromptChoice(shouldEnable: false)
            }
            Button("Enable Notifications") {
                lifecyclePrompts.handleNotificationPromptChoice(shouldEnable: true)
            }
        } message: {
            Text("SunHat can only alert you when weather matches your tasks if notifications are enabled.")
        }
        .alert("Enjoying SunHat?", isPresented: $lifecyclePrompts.showsEnjoymentPrompt) {
            Button("Not Really") {
                lifecyclePrompts.handleEnjoymentResponse(isEnjoying: false)
            }
            Button("Yes") {
                lifecyclePrompts.handleEnjoymentResponse(isEnjoying: true)
            }
        } message: {
            Text("A quick answer helps us decide whether to ask for a review or collect feedback.")
        }
        .alert("Review SunHat?", isPresented: $lifecyclePrompts.showsReviewPrompt) {
            Button("Not Now", role: .cancel) {
                lifecyclePrompts.deferReviewRequest()
            }
            Button("Review SunHat") {
                lifecyclePrompts.handleReviewRequest()
            }
        } message: {
            Text("Reviews help more people discover weather-triggered reminders.")
        }
        .sheet(isPresented: $lifecyclePrompts.showsFeedbackForm) {
            AppFeedbackFormView(
                feedbackText: $lifecyclePrompts.feedbackText,
                onSubmit: lifecyclePrompts.submitFeedback,
                onCancel: lifecyclePrompts.dismissFeedback
            )
        }
    }

    private func consumePendingIntentDestination() {
        guard let destination = SunHatIntentHandoff.consumePendingDestination() else {
            return
        }

        switch destination {
        case .home:
            selectedTab = .home
        case .reminders, .nextReady:
            selectedTab = .reminders
        case .createReminder:
            showingCreate = true
        case .settings:
            selectedTab = .settings
        }
    }

    private func consumePendingNotificationDestination() {
        guard let reminderID = NotificationNavigationHandoff.shared.consumePendingReminderID() else {
            return
        }

        selectedTab = .reminders
        reminderPath = [reminderID]
    }

    private func routeSearchActivity(_ userActivity: NSUserActivity) {
        guard
            let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let destination = SunHatSearchIndexer.destination(for: identifier)
        else {
            return
        }

        switch destination {
        case .reminders:
            selectedTab = .reminders
        case .settings:
            selectedTab = .settings
        }
    }
}

extension Notification.Name {
    /// Posted by views nested in other tabs (e.g. the dashboard's truncated
    /// task list) to switch the tab bar to the Reminders tab.
    static let sunHatShowRemindersTab = Notification.Name("SunHat.showRemindersTab")
}

private struct NotificationReminderDestination: View {
    @Query private var reminders: [WeatherReminder]

    init(reminderID: UUID) {
        _reminders = Query(
            filter: #Predicate<WeatherReminder> { reminder in
                reminder.id == reminderID
            }
        )
    }

    var body: some View {
        if let reminder = reminders.first {
            DetailedReminderView(reminder: reminder)
        } else {
            ContentUnavailableView(
                "Task Unavailable",
                systemImage: "bell.slash",
                description: Text("This weather task may have been deleted.")
            )
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(OnboardingCoordinator())
        .modelContainer(for: [
            WeatherReminder.self,
            WeatherData.self,
            ForecastDay.self,
            UserPreferences.self,
            LocationData.self
        ], inMemory: true)
}
