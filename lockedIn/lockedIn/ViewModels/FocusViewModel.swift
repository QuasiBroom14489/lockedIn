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
    @Published var currentTip: String = Constants.Session.focusTips.first ?? "Stay focused."
    @Published var audioState: FocusAudioState = .disconnected
    @Published var showMusicControls = true
    @Published var musicWarningMessage: String?
    @Published var isMusicConnecting = false

    // MARK: - Services

    private let screenTimeService = ScreenTimeService.shared
    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared
    private let notificationService = NotificationService.shared
    private let analyticsService = AnalyticsService.shared
    private let musicService: MusicPlaybackService

    // MARK: - Private Properties

    private var timer: Timer?
    private var tipTimer: Timer?
    private var sessionStartTime: Date?
    private var lifecycleObservers: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var isEndingSession = false
    private var currentTipIndex = 0

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

    init(musicService: MusicPlaybackService = SpotifyPlaybackService.shared) {
        self.musicService = musicService
        self.musicService.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.audioState = state
            }
        }
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

        // Non-blocking permission check so a background end can notify users.
        await notificationService.requestAuthorizationIfNeeded()

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
        startTipRotation()
        await connectMusicIfNeeded()

        analyticsService.logFocusSessionStarted(durationGoal: selectedDurationMinutes * 60)
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
        guard !isEndingSession else { return }
        isEndingSession = true
        defer { isEndingSession = false }

        stopTimer()
        stopTipRotation()
        screenTimeService.stopBlocking()
        musicService.disconnect()
        audioState = .disconnected

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

        var pointsEarned = 0

        do {
            try await firebaseService.updateSession(completedSession, userId: userId)

            // Update user's totals and points with screen-time bonus.
            if var user = try await firebaseService.getUser(id: userId) {
                user.totalFocusedSeconds += finalDuration

                let basePoints = finalDuration / 60
                let screenTimeBonus = calculateScreenTimeBonus(user: user)
                pointsEarned = max(Int((Double(basePoints) * screenTimeBonus).rounded()), 0)
                user.points += pointsEarned

                user.updatedAt = Date()
                try await firebaseService.updateUser(user)
            }

            completedSessionDuration = finalDuration
            showSessionComplete = true

            analyticsService.logFocusSessionCompleted(durationSeconds: finalDuration, pointsEarned: pointsEarned)
        } catch {
            handleError(error)
        }

        currentSession = nil
        isSessionActive = false
        remainingSeconds = 0
    }

    private func calculateScreenTimeBonus(user: User) -> Double {
        let nonProductive = user.dailyNonProductiveMinutes
        let total = max(user.dailyProductiveMinutes + user.dailyNonProductiveMinutes, 1)
        let productiveRatio = Double(user.dailyProductiveMinutes) / Double(total)

        let baseBonus: Double
        switch nonProductive {
        case ..<60:
            baseBonus = 1.30
        case 60..<120:
            baseBonus = 1.15
        case 120..<180:
            baseBonus = 1.00
        case 180..<240:
            baseBonus = 0.90
        default:
            baseBonus = 0.80
        }

        let ratioAdjustment = productiveRatio >= 0.70 ? 0.10 : (productiveRatio >= 0.50 ? 0.05 : 0.0)
        return min(baseBonus + ratioAdjustment, 1.50)
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

    private func startTipRotation() {
        guard !Constants.Session.focusTips.isEmpty else { return }

        currentTipIndex = Int.random(in: 0..<Constants.Session.focusTips.count)
        currentTip = Constants.Session.focusTips[currentTipIndex]

        tipTimer?.invalidate()
        let timer = Timer(timeInterval: Constants.Session.tipRotationInterval,
                          target: self,
                          selector: #selector(tipTimerFired(_:)),
                          userInfo: nil,
                          repeats: true)
        tipTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTipRotation() {
        tipTimer?.invalidate()
        tipTimer = nil
    }

    private func advanceTip() {
        guard !Constants.Session.focusTips.isEmpty else { return }
        currentTipIndex = (currentTipIndex + 1) % Constants.Session.focusTips.count
        currentTip = Constants.Session.focusTips[currentTipIndex]
        analyticsService.logFocusTipDisplayed(tipIndex: currentTipIndex)
        analyticsService.logFocusTipTransitionRendered()
    }

    @objc private func tipTimerFired(_ timer: Timer) {
        // We're on the main run loop; FocusViewModel is @MainActor, so this is safe.
        advanceTip()
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
                    await self?.handleAppBackgrounded()
                }
            },
            onForeground: { [weak self] in
                Task { @MainActor in
                    self?.handleAppForegrounded()
                }
            }
        )
    }

    private func handleAppBackgrounded() async {
        guard isSessionActive else { return }

        let elapsed = max((selectedDurationMinutes * 60) - remainingSeconds, 0)
        await endSession(early: true)
        await notificationService.sendFocusSessionEndedInBackgroundNotification(focusedSeconds: elapsed)
        analyticsService.logFocusSessionEndedBackground(durationSeconds: elapsed)
        showError(message: "Session ended because you left the app.")
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

    // MARK: - Music Controls

    func connectMusicIfNeeded() async {
        guard isSessionActive, showMusicControls else { return }

        isMusicConnecting = true
        musicWarningMessage = nil
        analyticsService.logFocusMusicConnectStarted()

        do {
            try await musicService.connect()
            await musicService.refreshState()
            analyticsService.logFocusMusicConnectSucceeded()
        } catch {
            let message = error.localizedDescription
            musicWarningMessage = message
            analyticsService.logFocusMusicConnectFailed(message: message)
        }

        isMusicConnecting = false
    }

    func togglePlayPause() async {
        do {
            analyticsService.logFocusMusicControlTap(action: "play_pause")
            try await musicService.playPause()
            await musicService.refreshState()
        } catch {
            musicWarningMessage = error.localizedDescription
        }
    }

    func skipNext() async {
        do {
            analyticsService.logFocusMusicControlTap(action: "next")
            try await musicService.nextTrack()
            await musicService.refreshState()
        } catch {
            musicWarningMessage = error.localizedDescription
        }
    }

    func skipPrevious() async {
        do {
            analyticsService.logFocusMusicControlTap(action: "previous")
            try await musicService.previousTrack()
            await musicService.refreshState()
        } catch {
            musicWarningMessage = error.localizedDescription
        }
    }

    func updateVolume(_ value: Double) async {
        do {
            analyticsService.logFocusMusicControlTap(action: "volume")
            try await musicService.setVolume(value)
            await musicService.refreshState()
        } catch {
            musicWarningMessage = error.localizedDescription
        }
    }

    func seekForward() async {
        do {
            analyticsService.logFocusMusicControlTap(action: "seek")
            try await musicService.seekForward()
            await musicService.refreshState()
        } catch {
            handleBlockedExternalMusicAction(action: "seek", message: error.localizedDescription)
        }
    }

    func openQueue() async {
        do {
            analyticsService.logFocusMusicControlTap(action: "queue")
            try await musicService.openQueue()
            await musicService.refreshState()
        } catch {
            handleBlockedExternalMusicAction(action: "queue", message: error.localizedDescription)
        }
    }

    func clearMusicWarning() {
        musicWarningMessage = nil
    }

    func handleBlockedExternalMusicAction(action: String, message: String = "This action would leave lockedIn and break focus. Use in-app controls only.") {
        musicWarningMessage = message
        analyticsService.logFocusMusicActionBlockedExternal(action: action)
    }
}
