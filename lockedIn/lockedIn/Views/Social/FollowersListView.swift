import SwiftUI

enum FollowListType {
    case followers
    case following

    var title: String {
        switch self {
        case .followers: return "Followers"
        case .following: return "Following"
        }
    }
}

struct FollowersListView: View {
    let userId: String
    let listType: FollowListType
    @StateObject private var viewModel = SocialViewModel()
    @State private var selectedUserId: String?

    var users: [User] {
        switch listType {
        case .followers: return viewModel.followers
        case .following: return viewModel.following
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                EmptyFollowListView(listType: listType)
            } else {
                List {
                    ForEach(users) { user in
                        Button {
                            selectedUserId = user.id
                        } label: {
                            FollowUserRow(user: user)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(listType.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedUserId) { userId in
            OtherUserProfileView(userId: userId)
        }
        .task {
            switch listType {
            case .followers:
                await viewModel.loadFollowers(userId: userId)
            case .following:
                await viewModel.loadFollowing(userId: userId)
            }
        }
    }
}

// MARK: - Empty View

struct EmptyFollowListView: View {
    let listType: FollowListType

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: listType == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(listType == .followers ? "No Followers Yet" : "Not Following Anyone")
                .font(AppFonts.headline())
                .foregroundColor(.primary)

            Text(listType == .followers ?
                "When people follow this account, they'll appear here" :
                "When this account follows people, they'll appear here"
            )
                .font(AppFonts.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Follow User Row

struct FollowUserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            // Profile Photo
            AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let year = user.year, let major = user.major {
                    Text("\(year) • \(major)")
                        .font(AppFonts.caption())
                        .foregroundColor(.secondary)
                } else if let major = user.major {
                    Text(major)
                        .font(AppFonts.caption())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(user.formattedTotalTime)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.navyBlue)
                Text("focused")
                    .font(AppFonts.caption())
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        FollowersListView(userId: "preview-id", listType: .followers)
    }
}
