import SwiftUI
import UIKit

struct StudyFeedView: View {
    @StateObject private var viewModel = StudyFeedViewModel()
    @State private var selectedAuthorId: String?
    @State private var showingComposer = false

    @State private var shareText = ""
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .tint(AppColors.gold)
                } else if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    feedContent
                }
            }
            .navigationTitle("Study Feed")
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(AppColors.gold)
                    }
                }
            }
            .navigationDestination(item: $selectedAuthorId) { userId in
                OtherUserProfileView(userId: userId)
            }
            .task {
                await viewModel.loadInitialFeed()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred.")
            }
            .sheet(isPresented: $showingComposer) {
                SharePostSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
        }
    }

    private var feedContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                sortPicker

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.posts) { post in
                        StudyPostRow(
                            post: post,
                            currentVote: viewModel.userVotes[post.id ?? ""] ?? .none,
                            isFavorited: viewModel.favoritePostIds.contains(post.id ?? ""),
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
                                Task { await viewModel.toggleFavorite(post: post) }
                            },
                            onShare: {
                                shareText = shareText(for: post)
                                showingShareSheet = true
                            }
                        )
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(AppColors.gold)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await viewModel.refreshFeed()
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $viewModel.sortOption) {
            ForEach(StudyFeedSortOption.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.sortOption) { _, newValue in
            Task {
                await viewModel.setSortOption(newValue)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("☘")
                .font(.system(size: 44))
                .foregroundColor(AppColors.greenMuted)

            Text("No Study Posts Yet")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Be the first to share a study stack or tip with other students.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button("Share Your First Post") {
                showingComposer = true
            }
            .primaryButtonStyle()
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

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    StudyFeedView()
}
