import SwiftUI

struct OtherUserProfileView: View {
    let userId: String
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedClassForDetail: ProfileClassItem?
    @State private var selectedAuthorId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let user = viewModel.user {
                    ProfileHeaderView(
                        user: user,
                        followersCount: viewModel.followersCount,
                        followingCount: viewModel.followingCount,
                        isCurrentUser: false,
                        isFollowing: viewModel.isFollowing,
                        onFollowTap: {
                            Task {
                                await viewModel.toggleFollow()
                            }
                        }
                    )

                    Picker("Profile Section", selection: $viewModel.selectedTab) {
                        Text(ProfileTab.overview.rawValue).tag(ProfileTab.overview)
                        Text(ProfileTab.classes.rawValue).tag(ProfileTab.classes)
                        Text(ProfileTab.posts.rawValue).tag(ProfileTab.posts)
                    }
                    .pickerStyle(.segmented)

                    contentForSelectedTab(user: user)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("User not found")
                            .font(AppFonts.headline())
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding()
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(viewModel.user?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedAuthorId) { authorId in
            OtherUserProfileView(userId: authorId)
        }
        .sheet(item: $selectedClassForDetail) { item in
            ClassDetailSheetView(
                item: item,
                isEditable: false,
                dashboard: viewModel.classDashboard,
                isLoadingDashboard: viewModel.isLoadingClassDashboard,
                classErrorMessage: viewModel.classErrorMessage,
                period: viewModel.classPeriod,
                userPosts: viewModel.classUserPosts,
                isLoadingUserPosts: viewModel.isLoadingClassPosts,
                isValidSpotifyURL: { FirebaseService.shared.isValidSpotifyURL($0) },
                onPeriodChanged: { period in
                    viewModel.classPeriod = period
                    Task { await viewModel.loadGlobalClassDashboard(classId: item.global.id, period: period) }
                },
                onRefreshDashboard: {
                    Task { await viewModel.loadGlobalClassDashboard(classId: item.global.id, period: viewModel.classPeriod) }
                },
                onSave: { _ in},
                onDelete: nil
            )
        }
        .task {
            await viewModel.loadProfile(userId: userId)
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            Task {
                switch newTab {
                case .overview:
                    break
                case .classes:
                    await viewModel.loadClassItems(userId: userId)
                case .posts:
                    await viewModel.loadUserPosts(userId: userId)
                case .saved:
                    break
                }
            }
        }
        .refreshable {
            await viewModel.loadProfile(userId: userId)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    @ViewBuilder
    private func contentForSelectedTab(user: User) -> some View {
        switch viewModel.selectedTab {
        case .overview:
            VStack(spacing: 24) {
                StatsCard(user: user)

                if user.screenTimeVisibilityEnabled {
                    ScreenTimeCard(user: user, isCurrentUser: false)
                }

                TierProgressCard(points: user.points, tier: user.tier)

                if let spotifyURL = user.spotifyPlaylistURL, !spotifyURL.isEmpty {
                    SpotifyCard(urlString: spotifyURL)
                }

                let mainTools = user.primaryStudyTools.isEmpty ? user.studyTools : user.primaryStudyTools
                if !mainTools.isEmpty {
                    StudyToolsCard(title: "Main Stack / Study Tools", tools: mainTools)
                }

                if !user.studyTools.isEmpty {
                    StudyToolsCard(title: "All Study Tools", tools: user.studyTools)
                }

                if let tips = user.tips, !tips.isEmpty {
                    TipsCard(tips: tips)
                }

                if !viewModel.recentSessions.isEmpty {
                    RecentSessionsCard(sessions: viewModel.recentSessions)
                }
            }
        case .classes:
            VStack(alignment: .leading, spacing: 12) {
                Text("Classes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)

                if viewModel.classItems.isEmpty {
                    EmptyPostsState(
                        title: "No Classes Shared",
                        message: "This user has not added classes yet."
                    )
                } else {
                    ForEach(viewModel.classItems, id: \.id) { item in
                        Button {
                            selectedClassForDetail = item
                        } label: {
                            ClassSummaryCard(item: item, dashboard: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .posts:
            VStack(alignment: .leading, spacing: 12) {
                Text("Posts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)

                if viewModel.userPosts.isEmpty {
                    EmptyPostsState(
                        title: "No Posts Yet",
                        message: "No posts available for this profile."
                    )
                } else {
                    PostsListView(
                        posts: viewModel.userPosts,
                        onAuthorTap: { post in
                            selectedAuthorId = post.authorId
                        }
                    )
                }
            }
        case .saved:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        OtherUserProfileView(userId: "preview-user-id")
    }
}
