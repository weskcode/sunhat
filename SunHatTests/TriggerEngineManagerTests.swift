import Foundation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct TriggerEngineManagerTests {
    @Test("Duplicate background task registration is ignored instead of crashing")
    func duplicateBackgroundRegistrationIsIgnored() {
        // The initializer is public for dependency injection, and defaults to
        // registering. BGTaskScheduler's registry is process-global, so a second
        // registration of the same identifier raises NSInternalInconsistencyException
        // — an uncatchable crash on launch. Only the first caller may register.
        let first = TriggerEngineManager(registerBackgroundTask: false)
        let didRegister = first.registerBackgroundTask()

        let second = TriggerEngineManager(registerBackgroundTask: false)
        #expect(second.registerBackgroundTask() == false)
        #expect(first.registerBackgroundTask() == false)

        // Whether *this* call won the race depends on whether `shared` (or another
        // test) registered first; either way no later call may register again.
        _ = didRegister
    }

    @Test("A policy-suppressed condition remains eligible and does not advance cooldown")
    func suppressedDeliveryDoesNotRecordTrigger() async throws {
        let configuration = ModelConfiguration(
            schema: SunHatModelSchema.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: SunHatModelSchema.schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)

        let condition = TriggerCondition()
        let reminder = WeatherReminder(title: "Water plants", triggerCondition: condition)
        let preferences = UserPreferences()
        preferences.notificationsEnabled = false
        context.insert(reminder)
        context.insert(preferences)
        try context.save()

        let manager = TriggerEngineManager(
            modelContainer: container,
            registerBackgroundTask: false
        )
        let result = TriggerEvaluationResult(
            reminderId: reminder.id,
            conditionData: ModelDataConverter.convertTriggerCondition(condition),
            triggered: true,
            triggerReason: "Condition met"
        )

        await manager.processEvaluationResults([result])

        #expect(manager.triggeredReminders.isEmpty)
        #expect(manager.successfulTriggers == 0)
        #expect(reminder.lastTriggered == nil)
        #expect(reminder.triggerCount == 0)
        #expect(reminder.totalNotificationsSent == 0)
    }

    @Test("Concurrent evaluations deliver the same reminder only once")
    func concurrentEvaluationDoesNotDuplicateDelivery() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let condition = TriggerCondition()
        let reminder = WeatherReminder(title: "Water plants", triggerCondition: condition)
        context.insert(reminder)
        try context.save()

        let sender = GatedTriggerNotificationSender()
        let manager = TriggerEngineManager(
            modelContainer: container,
            registerBackgroundTask: false,
            notificationManager: sender
        )
        let result = TriggerEvaluationResult(
            reminderId: reminder.id,
            conditionData: ModelDataConverter.convertTriggerCondition(condition),
            triggered: true,
            triggerReason: "Condition met"
        )

        let first = Task { await manager.processEvaluationResults([result]) }
        while await sender.hasStarted == false { await Task.yield() }
        let second = Task { await manager.processEvaluationResults([result]) }
        await Task.yield()
        await sender.finishDelivery()
        await first.value
        await second.value

        #expect(await sender.deliveryCount == 1)
        #expect(manager.triggeredReminders == [reminder.id])

        // `updateReminderWithResult` persists through its own ModelContext, so the
        // instance this test inserted is a different (now stale) object. Re-fetch to
        // observe what was actually written.
        let persisted = try Self.fetchReminder(id: reminder.id, in: container)
        #expect(persisted?.triggerCount == 1)
        #expect(persisted?.totalNotificationsSent == 1)
    }

    @Test("A failed delivery remains eligible for a later retry")
    func failedDeliveryCanRetry() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let condition = TriggerCondition()
        let reminder = WeatherReminder(title: "Water plants", triggerCondition: condition)
        context.insert(reminder)
        try context.save()

        let sender = FailOnceTriggerNotificationSender()
        let manager = TriggerEngineManager(
            modelContainer: container,
            registerBackgroundTask: false,
            notificationManager: sender
        )
        let result = TriggerEvaluationResult(
            reminderId: reminder.id,
            conditionData: ModelDataConverter.convertTriggerCondition(condition),
            triggered: true,
            triggerReason: "Condition met"
        )

        await manager.processEvaluationResults([result])
        #expect(manager.triggeredReminders.isEmpty)
        #expect(try Self.fetchReminder(id: reminder.id, in: container)?.triggerCount == 0)

        await manager.processEvaluationResults([result])
        #expect(await sender.deliveryCount == 2)
        #expect(manager.triggeredReminders == [reminder.id])
        // Re-fetch: the trigger is persisted through the manager's own ModelContext.
        #expect(try Self.fetchReminder(id: reminder.id, in: container)?.triggerCount == 1)
    }

    /// Reads a reminder back through a fresh context, so assertions see persisted
    /// state rather than a stale instance from the context that inserted it.
    private static func fetchReminder(id: UUID, in container: ModelContainer) throws -> WeatherReminder? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WeatherReminder>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: SunHatModelSchema.schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: SunHatModelSchema.schema,
            configurations: [configuration]
        )
    }
}

private actor FailOnceTriggerNotificationSender: TriggerNotificationSending {
    private(set) var deliveryCount = 0

    func configure(modelContainer: ModelContainer?) async {}

    func sendTriggerNotification(
        for result: TriggerEvaluationResult,
        isBackground: Bool
    ) async throws {
        deliveryCount += 1
        if deliveryCount == 1 {
            throw WeatherError.allProvidersFailed
        }
    }
}

private actor GatedTriggerNotificationSender: TriggerNotificationSending {
    private(set) var hasStarted = false
    private(set) var deliveryCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func configure(modelContainer: ModelContainer?) async {}

    func sendTriggerNotification(
        for result: TriggerEvaluationResult,
        isBackground: Bool
    ) async throws {
        hasStarted = true
        deliveryCount += 1
        await withCheckedContinuation { continuation = $0 }
    }

    func finishDelivery() {
        continuation?.resume()
        continuation = nil
    }
}
