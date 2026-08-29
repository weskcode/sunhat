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
        }
        .modelContainer(sharedModelContainer)
    }
}

@MainActor
final class StoreRecoveryState: ObservableObject {
    static let shared = StoreRecoveryState()

    @Published private(set) var recoveryMessage: String?

    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "StoreRecovery")

    private init() {}

    nonisolated func reportPersistentStoreFailure(_ error: Error) {
        let message = String(localized: "SunHat repaired a local data store issue and preserved the previous store for recovery.", comment: "Banner shown after the local database was quarantined and recreated")
        logger.error("Persistent store creation failed: \(error.localizedDescription)")
        Task { @MainActor in
            recoveryMessage = message
        }
    }

    nonisolated func reportRecoveryFailure(_ error: Error) {
        let message = String(localized: "SunHat is running in temporary recovery mode, changes made now will NOT be saved after you close the app. Contact support@sunhat.app for help recovering your data.", comment: "Banner shown when the app is running on a temporary in-memory database")
        logger.error("Persistent store recovery failed: \(error.localizedDescription)")
        Task { @MainActor in
            recoveryMessage = message
        }
    }

    nonisolated func reportQuarantineFailure(_ error: Error) {
        logger.error("Failed to quarantine persistent store: \(error.localizedDescription)")
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
