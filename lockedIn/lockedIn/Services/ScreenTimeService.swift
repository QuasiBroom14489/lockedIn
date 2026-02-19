import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine
import UIKit

struct ScreenTimeMetrics: Codable {
    var productiveMinutes: Int
    var nonProductiveMinutes: Int
    var totalMinutes: Int
    var lastUpdated: Date

    static var empty: ScreenTimeMetrics {
        ScreenTimeMetrics(
            productiveMinutes: 0,
            nonProductiveMinutes: 0,
            totalMinutes: 0,
            lastUpdated: Date()
        )
    }
}

enum AppProductivityCategory {
    case productive
    case nonProductive
}

@MainActor
class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()

    @Published var isAuthorized = false
    @Published var isBlocking = false
    @Published var error: ScreenTimeError?

    private let authorizationCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()
    private let metricsDefaultsKey = "screen_time_metrics_cache_v1"
    private static let activityName = DeviceActivityName("com.zanejohnson.lockedIn.daily")

    // Initial category map for future scoring logic. Expand over time.
    private let productiveBundleIds: Set<String> = [
        "com.apple.MobileSMS", // Messaging can be productive for study coordination
        "com.apple.mobilenotes",
        "com.apple.Pages",
        "com.apple.Keynote",
        "com.apple.Numbers",
        "com.notion.id",
        "com.ankiapp.ios"
    ]

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch authorizationCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
        case .denied:
            isAuthorized = false
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            self.error = .authorizationFailed(error.localizedDescription)
            isAuthorized = false
        }
    }

    // MARK: - App Blocking

    func startBlocking() {
        guard isAuthorized else {
            error = .notAuthorized
            return
        }

        // This SDK expects specific token sets to shield. Use `startBlocking(using:)`
        // with a FamilyActivitySelection obtained from the Family Controls picker.
        self.error = .blockingFailed("No activity selection provided. Use startBlocking(using:) with a FamilyActivitySelection.")
    }

    func startBlocking(using selection: FamilyActivitySelection) {
        guard isAuthorized else {
            error = .notAuthorized
            return
        }

        // Apply the selected tokens to shield apps, categories, and web domains.
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
        isBlocking = true
    }

    func stopBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        isBlocking = false
    }

    // MARK: - Device Activity + Metrics

    func startDeviceActivityMonitoring() async throws {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try activityCenter.startMonitoring(Self.activityName, during: schedule)
        } catch {
            let mapped = ScreenTimeError.monitoringFailed(error.localizedDescription)
            self.error = mapped
            throw mapped
        }
    }

    func fetchScreenTimeMetrics() async throws -> ScreenTimeMetrics {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }

        // Full per-app usage attribution requires a Device Activity Report extension.
        // Until that layer is added, return cached values so profile/reward features can ship.
        if let cached = loadCachedMetrics() {
            return cached
        }

        let empty = ScreenTimeMetrics.empty
        cacheMetrics(empty)
        return empty
    }

    func cacheMetrics(_ metrics: ScreenTimeMetrics) {
        guard let encoded = try? JSONEncoder().encode(metrics) else { return }
        UserDefaults.standard.set(encoded, forKey: metricsDefaultsKey)
    }

    func categorizeApp(bundleIdentifier: String) -> AppProductivityCategory {
        productiveBundleIds.contains(bundleIdentifier) ? .productive : .nonProductive
    }

    private func loadCachedMetrics() -> ScreenTimeMetrics? {
        guard let data = UserDefaults.standard.data(forKey: metricsDefaultsKey),
              let metrics = try? JSONDecoder().decode(ScreenTimeMetrics.self, from: data) else {
            return nil
        }
        return metrics
    }

    // MARK: - Alternative: App Lifecycle Detection

    // For devices without Screen Time API access, we can detect app backgrounding
    func setupAppLifecycleMonitoring(onBackground: @escaping () -> Void, onForeground: @escaping () -> Void) -> [Any] {
        var observers: [Any] = []

        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            onBackground()
        }
        observers.append(backgroundObserver)

        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            onForeground()
        }
        observers.append(foregroundObserver)

        return observers
    }

    func removeAppLifecycleMonitoring(observers: [Any]) {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Errors

enum ScreenTimeError: LocalizedError {
    case notAuthorized
    case authorizationFailed(String)
    case blockingFailed(String)
    case monitoringFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time access not authorized. Please enable in Settings."
        case .authorizationFailed(let message):
            return "Failed to authorize Screen Time: \(message)"
        case .blockingFailed(let message):
            return "Failed to block apps: \(message)"
        case .monitoringFailed(let message):
            return "Failed to start device activity monitoring: \(message)"
        }
    }
}

// MARK: - Shield Configuration (for customizing blocked app screen)

import SwiftUI

struct FocusShieldView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.navyBlue)

            Text("Focus Session Active")
                .font(AppFonts.headline())
                .foregroundColor(.primary)

            Text("Stay focused! Your session is in progress.")
                .font(AppFonts.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onUnlock) {
                Text("End Session Early")
                    .secondaryButtonStyle()
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .padding()
    }
}
