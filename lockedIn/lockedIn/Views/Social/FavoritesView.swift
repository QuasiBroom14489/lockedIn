import SwiftUI
import UIKit
import Combine

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @State private var selectedAuthorId: String?
    @State private var shareText = ""
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.gold)
                } else if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.posts) { post in
                                StudyPostRow(
                                    post: post,
                                    currentVote: viewModel.userVotes[post.id ?? ""] ?? .none,
                                    isFavorited: true,
                                    onAuthorTap: {
                                        selectedAuthorId = post.authorId
                                    },
                                    onUpvote: {
                                        Task { await viewModel.toggleUpvote(post: post) }
                                    },
                                    onDownvote: {
                                        Task { await viewModel.toggleDownvote(post: post) }
                                    },
                                    onFavorite: {
                                        Task { await viewModel.unfavorite(post: post) }
                                    },
                                    onShare: {
                                        shareText = shareText(for: post)
                                        showingShareSheet = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .refreshable {
                        await viewModel.loadFavorites()
                    }
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $selectedAuthorId) { userId in
                OtherUserProfileView(userId: userId)
            }
            .task {
                await viewModel.loadFavorites()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred.")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 44))
                .foregroundColor(AppColors.goldMuted)

            Text("No Saved Posts")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Save study tips and stacks from the feed to find them here later.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private func shareText(for post: StudyPost) -> String {
        var text = "\(post.title)\n\n\(post.content)\n\nShared from lockedIn"
        if !post.tags.isEmpty {
            text += "\n#\(post.tags.joined(separator: " #"))"
        }
        return text
    }
}

@MainActor
private class FavoritesViewModel: ObservableObject {
    @Published var posts: [StudyPost] = []
    @Published var userVotes: [String: VoteType] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared

    func loadFavorites() async {
        guard let userId = authService.currentUserId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let favorites = try await firebaseService.getFavorites(forUserId: userId, limit: 300)
            let favoritePostIds = favorites.map(\.postId)
            var loadedPosts: [StudyPost] = []
            loadedPosts.reserveCapacity(favoritePostIds.count)

            for postId in favoritePostIds {
                if let post = try await firebaseService.getStudyPost(id: postId) {
                    loadedPosts.append(post)
                }
            }

            posts = loadedPosts

            userVotes = [:]
            for post in posts {
                guard let postId = post.id else { continue }
                userVotes[postId] = try await firebaseService.getVote(postId: postId, userId: userId)
            }
        } catch {
            handleError(error)
        }
    }

    func toggleUpvote(post: StudyPost) async {
        await toggleVote(post: post, desired: .upvote)
    }

    func toggleDownvote(post: StudyPost) async {
        await toggleVote(post: post, desired: .downvote)
    }

    func unfavorite(post: StudyPost) async {
        guard let userId = authService.currentUserId, let postId = post.id else { return }

        do {
            try await firebaseService.setFavorite(postId: postId, userId: userId, isFavorite: false)
            posts.removeAll { $0.id == postId }
        } catch {
            handleError(error)
        }
    }

    private func toggleVote(post: StudyPost, desired: VoteType) async {
        guard let userId = authService.currentUserId, let postId = post.id else { return }

        let currentVote = userVotes[postId] ?? .none
        let newVote: VoteType = (currentVote == desired) ? .none : desired

        do {
            try await firebaseService.setVote(postId: postId, userId: userId, type: newVote)
            userVotes[postId] = newVote
            applyVoteDelta(postId: postId, from: currentVote, to: newVote)
        } catch {
            handleError(error)
        }
    }

    private func applyVoteDelta(postId: String, from oldVote: VoteType, to newVote: VoteType) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        var post = posts[index]
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

        post.upvoteCount = max(0, post.upvoteCount + upvoteDelta)
        post.downvoteCount = max(0, post.downvoteCount + downvoteDelta)
        post.hotScore += Double(upvoteDelta - downvoteDelta)
        posts[index] = post
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FavoritesView()
}
