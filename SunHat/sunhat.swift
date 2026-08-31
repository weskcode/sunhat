//
//  SunHatApp.swift
//  SunHat
//
//  Created by Wesley Keetch on 7/20/25.
//

import SwiftUI
import SwiftData
import UIKit
import Combine
import os
@preconcurrency import UserNotifications

final class SunHatAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        SunHatNotificationCategoryRegistry.register(center: center)
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await TriggerNotificationManager.shared.handleNotificationResponse(response)
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct SunHatApp: App {
    @UIApplicationDelegateAdaptor(SunHatAppDelegate.self) private var appDelegate
    @StateObject private var storeRecoveryState = StoreRecoveryState.shared
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        Self.prepareSharedStoreDirectory()

        let schema = SunHatModelSchema.schema
        // CloudKit sync is disabled for now - can be re-enabled in the future
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.org.wesley.sunhat"),
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            StoreRecoveryState.shared.reportPersistentStoreFailure(error)
            Self.quarantineSharedStore()

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                StoreRecoveryState.shared.reportRecoveryFailure(error)

                let fallbackConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )

                do {
                    return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                } catch {
                    preconditionFailure("Could not create fallback in-memory ModelContainer: \(error)")
                }
            }
        }
    }()

    /// True only when XCTest is loaded INTO this process (unit tests hosted
    /// in the app). Deliberately not an environment-variable check: UI-test
    /// runs also inject XCTest* env vars into the app under test, which must
    /// behave like production.
    private static var isHostingUnitTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    private static func prepareSharedStoreDirectory() {
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.org.wesley.sunhat"
        ) else {
            return
        }

        let applicationSupportURL = appGroupURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )
    }

    private static func quarantineSharedStore() {
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.org.wesley.sunhat"
        ) else {
            return
        }

        let applicationSupportURL = appGroupURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        let quarantineURL = applicationSupportURL
            .appendingPathComponent("Store Recovery", isDirectory: true)
            .appendingPathComponent(Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)), isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: quarantineURL, withIntermediateDirectories: true)
            let storeFiles = try FileManager.default.contentsOfDirectory(
                at: applicationSupportURL,
                includingPropertiesForKeys: nil
            )
            .filter { url in
                let name = url.lastPathComponent
                return name.hasSuffix(".store") ||
                    name.hasSuffix(".sqlite") ||
                    name.hasSuffix(".sqlite-shm") ||
                    name.hasSuffix(".sqlite-wal")
            }

            for url in storeFiles {
                try FileManager.default.moveItem(
                    at: url,
                    to: quarantineURL.appendingPathComponent(url.lastPathComponent)
                )
            }
        } catch {
            StoreRecoveryState.shared.reportQuarantineFailure(error)
        }
    }

    init() {
        let container = sharedModelContainer
        BackgroundWeatherManager.shared.configure(modelContainer: container)

        // Unit tests replace the App Store with a local SKTestSession; starting
        // the live Transaction.updates listener at launch would bind this
        // process to the real App Store environment before a test session can
        // take over, so the tests drive StoreManager instances directly instead.
        if !Self.isHostingUnitTests {
            StoreManager.shared.start()
            // Ad SDK activation is entitlement-gated inside AdManager: it only
            // starts Google Mobile Ads once StoreKit affirmatively resolves
            // that the user is not Ad-Free, and re-evaluates on changes.
            AdManager.shared.activate()
        }

        Task {
            // Configure the weather service before any background refresh can run,
            // so BackgroundWeatherManager's refresh path never hits an unconfigured actor.
            await WeatherService.shared.configure(modelContainer: container)
            await TriggerEngineManager.shared.configure(modelContainer: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .safeAreaInset(edge: .top) {
                    if let message = storeRecoveryState.recoveryMessage {
                        StoreRecoveryBanner(message: message)
                    }
                }
                .environment(StoreManager.shared)
                .task {
                    // onChange(of: scenePhase) never fires for the INITIAL
                    // value, and the scene is usually already .active by the
                    // first body evaluation — capture it here or ATT/consent
                    // presentation would wait for a background/foreground
                    // round-trip.
                    guard !Self.isHostingUnitTests else { return }
                    AdManager.shared.sceneDidChange(active: scenePhase == .active)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard !Self.isHostingUnitTests else { return }
                    // AdManager tracks real scene activity: ATT may only be
                    // requested while active.
                    AdManager.shared.sceneDidChange(active: newPhase == .active)
                    // Grace/billing/cancel transitions that land while the app
                    // is suspended produce no Transaction.updates event, so
                    // re-derive entitlement on each return to foreground; the
                    // entitlement change re-triggers ad evaluation on its own.
                    if newPhase == .active {
                        Task { await StoreManager.shared.refreshEntitlement() }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

/// How degraded the persistent store is. `.storeRepaired` means a fresh real
/// store replaced a corrupted one (writes persist normally, informational
/// only); `.inMemoryFallback` means the app is running on a throwaway
/// in-memory container (writes vanish at termination) and must not let the
/// user create or edit data without warning.
enum StoreRecoveryLevel: Equatable {
    case none
    case storeRepaired
    case inMemoryFallback
}

@MainActor
final class StoreRecoveryState: ObservableObject {
    static let shared = StoreRecoveryState()

    @Published private(set) var recoveryMessage: String?
    @Published private(set) var level: StoreRecoveryLevel = .none

    /// True when a save made right now will not survive app termination.
    /// Creation and edit flows must check this before persisting.
    var isWriteUnsafe: Bool { level == .inMemoryFallback }

    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "StoreRecovery")

    private init() {}

    nonisolated func reportPersistentStoreFailure(_ error: Error) {
        let message = String(localized: "SunHat repaired a local data store issue and preserved the previous store for recovery.", comment: "Banner shown after the local database was quarantined and recreated")
        logger.error("Persistent store creation failed: \(error.localizedDescription)")
        Task { @MainActor in
            recoveryMessage = message
            level = .storeRepaired
        }
    }

    nonisolated func reportRecoveryFailure(_ error: Error) {
        let message = String(localized: "SunHat couldn't load your data and is running in temporary recovery mode. Creating and editing reminders is disabled until this is fixed. Restart SunHat to try again, or contact support@sunhat.app for help.", comment: "Banner shown when the app is running on a temporary in-memory database")
        logger.error("Persistent store recovery failed: \(error.localizedDescription)")
        Task { @MainActor in
            recoveryMessage = message
            level = .inMemoryFallback
        }
    }

    nonisolated func reportQuarantineFailure(_ error: Error) {
        logger.error("Failed to quarantine persistent store: \(error.localizedDescription)")
    }

    /// Restores normal operation. Production code never calls this, since
    /// ModelContainer degradation only happens once at app launch and isn't
    /// expected to self-heal within a running process; exists so tests that
    /// exercise a degraded state can clean up this process-wide singleton
    /// afterward instead of leaking it into unrelated tests.
    func resetForTesting() {
        recoveryMessage = nil
        level = .none
    }

    /// Test support: sets the level directly and synchronously. Production
    /// code always goes through reportPersistentStoreFailure/
    /// reportRecoveryFailure instead, which are nonisolated and hop via Task
    /// because their real caller (the ModelContainer init closure) isn't
    /// MainActor-isolated; tests exercising gating behavior don't need that
    /// hop and would otherwise race it.
    func setLevelForTesting(_ level: StoreRecoveryLevel) {
        self.level = level
    }
}

private struct StoreRecoveryBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.18))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Data recovery notice. \(message)")
    }
}
