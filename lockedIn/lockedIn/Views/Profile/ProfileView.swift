import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedAuthorId: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.background)
                } else if let user = viewModel.user {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Profile Header
                            ProfileHeaderView(
                                user: user,
                                followersCount: viewModel.followersCount,
                                followingCount: viewModel.followingCount,
                                isCurrentUser: true,
                                isFollowing: false,
                                onFollowTap: {}
                            )

                            Picker("Profile Section", selection: $viewModel.selectedTab) {
                                ForEach(ProfileTab.allCases, id: \.self) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)

                            contentForSelectedTab(user: user)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Profile unavailable",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                    .background(AppColors.background)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationDestination(item: $selectedAuthorId) { userId in
                OtherUserProfileView(userId: userId)
            }
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

    @ViewBuilder
    private func contentForSelectedTab(user: User) -> some View {
        switch viewModel.selectedTab {
        case .overview:
            overviewContent(user: user)
        case .posts:
            postsContent
        case .saved:
            savedContent
        }
    }

    @ViewBuilder
    private func overviewContent(user: User) -> some View {
        VStack(spacing: 24) {
            StatsCard(user: user)

            if user.screenTimeVisibilityEnabled || viewModel.isCurrentUser {
                ScreenTimeCard(user: user, isCurrentUser: viewModel.isCurrentUser)
            }

            TierProgressCard(points: user.points, tier: user.tier)

            if let spotifyURL = user.spotifyPlaylistURL, !spotifyURL.isEmpty {
                SpotifyCard(urlString: spotifyURL)
            }

            if !user.studyTools.isEmpty {
                StudyToolsCard(tools: user.studyTools)
            }

            if let tips = user.tips, !tips.isEmpty {
                TipsCard(tips: tips)
            }

            if !viewModel.recentSessions.isEmpty {
                RecentSessionsCard(sessions: viewModel.recentSessions)
            }
        }
    }

    @ViewBuilder
    private var postsContent: some View {
        if viewModel.userPosts.isEmpty {
            EmptyPostsState(
                title: "No Posts Yet",
                message: "Share your first stack or suggestion to build your profile."
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

    @ViewBuilder
    private var savedContent: some View {
        if viewModel.savedPosts.isEmpty {
            EmptyPostsState(
                title: "No Saved Posts",
                message: "Save useful stacks and tips to revisit them here."
            )
        } else {
            PostsListView(
                posts: viewModel.savedPosts,
                isFavoritedPost: { _ in true },
                onAuthorTap: { post in
                    selectedAuthorId = post.authorId
                }
            )
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

// MARK: - Screen Time Card

struct ScreenTimeCard: View {
    let user: User
    var isCurrentUser: Bool = true

    private var productiveMinutes: Int {
        max(user.dailyProductiveMinutes, 0)
    }

    private var nonProductiveMinutes: Int {
        max(user.dailyNonProductiveMinutes, 0)
    }

    private var totalMinutes: Int {
        productiveMinutes + nonProductiveMinutes
    }

    private var productiveRatio: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(productiveMinutes) / Double(totalMinutes)
    }

    private var nonProductiveRatio: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(nonProductiveMinutes) / Double(totalMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screen Time")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if let updatedAt = user.screenTimeUpdatedAt {
                    Text("Updated \(updatedAt.timeAgoString())")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            if totalMinutes == 0 {
                Text("No screen time data available yet.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(spacing: 10) {
                    GeometryReader { geometry in
                        let productiveWidth = geometry.size.width * productiveRatio
                        let nonProductiveWidth = geometry.size.width * nonProductiveRatio

                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.success)
                                .frame(width: productiveWidth)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.warning)
                                .frame(width: nonProductiveWidth)
                        }
                        .frame(height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 12)

                    HStack(spacing: 12) {
                        LegendItem(
                            color: AppColors.success,
                            title: "Productive",
                            value: "\(productiveMinutes)m"
                        )

                        Spacer()

                        LegendItem(
                            color: AppColors.warning,
                            title: "Non-Productive",
                            value: "\(nonProductiveMinutes)m"
                        )
                    }
                }
            }

            if isCurrentUser && !user.screenTimeVisibilityEnabled {
                Text("Your screen time is hidden from other users.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .cardStyle()
    }
}

private struct LegendItem: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

private struct EmptyPostsState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary)

            Text(title)
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text(message)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .cardStyle()
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
                    Button("Sign Out", role: .destructive) {
                        authViewModel.signOut()
                        dismiss()
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
