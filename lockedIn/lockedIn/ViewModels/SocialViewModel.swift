import Foundation
import Combine

@MainActor
class SocialViewModel: ObservableObject {
    @Published var feedItems: [FeedItem] = []
    @Published var searchResults: [User] = []
    @Published var followers: [User] = []
    @Published var following: [User] = []

    @Published var searchQuery = ""

    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Feed

    func loadFeed() async {
        guard let currentUserId = authService.currentUserId else { return }

        isLoading = true

        do {
            let followingIds = try await firebaseService.getFollowing(userId: currentUserId)

            guard !followingIds.isEmpty else {
                feedItems = []
                isLoading = false
                return
            }

            // Fetch recent sessions from all followed users
            var allItems: [FeedItem] = []

            for userId in followingIds {
                if let user = try await firebaseService.getUser(id: userId) {
                    let sessions = try await firebaseService.getSessions(userId: userId, limit: 5)
                    let items = sessions.map { FeedItem(session: $0, user: user) }
                    allItems.append(contentsOf: items)
                }
            }

            // Sort by most recent
            feedItems = allItems.sorted { item1, item2 in
                let date1 = item1.session.completedAt ?? item1.session.startTime
                let date2 = item2.session.completedAt ?? item2.session.startTime
                return date1 > date2
            }

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Search

    private func performSearch(query: String) async {
        let trimmed = query.trimmed

        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            searchResults = try await firebaseService.searchUsers(query: trimmed)

            // Filter out current user
            if let currentUserId = authService.currentUserId {
                searchResults = searchResults.filter { $0.id != currentUserId }
            }
        } catch {
            handleError(error)
        }

        isSearching = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Followers/Following Lists

    func loadFollowers(userId: String) async {
        isLoading = true

        do {
            let followerIds = try await firebaseService.getFollowers(userId: userId)
            followers = []

            for id in followerIds {
                if let user = try await firebaseService.getUser(id: id) {
                    followers.append(user)
                }
            }

            // Sort by name
            followers.sort { $0.displayName < $1.displayName }

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func loadFollowing(userId: String) async {
        isLoading = true

        do {
            let followingIds = try await firebaseService.getFollowing(userId: userId)
            following = []

            for id in followingIds {
                if let user = try await firebaseService.getUser(id: id) {
                    following.append(user)
                }
            }

            // Sort by name
            following.sort { $0.displayName < $1.displayName }

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Follow Actions

    func follow(userId: String) async {
        guard let currentUserId = authService.currentUserId else { return }

        do {
            try await firebaseService.followUser(currentUserId: currentUserId, targetUserId: userId)

            // Update local state if needed
            _ = searchResults.contains { $0.id == userId }
        } catch {
            handleError(error)
        }
    }

    func unfollow(userId: String) async {
        guard let currentUserId = authService.currentUserId else { return }

        do {
            try await firebaseService.unfollowUser(currentUserId: currentUserId, targetUserId: userId)
        } catch {
            handleError(error)
        }
    }

    func isFollowing(userId: String) async -> Bool {
        guard let currentUserId = authService.currentUserId else { return false }

        do {
            return try await firebaseService.isFollowing(currentUserId: currentUserId, targetUserId: userId)
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
