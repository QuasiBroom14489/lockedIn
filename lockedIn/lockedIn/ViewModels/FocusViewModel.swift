import Foundation
import Combine
import SwiftUI

@MainActor
class FocusViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedDurationMinutes: Int = Constants.Session.defaultDurationMinutes
    @Published var remainingSeconds: Int = 0
    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var currentSession: FocusSession?
    @Published var recentSessions: [FocusSession] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSessionComplete = false

    @Published var completedSessionDuration: Int = 0

    // MARK: - Services

    let cameraService = CameraService()
    private let screenTimeService = ScreenTimeService.shared
    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared

    // MARK: - Private Properties

    private var timer: Timer?
    private var sessionStartTime: Date?
    private var lifecycleObservers: [Any] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var timerDisplay: String {
        remainingSeconds.formattedAsTime
    }

    var progress: Double {
        let total = Double(selectedDurationMinutes * 60)
        let elapsed = total - Double(remainingSeconds)
        return total > 0 ? elapsed / total : 0
    }

    var durationOptions: [Int] {
        [15, 25, 30, 45, 60, 90, 120]
    }

    // MARK: - Initialization

    init() {
        setupLifecycleMonitoring()
    }

    deinit {
        // Note: deinit is nonisolated and cannot access @MainActor state.
        // Cleanup that touches actor-isolated properties must happen elsewhere on the main actor.
    }

    // MARK: - Session Control

    func startSession() async {
        guard let userId = authService.currentUserId else {
            showError(message: "You must be signed in to start a session")
            return
        }

        // Setup camera
        cameraService.setupSession()
        cameraService.startSession()

        // Start screen time blocking (if authorized)
        if screenTimeService.isAuthorized {
            screenTimeService.startBlocking()
        }

        // Create session
        let session = FocusSession(
            userId: userId,
            startTime: Date(),
            durationSeconds: selectedDurationMinutes * 60,
            verified: true
        )

        do {
            let sessionId = try await firebaseService.createSession(session, userId: userId)
            var newSession = session
            newSession.id = sessionId
            currentSession = newSession
        } catch {
            handleError(error)
            return
        }

        sessionStartTime = Date()
        remainingSeconds = selectedDurationMinutes * 60
        isSessionActive = true
        isPaused = false

        startTimer()
    }

    func pauseSession() {
        isPaused = true
        stopTimer()
    }

    func resumeSession() {
        isPaused = false
        startTimer()
    }

    func endSession(early: Bool = false) async {
        stopTimer()
        cameraService.stopSession()
        screenTimeService.stopBlocking()

        guard let session = currentSession,
              let userId = authService.currentUserId else {
            isSessionActive = false
            return
        }

        let elapsed = (selectedDurationMinutes * 60) - remainingSeconds
        let finalDuration = max(elapsed, Constants.Session.minimumDurationSeconds)

        // Only count if session meets minimum duration
        let isValid = elapsed >= Constants.Session.minimumDurationSeconds

        var completedSession = session
        completedSession.endTime = Date()
        completedSession.durationSeconds = isValid ? finalDuration : 0
        completedSession.verified = isValid && !early
        completedSession.completedAt = Date()

        do {
            try await firebaseService.updateSession(completedSession, userId: userId)

            if isValid {
                // Update user's total focused time
                if var user = try await firebaseService.getUser(id: userId) {
                    user.totalFocusedSeconds += finalDuration
                    user.updatedAt = Date()
                    try await firebaseService.updateUser(user)
                }

                completedSessionDuration = finalDuration
                showSessionComplete = true
            }
        } catch {
            handleError(error)
        }

        currentSession = nil
        isSessionActive = false
        remainingSeconds = 0
    }

    // MARK: - Timer Management

    private func startTimer() {
        let timer = Timer.scheduledTimer(timeInterval: 1.0,
                                         target: self,
                                         selector: #selector(timerFired(_:)),
                                         userInfo: nil,
                                         repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func timerFired(_ timer: Timer) {
        // We're on the main run loop; FocusViewModel is @MainActor, so this is safe.
        timerTick()
    }

    private func timerTick() {
        guard !isPaused else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            Task { @MainActor in
                await endSession(early: false)
            }
        }
    }

    // MARK: - Lifecycle Monitoring

    private func setupLifecycleMonitoring() {
        lifecycleObservers = screenTimeService.setupAppLifecycleMonitoring(
            onBackground: { [weak self] in
                Task { @MainActor in
                    self?.handleAppBackgrounded()
                }
            },
            onForeground: { [weak self] in
                Task { @MainActor in
                    self?.handleAppForegrounded()
                }
            }
        )
    }

    private func handleAppBackgrounded() {
        guard isSessionActive else { return }

        // If Screen Time blocking is not enabled, pause the session
        if !screenTimeService.isBlocking {
            pauseSession()
            showError(message: "Session paused. Return to the app to continue.")
        }
    }

    private func handleAppForegrounded() {
        // Session continues if user returns
    }

    // MARK: - Session History

    func loadRecentSessions() async {
        guard let userId = authService.currentUserId else { return }

        isLoading = true

        do {
            recentSessions = try await firebaseService.getSessions(userId: userId, limit: 20)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
