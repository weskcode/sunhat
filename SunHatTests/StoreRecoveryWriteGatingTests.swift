//
//  StoreRecoveryWriteGatingTests.swift
//  SunHatTests
//
//  Verifies that reminder creation and editing are blocked while the app is
//  running on the throwaway in-memory fallback store, so a user can't create
//  or edit a reminder that silently vanishes at termination. StoreRecoveryState
//  is a process-wide singleton, so every test that puts it into a degraded
//  state resets it in a `defer` to avoid leaking into unrelated tests.
//

import Foundation
import SwiftData
import CoreLocation
import Testing
@testable import SunHat

private struct DummyRecoveryError: Error {}

/// reportPersistentStoreFailure/reportRecoveryFailure are nonisolated and hop
/// to the MainActor via an unstructured Task (their real caller, the
/// ModelContainer init closure, isn't MainActor-isolated), so the level
/// update isn't guaranteed to have landed by the very next line. Polls with
/// yields instead of a fixed sleep or assuming one yield is always enough.
@MainActor
private func waitUntilLevelSettles(expected: StoreRecoveryLevel, maxAttempts: Int = 50) async {
    for _ in 0..<maxAttempts {
        if StoreRecoveryState.shared.level == expected { return }
        await Task.yield()
    }
}

@MainActor
struct StoreRecoveryLevelReportingTests {

    @Test("Normal operation does not report write-unsafe")
    func normalOperationIsWriteSafe() {
        StoreRecoveryState.shared.resetForTesting()
        #expect(StoreRecoveryState.shared.isWriteUnsafe == false)
    }

    @Test("A repaired store (not the in-memory fallback) does not block writes")
    func repairedStoreDoesNotBlockWrites() async {
        StoreRecoveryState.shared.resetForTesting()
        defer { StoreRecoveryState.shared.resetForTesting() }

        StoreRecoveryState.shared.reportPersistentStoreFailure(DummyRecoveryError())
        await waitUntilLevelSettles(expected: .storeRepaired)

        #expect(StoreRecoveryState.shared.level == .storeRepaired)
        #expect(StoreRecoveryState.shared.isWriteUnsafe == false)
    }

    @Test("The in-memory fallback reports write-unsafe")
    func inMemoryFallbackIsWriteUnsafe() async {
        StoreRecoveryState.shared.resetForTesting()
        defer { StoreRecoveryState.shared.resetForTesting() }

        StoreRecoveryState.shared.reportRecoveryFailure(DummyRecoveryError())
        await waitUntilLevelSettles(expected: .inMemoryFallback)

        #expect(StoreRecoveryState.shared.level == .inMemoryFallback)
        #expect(StoreRecoveryState.shared.isWriteUnsafe == true)
    }
}

@MainActor
struct ReminderWriteGatingTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() throws {
        let schema = Schema([
            WeatherReminder.self,
            TriggerCondition.self,
            LocationData.self,
            WeatherData.self,
            ForecastDay.self,
            NotificationConfig.self,
            ReminderHistory.self,
            UserPreferences.self,
            SavedLocation.self,
            LocationHistory.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    @Test("Creating a reminder while write-blocked fails with a clear error and saves nothing")
    func createReminderBlockedDuringRecovery() throws {
        StoreRecoveryState.shared.resetForTesting()
        defer { StoreRecoveryState.shared.resetForTesting() }
        StoreRecoveryState.shared.setLevelForTesting(.inMemoryFallback)

        let viewModel = FirstReminderCreationViewModel()
        viewModel.configure(modelContext: modelContext)
        viewModel.customReminder.title = "Morning Walk"
        let location = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        )
        viewModel.selectManualLocation(location)

        #expect(viewModel.isWriteBlocked == true)
        #expect(viewModel.createReminder() == false)
        #expect(viewModel.creationErrorMessage != nil)

        let reminders = try modelContext.fetch(FetchDescriptor<WeatherReminder>())
        #expect(reminders.isEmpty)
    }

    @Test("Creating a reminder succeeds normally once recovery clears")
    func createReminderSucceedsAfterRecoveryClears() throws {
        StoreRecoveryState.shared.resetForTesting()
        defer { StoreRecoveryState.shared.resetForTesting() }

        let viewModel = FirstReminderCreationViewModel()
        viewModel.configure(modelContext: modelContext)
        viewModel.customReminder.title = "Morning Walk"
        let location = ManualLocationData(
            name: "Denver",
            coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        )
        viewModel.selectManualLocation(location)

        #expect(viewModel.isWriteBlocked == false)
        #expect(viewModel.createReminder() == true)

        let reminders = try modelContext.fetch(FetchDescriptor<WeatherReminder>())
        #expect(reminders.count == 1)
    }

    @Test("Saving reminder edits while write-blocked fails and persists nothing")
    func saveChangesBlockedDuringRecovery() async throws {
        let reminder = WeatherReminder(title: "Evening Walk")
        reminder.triggerCondition = TriggerCondition()
        reminder.location = LocationData(latitude: 47.6062, longitude: -122.3321)
        modelContext.insert(reminder)
        try modelContext.save()

        StoreRecoveryState.shared.resetForTesting()
        defer { StoreRecoveryState.shared.resetForTesting() }
        StoreRecoveryState.shared.setLevelForTesting(.inMemoryFallback)

        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: modelContext)

        var edited = EditableReminder(from: reminder)
        edited.title = "Renamed Walk"

        #expect(viewModel.isWriteBlocked == true)
        let success = await viewModel.saveChanges(edited)
        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(reminder.title == "Evening Walk")
    }

    @Test("Saving reminder edits succeeds normally once recovery clears")
    func saveChangesSucceedsAfterRecoveryClears() async throws {
        let reminder = WeatherReminder(title: "Evening Walk")
        reminder.triggerCondition = TriggerCondition()
        reminder.location = LocationData(latitude: 47.6062, longitude: -122.3321)
        modelContext.insert(reminder)
        try modelContext.save()

        StoreRecoveryState.shared.resetForTesting()
        defer { StoreRecoveryState.shared.resetForTesting() }

        let viewModel = DetailedReminderViewModel(reminder: reminder)
        viewModel.configure(modelContext: modelContext)

        var edited = EditableReminder(from: reminder)
        edited.title = "Renamed Walk"

        #expect(viewModel.isWriteBlocked == false)
        let success = await viewModel.saveChanges(edited)
        #expect(success == true)
        #expect(reminder.title == "Renamed Walk")
    }
}
