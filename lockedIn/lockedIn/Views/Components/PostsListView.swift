import SwiftUI

struct PostsListView: View {
    let posts: [StudyPost]
    var voteForPost: (StudyPost) -> VoteType = { _ in .none }
    var isFavoritedPost: (StudyPost) -> Bool = { _ in false }
    var onAuthorTap: (StudyPost) -> Void = { _ in }
    var onUpvote: (StudyPost) -> Void = { _ in }
    var onDownvote: (StudyPost) -> Void = { _ in }
    var onFavorite: (StudyPost) -> Void = { _ in }
    var onShare: (StudyPost) -> Void = { _ in }
    var onPostAppear: (StudyPost) -> Void = { _ in }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(posts) { post in
                StudyPostRow(
                    post: post,
                    currentVote: voteForPost(post),
                    isFavorited: isFavoritedPost(post),
                    onAuthorTap: {
                        onAuthorTap(post)
                    },
                    onUpvote: {
                        onUpvote(post)
                    },
                    onDownvote: {
                        onDownvote(post)
                    },
                    onFavorite: {
                        onFavorite(post)
                    },
                    onShare: {
                        onShare(post)
                    }
                )
                .onAppear {
                    onPostAppear(post)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        PostsListView(posts: [StudyPost.preview, StudyPost.preview])
            .padding()
    }
    .background(AppColors.background.ignoresSafeArea())
}
