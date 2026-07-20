//
//  DataPrivacyViewModelTests.swift
//  SunHatTests
//

import Foundation
import SwiftData
import Testing
@testable import SunHat

@MainActor
struct DataPrivacyViewModelTests {
    @Test("Data summary reads from the injected model context")
    func dataSummaryReadsInjectedContext() async throws {
        let context = try makeInMemoryContext()
        let reminder = WeatherReminder(title: "Water plants")
        context.insert(reminder)
        try context.save()

        let viewModel = DataPrivacyViewModel()
        viewModel.configure(modelContext: context)
        await viewModel.loadDataSummary()

        #expect(viewModel.dataSummary?.reminderCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Data operations fail loudly when no context is configured")
    func missingContextSurfacesError() async {
        let viewModel = DataPrivacyViewModel()

        await viewModel.loadDataSummary()

        #expect(viewModel.errorMessage?.isEmpty == false)
        #expect(viewModel.dataSummary == nil)
    }

    @Test("Delete all removes every persisted type, including saved locations and history")
    func deleteAllRemovesEverything() async throws {
        let context = try makeInMemoryContext()
        insertOneOfEachPrivacyModel(in: context)
        try context.save()

        let viewModel = DataPrivacyViewModel()
        viewModel.configure(modelContext: context)
        viewModel.deleteConfirmationText = "DELETE"
        await viewModel.deleteAllUserData()

        #expect(viewModel.errorMessage == nil)
        #expect(try context.fetch(FetchDescriptor<WeatherReminder>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TriggerCondition>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LocationData>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WeatherData>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ForecastDay>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<NotificationConfig>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ReminderHistory>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserPreferences>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SavedLocation>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LocationHistory>()).isEmpty)
    }

    @Test("Delete all is a no-op without typed confirmation")
    func deleteAllRequiresConfirmation() async throws {
        let context = try makeInMemoryContext()
        context.insert(WeatherReminder(title: "Bring umbrella"))
        try context.save()

        let viewModel = DataPrivacyViewModel()
        viewModel.configure(modelContext: context)
        viewModel.deleteConfirmationText = "nope"
        await viewModel.deleteAllUserData()

        #expect(try context.fetch(FetchDescriptor<WeatherReminder>()).count == 1)
    }

    @Test("Privacy coverage lists match the app SwiftData schema")
    func privacyCoverageListsMatchSchema() {
        #expect(DataPrivacyViewModel.privacyDeletedModelTypeNames == SunHatModelSchema.modelTypeNames)
        #expect(DataPrivacyViewModel.privacyExportedModelTypeNames == SunHatModelSchema.modelTypeNames)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = SunHatModelSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func insertOneOfEachPrivacyModel(in context: ModelContext) {
        context.insert(WeatherReminder(title: "Wear sunscreen"))
        context.insert(TriggerCondition())
        context.insert(LocationData(latitude: 40.0, longitude: -111.0, city: "Home"))
        context.insert(WeatherData(temperature: 75, feelsLike: 75, humidity: 30))
        context.insert(ForecastDay(date: Date(), highTemperature: 80, lowTemperature: 55))
        context.insert(NotificationConfig())
        context.insert(ReminderHistory())
        context.insert(UserPreferences())
        context.insert(SavedLocation(latitude: 40.0, longitude: -111.0, name: "Home"))
        context.insert(LocationHistory(latitude: 40.2, longitude: -111.7, name: "Provo"))
    }
}
