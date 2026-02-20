import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedUserId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.background, AppColors.backgroundSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .ambientBackgroundLayer()

                VStack(spacing: 12) {
                    topHeader

                    LeaderboardTabBar(
                        selectedPeriod: $viewModel.selectedPeriod,
                        showFriendsOnly: $viewModel.showFriendsOnly
                    )
                    .focusCardStyle()

                    if viewModel.isLoading {
                        LeaderboardSkeletonView()
                    } else if viewModel.entries.isEmpty {
                        Spacer()
                        EmptyLeaderboardView(showFriendsOnly: viewModel.showFriendsOnly)
                            .focusCardStyle()
                            .padding(.horizontal, 16)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                if viewModel.didAutoFallbackToAllTime {
                                    HStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(AppColors.gold)
                                        Text(viewModel.fallbackMessage ?? "No data for current filter yet. Showing All Time.")
                                            .font(AppFonts.caption())
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppColors.surface.opacity(0.85))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                                    )
                                }

                                if viewModel.entries.count >= 3 {
                                    LeaderboardPodiumView(
                                        entries: Array(viewModel.entries.prefix(3)),
                                        onSelectUser: { userId in
                                            selectedUserId = userId
                                        }
                                    )
                                    .focusCardStyle()
                                }

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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(AppColors.surface.opacity(0.78))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await viewModel.loadLeaderboard()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
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

    private var topHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundColor(AppColors.gold)
            Text("Leaderboard")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            Spacer(minLength: 0)
        }
        .focusCardStyle()
        .padding(.horizontal, 16)
    }
}

// MARK: - Custom Tab Bar

struct LeaderboardTabBar: View {
    @Binding var selectedPeriod: LeaderboardPeriod
    @Binding var showFriendsOnly: Bool

    var body: some View {
        HStack(spacing: 8) {
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
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? AppColors.background : AppColors.textSecondary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.gold : AppColors.surface.opacity(0.85))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading Skeleton

struct LeaderboardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface.opacity(0.72))
                    .frame(height: 188)

                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.surface.opacity(0.72))
                        .frame(height: 72)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Podium View

struct LeaderboardPodiumView: View {
    let entries: [LeaderboardEntry]
    let onSelectUser: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if entries.count > 1 {
                PodiumUserView(
                    entry: entries[1],
                    rank: 2,
                    avatarSize: 70,
                    onTap: { onSelectUser(entries[1].userId) }
                )
            }

            if entries.count > 0 {
                PodiumUserView(
                    entry: entries[0],
                    rank: 1,
                    avatarSize: 90,
                    showCrown: true,
                    onTap: { onSelectUser(entries[0].userId) }
                )
            }

            if entries.count > 2 {
                PodiumUserView(
                    entry: entries[2],
                    rank: 3,
                    avatarSize: 70,
                    onTap: { onSelectUser(entries[2].userId) }
                )
            }
        }
        .padding(.horizontal, 8)
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
        case 2: return Color(hex: "60A5FA")
        case 3: return AppColors.greenLight
        default: return AppColors.textSecondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if showCrown {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.gold)
                        .shadow(color: AppColors.gold.opacity(0.45), radius: 4)
                } else {
                    Spacer().frame(height: 22)
                }

                ZStack {
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

                    VStack {
                        Spacer()
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(rankColor)
                                    .frame(width: 24, height: 24)
                                Text("\(rank)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(rank == 1 ? AppColors.background : .white)
                            }
                            Spacer()
                        }
                    }
                    .frame(width: avatarSize + 8, height: avatarSize + 8)
                }

                Text(entry.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(entry.formattedTime)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(rankColor)

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
            TierAvatarView(
                photoURL: entry.photoURL,
                displayName: entry.displayName,
                tier: entry.tier,
                size: 44,
                showAnimation: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCurrentUser ? AppColors.gold : AppColors.textPrimary)

                Text("@\(entry.displayName.lowercased().replacingOccurrences(of: " ", with: ""))")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Text(entry.formattedTime)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.greenLight)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(isCurrentUser ? AppColors.gold.opacity(0.1) : Color.clear)
        .cornerRadius(10)
    }
}

// MARK: - Empty State

struct EmptyLeaderboardView: View {
    let showFriendsOnly: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 42))
                .foregroundColor(AppColors.goldMuted)

            Text("No Rankings Yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)

            Text(showFriendsOnly
                 ? "Follow some friends to see them here."
                 : "Complete focus sessions to appear on the leaderboard.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
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
        .focusCardStyle()
        .padding()
    }
}
