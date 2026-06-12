//
//  NotificationPermissionDependencyTests.swift
//  SunHatTests
//

import Foundation
import SwiftData
import Testing
@preconcurrency import UserNotifications
@testable import SunHat

@MainActor
struct NotificationPermissionDependencyTests {
    // MARK: - SettingsViewModel

    @Test("Granted permission enables notifications")
    func grantedPermissionEnablesNotifications() async throws {
        let permissions = StubNotificationPermissionProvider()
        permissions.grantsAuthorization = true
        let viewModel = SettingsViewModel(notificationPermissions: permissions)

        viewModel.requestNotificationPermission()

        try await waitUntil { viewModel.notificationsEnabled }
        #expect(permissions.requestedOptions.contains([.alert, .badge, .sound]))
        #expect(viewModel.actionError == nil)
    }

    @Test("Denied permission leaves notifications disabled without an error")
    func deniedPermissionLeavesNotificationsDisabled() async throws {
        let permissions = StubNotificationPermissionProvider()
        permissions.grantsAuthorization = false
        let viewModel = SettingsViewModel(notificationPermissions: permissions)

        viewModel.requestNotificationPermission()

        try await waitUntil { permissions.requestedOptions.isEmpty == false }
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.notificationsEnabled == false)
        #expect(viewModel.actionError == nil)
    }

    @Test("A failed permission request surfaces a user-visible error")
    func failedPermissionRequestSurfacesError() async throws {
        let permissions = StubNotificationPermissionProvider()
        permissions.errorToThrow = StubPermissionError.requestFailed
        let viewModel = SettingsViewModel(notificationPermissions: permissions)

        viewModel.requestNotificationPermission()

        try await waitUntil { viewModel.actionError != nil }
        #expect(viewModel.isShowingActionError == true)
        #expect(viewModel.notificationsEnabled == false)
    }

    // MARK: - NotificationPreferencesViewModel

    @Test("Permission status check reads through the injected provider")
    func statusCheckUsesInjectedProvider() async {
        let permissions = StubNotificationPermissionProvider()
        permissions.status = .denied
        let viewModel = NotificationPreferencesViewModel(notificationPermissions: permissions)

        let status = await viewModel.checkNotificationPermissions()

        #expect(status == .denied)
    }

    @Test("Critical alerts setting adds the critical alert authorization option")
    func criticalAlertsAddsAuthorizationOption() async throws {
        let permissions = StubNotificationPermissionProvider()
        let viewModel = NotificationPreferencesViewModel(notificationPermissions: permissions)
        viewModel.configure(modelContext: try makeInMemoryContext())
        await viewModel.loadSettings()
        viewModel.criticalAlertsEnabled = true

        await viewModel.saveSettings()

        #expect(permissions.requestedOptions.last?.contains(.criticalAlert) == true)
    }

    @Test("Denied permission during save surfaces an error message")
    func deniedPermissionDuringSaveSurfacesError() async throws {
        let permissions = StubNotificationPermissionProvider()
        permissions.grantsAuthorization = false
        let viewModel = NotificationPreferencesViewModel(notificationPermissions: permissions)
        viewModel.configure(modelContext: try makeInMemoryContext())
        await viewModel.loadSettings()

        await viewModel.saveSettings()

        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            WeatherReminder.self, TriggerCondition.self, LocationData.self,
            WeatherData.self, ForecastDay.self, NotificationConfig.self,
            ReminderHistory.self, UserPreferences.self, SavedLocation.self, LocationHistory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Condition was not met before timeout")
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubNotificationPermissionProvider: NotificationPermissionProviding {
    var status: UNAuthorizationStatus = .notDetermined
    var grantsAuthorization = true
    var errorToThrow: Error?
    private(set) var requestedOptions: [UNAuthorizationOptions] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions.append(options)
        if let errorToThrow {
            throw errorToThrow
        }
        return grantsAuthorization
    }
}

private enum StubPermissionError: Error {
    case requestFailed
}
