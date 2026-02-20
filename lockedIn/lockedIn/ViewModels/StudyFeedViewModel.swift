import Foundation
import Combine

enum StudyFeedSortOption: String, CaseIterable {
    case hot
    case recent
    case top

    var displayName: String {
        switch self {
        case .hot: return "Hot"
        case .recent: return "Recent"
        case .top: return "Top"
        }
    }
}

enum StudyFeedPostFilter: String, CaseIterable {
    case all
    case stacks
    case suggestions

    var displayName: String {
        switch self {
        case .all: return "All"
        case .stacks: return "Stacks"
        case .suggestions: return "Suggestions"
        }
    }
}

@MainActor
class StudyFeedViewModel: ObservableObject {
    @Published var posts: [StudyPost] = []
    @Published var sortOption: StudyFeedSortOption = .hot
    @Published var postFilter: StudyFeedPostFilter = .all

    @Published var userVotes: [String: VoteType] = [:]
    @Published var favoritePostIds = Set<String>()

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSubmittingPost = false
    @Published var hasMorePages = false

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var softDiagnostics: [String] = []

    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared
    private let analyticsService = AnalyticsService.shared

    private var allPosts: [StudyPost] = []
    private var postChunks: [[StudyPost]] = []
    private var currentPage = 0
    private let pageSize = 20

    // MARK: - Feed Loading

    func loadInitialFeed() async {
        isLoading = true
        defer { isLoading = false }

        do {
            allPosts = try await firebaseService.getStudyPosts(limit: 200)
            rebuildFeedPages()
            await loadInteractionState(for: posts)
        } catch {
            handleError(error)
        }
    }

    func refreshFeed() async {
        do {
            allPosts = try await firebaseService.getStudyPosts(limit: 200)
            rebuildFeedPages()
            await loadInteractionState(for: posts)
        } catch {
            handleError(error)
        }
    }

    func setSortOption(_ option: StudyFeedSortOption) async {
        // Value already set by Picker binding, just rebuild
        rebuildFeedPages()
        await loadInteractionState(for: posts)
    }

    func setPostFilter(_ filter: StudyFeedPostFilter) async {
        guard postFilter != filter else { return }
        postFilter = filter
        rebuildFeedPages()
        await loadInteractionState(for: posts)
    }

    func loadMoreIfNeeded(currentPost: StudyPost) async {
        guard hasMorePages, !isLoadingMore, let postId = currentPost.id else { return }
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        let triggerIndex = max(posts.count - 5, 0)
        guard index >= triggerIndex else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard currentPage < postChunks.count else {
            hasMorePages = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextChunk = postChunks[currentPage]
        posts.append(contentsOf: nextChunk)
        currentPage += 1
        hasMorePages = currentPage < postChunks.count

        await loadInteractionState(for: nextChunk)
    }

    private func rebuildFeedPages() {
        let filteredPosts = filtered(allPosts, by: postFilter)
        let sortedPosts = sorted(filteredPosts, by: sortOption)
        postChunks = sortedPosts.chunked(into: pageSize)

        posts = []
        currentPage = 0
        hasMorePages = !postChunks.isEmpty

        if hasMorePages {
            let firstPage = postChunks[0]
            posts = firstPage
            currentPage = 1
            hasMorePages = currentPage < postChunks.count
        }
    }

    private func sorted(_ posts: [StudyPost], by option: StudyFeedSortOption) -> [StudyPost] {
        switch option {
        case .hot:
            return posts.sorted { lhs, rhs in
                if lhs.hotScore == rhs.hotScore {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.hotScore > rhs.hotScore
            }
        case .recent:
            return posts.sorted { $0.createdAt > $1.createdAt }
        case .top:
            return posts.sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.score > rhs.score
            }
        }
    }

    private func filtered(_ posts: [StudyPost], by filter: StudyFeedPostFilter) -> [StudyPost] {
        switch filter {
        case .all:
            return posts
        case .stacks:
            return posts.filter { $0.type == .stack }
        case .suggestions:
            return posts.filter { $0.type == .tip }
        }
    }

    // MARK: - Interaction State

    private func loadInteractionState(for feedPosts: [StudyPost]) async {
        guard let userId = authService.currentUserId else { return }

        for post in feedPosts {
            guard let postId = post.id else { continue }

            if userVotes[postId] == nil {
                do {
                    userVotes[postId] = try await firebaseService.getVote(postId: postId, userId: userId)
                } catch {
                    userVotes[postId] = .none
                    recordSoftDiagnostic(
                        operation: "interaction_state_vote_lookup",
                        postId: postId,
                        error: error
                    )
                }
            }

            if !favoritePostIds.contains(postId) {
                do {
                    let isFavorited = try await firebaseService.isFavorited(postId: postId, userId: userId)
                    if isFavorited {
                        favoritePostIds.insert(postId)
                    }
                } catch {
                    recordSoftDiagnostic(
                        operation: "interaction_state_favorite_lookup",
                        postId: postId,
                        error: error
                    )
                }
            }
        }
    }

    // MARK: - Voting

    func toggleUpvote(post: StudyPost) async {
        await updateVote(for: post, desired: .upvote)
    }

    func toggleDownvote(post: StudyPost) async {
        await updateVote(for: post, desired: .downvote)
    }

    private func updateVote(for post: StudyPost, desired: VoteType) async {
        guard let userId = authService.currentUserId, let postId = post.id else { return }

        let currentVote = userVotes[postId] ?? .none
        let newVote: VoteType = (currentVote == desired) ? .none : desired

        do {
            try await firebaseService.setVote(postId: postId, userId: userId, type: newVote)
            userVotes[postId] = newVote
            applyVoteChangeLocally(postId: postId, from: currentVote, to: newVote)
            analyticsService.logVote(postId: postId, voteType: newVote.rawValue)
        } catch {
            showError(
                message: "Vote action failed. operation=\(desired.rawValue) postId=\(postId) reason=\(error.localizedDescription)"
            )
        }
    }

    private func applyVoteChangeLocally(postId: String, from oldVote: VoteType, to newVote: VoteType) {
        let upvoteDelta: Int
        let downvoteDelta: Int

        switch (oldVote, newVote) {
        case (.none, .upvote): upvoteDelta = 1; downvoteDelta = 0
        case (.none, .downvote): upvoteDelta = 0; downvoteDelta = 1
        case (.upvote, .none): upvoteDelta = -1; downvoteDelta = 0
        case (.downvote, .none): upvoteDelta = 0; downvoteDelta = -1
        case (.upvote, .downvote): upvoteDelta = -1; downvoteDelta = 1
        case (.downvote, .upvote): upvoteDelta = 1; downvoteDelta = -1
        default: upvoteDelta = 0; downvoteDelta = 0
        }

        updatePostLocally(postId: postId) { post in
            post.upvoteCount = max(0, post.upvoteCount + upvoteDelta)
            post.downvoteCount = max(0, post.downvoteCount + downvoteDelta)
            post.hotScore += Double(upvoteDelta - downvoteDelta)
            post.updatedAt = Date()
        }
    }

    // MARK: - Favorites

    func toggleFavorite(post: StudyPost) async {
        guard let userId = authService.currentUserId, let postId = post.id else { return }

        let currentlyFavorited = favoritePostIds.contains(postId)
        let newState = !currentlyFavorited

        do {
            try await firebaseService.setFavorite(postId: postId, userId: userId, isFavorite: newState)

            if newState {
                favoritePostIds.insert(postId)
            } else {
                favoritePostIds.remove(postId)
            }

            updatePostLocally(postId: postId) { post in
                let delta = newState ? 1 : -1
                post.favoriteCount = max(0, post.favoriteCount + delta)
                post.updatedAt = Date()
            }

            analyticsService.logFavoriteToggled(postId: postId, isFavorited: newState)
        } catch {
            showError(
                message: "Favorite action failed. operation=favorite postId=\(postId) reason=\(error.localizedDescription)"
            )
        }
    }

    // MARK: - Create/Delete Post

    func createPost(
        type: StudyPostType,
        title: String,
        content: String,
        stackItems: [StudyStackItem]? = nil,
        tools: [String],
        tags: [String],
        classKeys: [String] = []
    ) async {
        guard let currentUserId = authService.currentUserId else {
            showError(message: "You must be signed in to create a post.")
            return
        }

        isSubmittingPost = true
        defer { isSubmittingPost = false }

        do {
            for classKey in classKeys.map({ GlobalClass.normalizedId(from: $0) }).filter(\.isNotEmpty) {
                try await firebaseService.joinClass(userId: currentUserId, classId: classKey)
            }

            let uniqueTools = Set(
                (stackItems?.map(\.toolName) ?? tools)
                    .map(\.trimmed)
                    .filter(\.isNotEmpty)
            )
            for toolName in uniqueTools {
                let canonicalTool = try await firebaseService.createGlobalToolIfNeeded(
                    displayName: toolName,
                    category: nil,
                    createdByUserId: currentUserId
                )
                try await firebaseService.incrementToolUsage(toolId: canonicalTool.id)
            }

            let user = try await firebaseService.getUser(id: currentUserId)
            let newPost = StudyPost(
                authorId: currentUserId,
                authorName: user?.displayName ?? "Student",
                authorPhotoURL: user?.photoURL,
                type: type,
                title: title.trimmed,
                content: content.trimmed,
                stackItems: stackItems,
                tools: tools,
                tags: tags.map(\.trimmed).filter(\.isNotEmpty),
                classKeys: classKeys.map { GlobalClass.normalizedId(from: $0) }.filter(\.isNotEmpty)
            )

            _ = try await firebaseService.createStudyPost(newPost)
            await refreshFeed()

            analyticsService.logPostCreated(
                type: type.rawValue,
                toolCount: stackItems?.count ?? tools.count,
                tagCount: tags.count
            )
        } catch {
            handleError(error)
        }
    }

    func deletePost(_ post: StudyPost) async {
        guard let postId = post.id else { return }

        do {
            try await firebaseService.deleteStudyPost(postId: postId)
            allPosts.removeAll { $0.id == postId }
            posts.removeAll { $0.id == postId }
            userVotes.removeValue(forKey: postId)
            favoritePostIds.remove(postId)
            rebuildFeedPages()
            await loadInteractionState(for: posts)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Helpers

    private func updatePostLocally(postId: String, update: (inout StudyPost) -> Void) {
        if let allIndex = allPosts.firstIndex(where: { $0.id == postId }) {
            var post = allPosts[allIndex]
            update(&post)
            allPosts[allIndex] = post
        }

        if let visibleIndex = posts.firstIndex(where: { $0.id == postId }) {
            var post = posts[visibleIndex]
            update(&post)
            posts[visibleIndex] = post
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private func recordSoftDiagnostic(operation: String, postId: String, error: Error) {
        let message = "Soft diagnostic. operation=\(operation) postId=\(postId) reason=\(error.localizedDescription)"
        print(message)
        softDiagnostics.append(message)

        if softDiagnostics.count > 100 {
            softDiagnostics.removeFirst(softDiagnostics.count - 100)
        }
    }

    func clearErrorState() {
        errorMessage = nil
        showError = false
    }
}
