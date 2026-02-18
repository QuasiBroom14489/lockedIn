import SwiftUI

struct OtherUserProfileView: View {
    let userId: String
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let user = viewModel.user {
                    // Profile Header
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

                    // Stats Card
                    StatsCard(user: user)

                    // Tier Progress
                    TierProgressCard(points: user.points, tier: user.tier)

                    // Spotify Playlist
                    if let spotifyURL = user.spotifyPlaylistURL, !spotifyURL.isEmpty {
                        SpotifyCard(urlString: spotifyURL)
                    }

                    // Study Tools
                    if !user.studyTools.isEmpty {
                        StudyToolsCard(tools: user.studyTools)
                    }

                    // Tips
                    if let tips = user.tips, !tips.isEmpty {
                        TipsCard(tips: tips)
                    }

                    // Recent Sessions
                    if !viewModel.recentSessions.isEmpty {
                        RecentSessionsCard(sessions: viewModel.recentSessions)
                    }
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.user?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(userId: userId)
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
}

#Preview {
    NavigationStack {
        OtherUserProfileView(userId: "preview-user-id")
    }
}
