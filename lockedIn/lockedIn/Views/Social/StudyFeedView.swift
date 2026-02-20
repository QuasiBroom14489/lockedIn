import SwiftUI
import UIKit

struct StudyFeedView: View {
    let selectedTab: Int

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
                    feedSkeleton
                } else if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    feedContent
                }
            }
            .navigationTitle("Study Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
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
            .onChange(of: selectedTab) { _, newValue in
                guard newValue == 2 else { return }
                Task {
                    await viewModel.refreshFeed()
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "No additional error details available.")
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
            VStack(spacing: 14) {
                feedControls

                PostsListView(
                    posts: viewModel.posts,
                    voteForPost: { post in
                        viewModel.userVotes[post.id ?? ""] ?? .none
                    },
                    isFavoritedPost: { post in
                        viewModel.favoritePostIds.contains(post.id ?? "")
                    },
                    onAuthorTap: { post in
                        selectedAuthorId = post.authorId
                    },
                    onUpvote: { post in
                        Task { await viewModel.toggleUpvote(post: post) }
                    },
                    onDownvote: { post in
                        Task { await viewModel.toggleDownvote(post: post) }
                    },
                    onFavorite: { post in
                        Task { await viewModel.toggleFavorite(post: post) }
                    },
                    onShare: { post in
                        shareText = shareText(for: post)
                        showingShareSheet = true
                    },
                    onPostAppear: { post in
                        Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
                    }
                )

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

    private var feedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            sortPicker
            postTypeFilterChips
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.surface.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
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

    private var postTypeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StudyFeedPostFilter.allCases, id: \.self) { filter in
                    let isSelected = viewModel.postFilter == filter
                    Button {
                        Task { await viewModel.setPostFilter(filter) }
                    } label: {
                        Text(filter.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(isSelected ? AppColors.background : AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? AppColors.gold : AppColors.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .font(.system(size: 38))
                .foregroundColor(AppColors.goldMuted)

            Text("No Study Posts Yet")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Be the first to share a study stack or tip with other students.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button("Create Post") {
                showingComposer = true
            }
            .primaryButtonStyle()
            .padding(.horizontal, 28)
        }
    }

    private var feedSkeleton: some View {
        ScrollView {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface.opacity(0.7))
                    .frame(height: 88)

                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Constants.UI.postCardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.surfaceElevated.opacity(0.9), AppColors.surface.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: Constants.UI.postCardCornerRadius)
                                .stroke(AppColors.borderSubtle, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    StudyFeedView(selectedTab: 2)
}
