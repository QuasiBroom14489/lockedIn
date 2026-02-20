import SwiftUI

struct PostActionBarView: View {
    let post: StudyPost
    let currentVote: VoteType
    let isFavorited: Bool

    var onUpvote: () -> Void = {}
    var onDownvote: () -> Void = {}
    var onFavorite: () -> Void = {}
    var onShare: () -> Void = {}

    private var upvoteSelected: Bool { currentVote == .upvote }
    private var downvoteSelected: Bool { currentVote == .downvote }

    var body: some View {
        HStack(spacing: 10) {
            interactionButton(
                icon: upvoteSelected ? "arrow.up.circle.fill" : "arrow.up.circle",
                count: post.upvoteCount,
                foreground: upvoteSelected ? AppColors.success : AppColors.textSecondary,
                action: onUpvote
            )

            interactionButton(
                icon: downvoteSelected ? "arrow.down.circle.fill" : "arrow.down.circle",
                count: post.downvoteCount,
                foreground: downvoteSelected ? AppColors.warning : AppColors.textSecondary,
                action: onDownvote
            )

            interactionButton(
                icon: isFavorited ? "bookmark.fill" : "bookmark",
                count: post.favoriteCount,
                foreground: isFavorited ? AppColors.gold : AppColors.textSecondary,
                action: onFavorite
            )

            Spacer(minLength: 0)

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(AppColors.surfaceElevated.opacity(0.75))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func interactionButton(icon: String, count: Int, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text("\(count)")
                    .font(.caption.weight(.semibold))
            }
            .font(.callout)
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppColors.surface.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PostActionBarView(post: .preview, currentVote: .upvote, isFavorited: true)
        .padding()
        .background(AppColors.background)
}
