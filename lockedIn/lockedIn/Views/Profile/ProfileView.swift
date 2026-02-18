import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
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
                            isCurrentUser: true,
                            isFollowing: false,
                            onFollowTap: {}
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
                    }
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }

                        Divider()

                        Button(role: .destructive) {
                            authViewModel.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await viewModel.loadProfile(userId: nil)
            }
            .refreshable {
                await viewModel.loadProfile(userId: nil)
            }
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User
    let followersCount: Int
    let followingCount: Int
    let isCurrentUser: Bool
    let isFollowing: Bool
    let onFollowTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Profile Photo with Tier Ring
            TierAvatarView(
                photoURL: user.photoURL,
                displayName: user.displayName,
                tier: user.tier,
                size: Constants.UI.profileImageSize
            )

            // Name and Info
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(AppFonts.headline())

                // Tier Title
                TierTitleView(tier: user.tier)

                if let major = user.major, let year = user.year {
                    Text("\(year) • \(major)")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                } else if let major = user.major {
                    Text(major)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                } else if let year = user.year {
                    Text(year)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Followers/Following
            HStack(spacing: 32) {
                VStack {
                    Text("\(followersCount)")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Followers")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack {
                    Text("\(followingCount)")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Following")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Follow Button (for other users)
            if !isCurrentUser {
                Button(action: onFollowTap) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.headline)
                        .foregroundColor(isFollowing ? AppColors.textPrimary : AppColors.background)
                        .frame(width: 120, height: 36)
                        .background(isFollowing ? AppColors.surface : AppColors.gold)
                        .cornerRadius(18)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Stats")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                StatItem(
                    icon: "clock.fill",
                    value: user.formattedTotalTime,
                    label: "Total Time"
                )

                Spacer()

                StatItem(
                    icon: "flame.fill",
                    value: "\(user.totalFocusedSeconds / 3600)",
                    label: "Hours"
                )
            }
        }
        .cardStyle()
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.gold)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Spotify Card

struct SpotifyCard: View {
    let urlString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.greenLight)
                Text("Study Playlist")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
            }

            Link(destination: URL(string: urlString) ?? URL(string: "https://spotify.com")!) {
                HStack {
                    Text("Open in Spotify")
                        .font(AppFonts.body())
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundColor(AppColors.gold)
            }
        }
        .cardStyle()
    }
}

// MARK: - Study Tools Card

struct StudyToolsCard: View {
    let tools: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Tools")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            FlowLayout(spacing: 8) {
                ForEach(tools, id: \.self) { tool in
                    Text(tool)
                        .font(AppFonts.caption())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.gold.opacity(0.15))
                        .foregroundColor(AppColors.gold)
                        .cornerRadius(16)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Tips Card

struct TipsCard: View {
    let tips: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.gold)
                Text("Study Tips")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
            }

            Text(tips)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
        }
        .cardStyle()
    }
}

// MARK: - Recent Sessions Card

struct RecentSessionsCard: View {
    let sessions: [FocusSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            ForEach(sessions) { session in
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.formattedDuration)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Text(session.relativeTimeString)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    if session.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppColors.success)
                    }
                }
                .padding(.vertical, 4)

                if session.id != sessions.last?.id {
                    Divider()
                        .background(AppColors.borderSubtle)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button("Change Password") {
                        // TODO: Implement password change
                    }

                    Button("Change Email") {
                        // TODO: Implement email change
                    }
                }

                Section("Notifications") {
                    Toggle("Session Reminders", isOn: .constant(true))
                    Toggle("Leaderboard Updates", isOn: .constant(true))
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Delete Account", role: .destructive) {
                        // TODO: Implement account deletion
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
