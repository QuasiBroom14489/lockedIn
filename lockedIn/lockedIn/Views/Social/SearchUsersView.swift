import SwiftUI

struct SearchUsersView: View {
    @ObservedObject var viewModel: SocialViewModel
    @State private var selectedUserId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search by name...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Results
            if viewModel.isSearching {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.searchQuery.isEmpty {
                SearchPlaceholderView()
            } else if viewModel.searchResults.isEmpty {
                NoResultsView(query: viewModel.searchQuery)
            } else {
                List {
                    ForEach(viewModel.searchResults) { user in
                        Button {
                            selectedUserId = user.id
                        } label: {
                            SearchResultRow(user: user, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedUserId) { userId in
            OtherUserProfileView(userId: userId)
        }
    }
}

// MARK: - Search Placeholder

struct SearchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("Find Notre Dame Students")
                .font(AppFonts.headline())
                .foregroundColor(.primary)

            Text("Search by name to find and follow classmates")
                .font(AppFonts.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - No Results

struct NoResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(AppFonts.headline())
                .foregroundColor(.primary)

            Text("No users found matching \"\(query)\"")
                .font(AppFonts.body())
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: User
    @ObservedObject var viewModel: SocialViewModel
    @State private var isFollowing = false
    @State private var isLoading = false

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

                if let major = user.major {
                    Text(major)
                        .font(AppFonts.caption())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Follow Button
            Button {
                Task {
                    await toggleFollow()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(width: 80)
                } else {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isFollowing ? .primary : .white)
                        .frame(width: 80, height: 32)
                        .background(isFollowing ? Color(.systemGray5) : AppColors.navyBlue)
                        .cornerRadius(16)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .task {
            isFollowing = await viewModel.isFollowing(userId: user.id ?? "")
        }
    }

    private func toggleFollow() async {
        guard let userId = user.id else { return }

        isLoading = true
        if isFollowing {
            await viewModel.unfollow(userId: userId)
            isFollowing = false
        } else {
            await viewModel.follow(userId: userId)
            isFollowing = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SearchUsersView(viewModel: SocialViewModel())
    }
}
