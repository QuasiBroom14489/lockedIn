import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var selectedUserId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.feedItems.isEmpty {
                    EmptyFeedView()
                } else {
                    List {
                        ForEach(viewModel.feedItems) { item in
                            Button {
                                selectedUserId = item.user.id
                            } label: {
                                FeedItemRow(item: item)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(AppColors.background)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Activity")
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SearchUsersView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(item: $selectedUserId) { userId in
                OtherUserProfileView(userId: userId)
            }
            .task {
                await viewModel.loadFeed()
            }
            .refreshable {
                await viewModel.loadFeed()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Empty Feed View

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Clover as empty state placeholder
            Text("☘")
                .font(.system(size: 48))
                .foregroundColor(AppColors.greenMuted)

            VStack(spacing: 8) {
                Text("No Activity Yet")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)

                Text("Follow other students to see their focus sessions here")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            NavigationLink {
                SearchUsersView(viewModel: SocialViewModel())
            } label: {
                Text("Find People to Follow")
            }
            .primaryButtonStyle()
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Feed Item Row

struct FeedItemRow: View {
    let item: FeedItem

    var body: some View {
        HStack(spacing: 12) {
            // User Photo with Tier Ring
            TierAvatarView(
                photoURL: item.user.photoURL,
                displayName: item.user.displayName,
                tier: item.user.tier,
                size: Constants.UI.feedRowImageSize
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.user.displayName)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    TierBadgeView(tier: item.user.tier, style: .minimal)

                    Text("completed a focus session")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .lineLimit(1)

                HStack(spacing: 16) {
                    Label(item.session.formattedDuration, systemImage: "clock.fill")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.gold)

                    Text(item.session.relativeTimeString)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textTertiary)

                    Spacer()

                    if item.session.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.success)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FeedView()
}
