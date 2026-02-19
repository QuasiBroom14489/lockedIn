import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedUserId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Tab Bar
                    LeaderboardTabBar(
                        selectedPeriod: $viewModel.selectedPeriod,
                        showFriendsOnly: $viewModel.showFriendsOnly
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(AppColors.gold)
                        Spacer()
                    } else if viewModel.entries.isEmpty {
                        Spacer()
                        EmptyLeaderboardView(showFriendsOnly: viewModel.showFriendsOnly)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                // Podium for Top 3
                                if viewModel.entries.count >= 3 {
                                    LeaderboardPodiumView(
                                        entries: Array(viewModel.entries.prefix(3)),
                                        onSelectUser: { userId in
                                            selectedUserId = userId
                                        }
                                    )
                                    .padding(.top, 24)
                                    .padding(.bottom, 16)
                                }

                                // List for remaining entries
                                let remainingEntries = viewModel.entries.count > 3
                                    ? Array(viewModel.entries.dropFirst(3))
                                    : (viewModel.entries.count < 3 ? viewModel.entries : [])

                                if !remainingEntries.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(remainingEntries) { entry in
                                            Button {
                                                selectedUserId = entry.userId
                                            } label: {
                                                LeaderboardListRow(
                                                    entry: entry,
                                                    isCurrentUser: entry.userId == AuthService.shared.currentUserId
                                                )
                                            }
                                            .buttonStyle(.plain)

                                            if entry.id != remainingEntries.last?.id {
                                                Divider()
                                                    .background(AppColors.border)
                                                    .padding(.leading, 72)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .background(AppColors.surface.opacity(0.5))
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await viewModel.loadLeaderboard()
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $selectedUserId) { userId in
                OtherUserProfileView(userId: userId)
            }
            .task {
                await viewModel.loadLeaderboard()
            }
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct LeaderboardTabBar: View {
    @Binding var selectedPeriod: LeaderboardPeriod
    @Binding var showFriendsOnly: Bool

    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Friends",
                isSelected: showFriendsOnly,
                action: { showFriendsOnly = true }
            )

            TabButton(
                title: "Weekly",
                isSelected: !showFriendsOnly && selectedPeriod == .weekly,
                action: {
                    showFriendsOnly = false
                    selectedPeriod = .weekly
                }
            )

            TabButton(
                title: "All Time",
                isSelected: !showFriendsOnly && selectedPeriod == .allTime,
                action: {
                    showFriendsOnly = false
                    selectedPeriod = .allTime
                }
            )
        }
        .padding(4)
        .background(AppColors.surface)
        .cornerRadius(12)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? AppColors.surfaceElevated
                        : Color.clear
                )
                .cornerRadius(8)
        }
    }
}

// MARK: - Podium View

struct LeaderboardPodiumView: View {
    let entries: [LeaderboardEntry]
    let onSelectUser: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 2nd Place (Left)
            if entries.count > 1 {
                PodiumUserView(
                    entry: entries[1],
                    rank: 2,
                    avatarSize: 70,
                    onTap: { onSelectUser(entries[1].userId) }
                )
            }

            // 1st Place (Center)
            if entries.count > 0 {
                PodiumUserView(
                    entry: entries[0],
                    rank: 1,
                    avatarSize: 90,
                    showCrown: true,
                    onTap: { onSelectUser(entries[0].userId) }
                )
            }

            // 3rd Place (Right)
            if entries.count > 2 {
                PodiumUserView(
                    entry: entries[2],
                    rank: 3,
                    avatarSize: 70,
                    onTap: { onSelectUser(entries[2].userId) }
                )
            }
        }
        .padding(.horizontal, 24)
    }
}

struct PodiumUserView: View {
    let entry: LeaderboardEntry
    let rank: Int
    let avatarSize: CGFloat
    var showCrown: Bool = false
    let onTap: () -> Void

    var rankColor: Color {
        switch rank {
        case 1: return AppColors.gold
        case 2: return Color(hex: "60A5FA") // Blue
        case 3: return AppColors.greenLight
        default: return AppColors.textSecondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Crown for 1st place
                if showCrown {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.gold)
                        .shadow(color: AppColors.gold.opacity(0.5), radius: 4)
                } else {
                    Spacer()
                        .frame(height: 24)
                }

                // Avatar with rank ring
                ZStack {
                    // Colored ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [rankColor, rankColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: avatarSize + 8, height: avatarSize + 8)
                        .shadow(color: rankColor.opacity(0.4), radius: 6)

                    // Avatar
                    if let photoURL = entry.photoURL, let url = URL(string: photoURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                avatarPlaceholder
                            @unknown default:
                                avatarPlaceholder
                            }
                        }
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }

                    // Rank badge
                    VStack {
                        Spacer()
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(rankColor)
                                    .frame(width: 24, height: 24)
                                    .shadow(color: rankColor.opacity(0.5), radius: 3)

                                Text("\(rank)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(rank == 1 ? AppColors.background : .white)
                            }
                            Spacer()
                        }
                    }
                    .frame(width: avatarSize + 8, height: avatarSize + 8)
                }

                // Name
                Text(entry.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                // Time/Points
                Text(entry.formattedTime)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(rankColor)

                // Username placeholder
                Text("@\(entry.displayName.lowercased().replacingOccurrences(of: " ", with: ""))")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(rankColor.opacity(0.2))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(entry.displayName.prefix(1).uppercased())
                    .font(.system(size: avatarSize * 0.35, weight: .semibold))
                    .foregroundColor(rankColor)
            )
    }
}

// MARK: - List Row

struct LeaderboardListRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with tier ring
            TierAvatarView(
                photoURL: entry.photoURL,
                displayName: entry.displayName,
                tier: entry.tier,
                size: 44,
                showAnimation: false
            )

            // Name and username
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCurrentUser ? AppColors.gold : AppColors.textPrimary)

                Text("@\(entry.displayName.lowercased().replacingOccurrences(of: " ", with: ""))")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // Time
            Text(entry.formattedTime)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.greenLight)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(isCurrentUser ? AppColors.gold.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Empty State

struct EmptyLeaderboardView: View {
    let showFriendsOnly: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(AppColors.goldMuted)

            Text("No Rankings Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(showFriendsOnly ?
                "Follow some friends to see them here" :
                "Complete focus sessions to appear on the leaderboard")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    LeaderboardView()
}

#Preview("Podium Only") {
    ZStack {
        AppColors.background.ignoresSafeArea()
        LeaderboardPodiumView(
            entries: LeaderboardEntry.previewList,
            onSelectUser: { _ in }
        )
    }
}
