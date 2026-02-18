import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine
import UIKit

@MainActor
class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()

    @Published var isAuthorized = false
    @Published var isBlocking = false
    @Published var error: ScreenTimeError?

    private let authorizationCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()

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

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time access not authorized. Please enable in Settings."
        case .authorizationFailed(let message):
            return "Failed to authorize Screen Time: \(message)"
        case .blockingFailed(let message):
            return "Failed to block apps: \(message)"
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

