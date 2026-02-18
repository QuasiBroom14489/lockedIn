import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedUserId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Period Selector
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Friends Toggle
                Toggle(isOn: $viewModel.showFriendsOnly) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Friends Only")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Current User Rank Banner
                if let entry = viewModel.currentUserEntry, let rank = viewModel.currentUserRank {
                    CurrentUserRankBanner(entry: entry, rank: rank)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Leaderboard List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.entries.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Rankings Yet",
                        systemImage: "trophy",
                        description: Text(viewModel.showFriendsOnly ?
                            "Follow some friends to see them here" :
                            "Complete focus sessions to appear on the leaderboard")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.entries) { entry in
                            Button {
                                selectedUserId = entry.userId
                            } label: {
                                LeaderboardRow(
                                    entry: entry,
                                    isCurrentUser: entry.userId == AuthService.shared.currentUserId
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Leaderboard")
            .navigationDestination(item: $selectedUserId) { userId in
                OtherUserProfileView(userId: userId)
            }
            .task {
                await viewModel.loadLeaderboard()
            }
            .refreshable {
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

// MARK: - Current User Rank Banner

struct CurrentUserRankBanner: View {
    let entry: LeaderboardEntry
    let rank: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Rank")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.background.opacity(0.8))
                Text("#\(rank)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.background)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Total Time")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.background.opacity(0.8))
                Text(entry.formattedTime)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.background)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppColors.gold, AppColors.goldLight],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(Constants.UI.cornerRadius)
        .goldGlow(radius: 8, opacity: 0.3)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            RankBadge(rank: entry.rank)

            // Profile Photo with Tier Ring
            TierAvatarView(
                photoURL: entry.photoURL,
                displayName: entry.displayName,
                tier: entry.tier,
                size: Constants.UI.leaderboardRowImageSize
            )

            // Name and Tier
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? AppColors.gold : AppColors.textPrimary)

                HStack(spacing: 4) {
                    if isCurrentUser {
                        Text("You")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.gold)
                        Text("•")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    TierBadgeView(tier: entry.tier, style: .compact)
                }
            }

            Spacer()

            // Time
            Text(entry.formattedTime)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 4)
        .background(isCurrentUser ? AppColors.gold.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Rank Badge

struct RankBadge: View {
    let rank: Int

    var body: some View {
        ZStack {
            if rank <= 3 {
                Circle()
                    .fill(medalColor)
                    .frame(width: 32, height: 32)
                    .shadow(color: medalColor.opacity(0.4), radius: 6, x: 0, y: 0)

                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.background)
            } else {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32)
            }
        }
    }

    var medalColor: Color {
        switch rank {
        case 1: return AppColors.gold
        case 2: return Color(hex: "9CA3AF") // Silver
        case 3: return Color(hex: "8B7355") // Bronze
        default: return Color.clear
        }
    }
}

#Preview {
    LeaderboardView()
}
