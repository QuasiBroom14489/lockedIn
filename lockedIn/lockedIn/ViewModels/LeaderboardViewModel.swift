import Foundation
import Combine
import FirebaseFirestore

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var selectedPeriod: LeaderboardPeriod = .weekly
    @Published var showFriendsOnly = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var currentUserRank: Int?
    @Published var currentUserEntry: LeaderboardEntry?

    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared
    private let analyticsService = AnalyticsService.shared
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    deinit {
        listener?.remove()
    }

    private func setupBindings() {
        // Reload and restart listener when period changes
        $selectedPeriod
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.loadLeaderboard()
                    self?.startListening()
                }
            }
            .store(in: &cancellables)

        // Reload and restart listener when friends filter changes
        $showFriendsOnly
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.loadLeaderboard()
                    self?.startListening()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Leaderboard

    func loadLeaderboard() async {
        isLoading = true

        do {
            if showFriendsOnly, let userId = authService.currentUserId {
                entries = try await firebaseService.getFriendsLeaderboard(userId: userId, period: selectedPeriod)
            } else {
                entries = try await firebaseService.getLeaderboard(limit: 100, period: selectedPeriod)
            }

            updateCurrentUserRank()
            analyticsService.logLeaderboardViewed(period: selectedPeriod.rawValue, showFriendsOnly: showFriendsOnly)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Real-time Updates

    func startListening() {
        listener?.remove()

        // Real-time listener only works for allTime since it queries totalFocusedSeconds
        // For weekly/monthly, we rely on manual refresh
        guard selectedPeriod == .allTime && !showFriendsOnly else {
            listener = nil
            return
        }

        listener = firebaseService.addLeaderboardListener(limit: 100) { [weak self] entries in
            Task { @MainActor in
                guard let self = self else { return }
                // Only update if still on allTime and not friends-only
                if self.selectedPeriod == .allTime && !self.showFriendsOnly {
                    self.entries = entries
                    self.updateCurrentUserRank()
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Current User

    private func updateCurrentUserRank() {
        guard let userId = authService.currentUserId else {
            currentUserRank = nil
            currentUserEntry = nil
            return
        }

        if let index = entries.firstIndex(where: { $0.userId == userId }) {
            currentUserRank = index + 1
            currentUserEntry = entries[index]
        } else {
            currentUserRank = nil
            currentUserEntry = nil
        }
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - Leaderboard Row View Model

struct LeaderboardRowData: Identifiable {
    let id: String
    let rank: Int
    let displayName: String
    let photoURL: String?
    let totalTime: String
    let isCurrentUser: Bool

    init(entry: LeaderboardEntry, currentUserId: String?) {
        self.id = entry.userId
        self.rank = entry.rank
        self.displayName = entry.displayName
        self.photoURL = entry.photoURL
        self.totalTime = entry.formattedTime
        self.isCurrentUser = entry.userId == currentUserId
    }
}
