//
//  BackgroundWeatherManagerTests.swift
//  SunHatTests
//

import Foundation
import Testing
@testable import SunHat

/// Serialized because they exercise the shared singleton's registration and
/// scheduling state.
@MainActor
@Suite(.serialized)
struct BackgroundWeatherManagerTests {
    @Test("Duplicate background task registration is ignored instead of crashing")
    func duplicateRegistrationIsIgnored() {
        let manager = BackgroundWeatherManager.shared

        // The singleton registers in init, so it is already registered by the
        // time any test touches it.
        #expect(manager.isBackgroundTaskRegistered == true)

        // A second registration must be a no-op — without the guard this
        // raises NSInternalInconsistencyException inside BGTaskScheduler.
        #expect(manager.registerBackgroundTask() == false)
        #expect(manager.registerBackgroundTask() == false)
        #expect(manager.isBackgroundTaskRegistered == true)
    }

    @Test("Scheduling falls back gracefully when background refresh is unavailable")
    func unavailableBackgroundRefreshFallsBack() {
        let manager = BackgroundWeatherManager.shared
        let originalAvailability = manager.isBackgroundRefreshEnabled
        defer { manager.isBackgroundRefreshEnabled = originalAvailability }

        manager.isBackgroundRefreshEnabled = false

        // No request is submitted and no error is thrown — the app simply
        // relies on foreground refresh.
        #expect(manager.scheduleBackgroundRefresh() == false)
    }
}
