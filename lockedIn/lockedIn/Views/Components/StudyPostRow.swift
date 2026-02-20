import SwiftUI

struct StudyPostRow: View {
    let post: StudyPost
    let currentVote: VoteType
    let isFavorited: Bool

    var showCompactHeader: Bool = false
    var enableExpandableContent: Bool = true

    var onAuthorTap: (() -> Void)? = nil
    var onUpvote: () -> Void = {}
    var onDownvote: () -> Void = {}
    var onFavorite: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.postCardVerticalSpacing) {
            PostHeaderView(post: post, showCompactHeader: showCompactHeader, onAuthorTap: onAuthorTap)

            if post.title.isNotEmpty {
                Text(post.title)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
            }

            if enableExpandableContent {
                ExpandableTextView(text: post.content, lineLimit: Constants.UI.postCollapsedLineLimit)
            } else {
                Text(post.content)
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            }

            if post.type == .stack {
                stackContent
            } else {
                suggestionContent
            }

            PostActionBarView(
                post: post,
                currentVote: currentVote,
                isFavorited: isFavorited,
                onUpvote: onUpvote,
                onDownvote: onDownvote,
                onFavorite: onFavorite,
                onShare: onShare
            )
        }
        .postCardStyle()
    }

    @ViewBuilder
    private var stackContent: some View {
        if let stackItems = post.stackItems, !stackItems.isEmpty {
            CollapsibleStackItemsView(items: stackItems, collapsedCount: Constants.UI.postCollapsedStackCount)
        } else if !post.tools.isEmpty {
            ToolChipRowView(tools: post.tools)
        }

        TagChipRowView(tags: post.tags)
    }

    @ViewBuilder
    private var suggestionContent: some View {
        TagChipRowView(tags: post.tags)

        if !post.tools.isEmpty {
            ToolChipRowView(tools: post.tools)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StudyPostRow(post: .preview, currentVote: .upvote, isFavorited: true)

        StudyPostRow(
            post: StudyPost(
                authorId: "2",
                authorName: "Sam",
                type: .tip,
                title: "Quick retention loop",
                content: "Teach the concept out loud for 2 minutes after each chapter. This compounds fast.",
                tools: ["Notion"],
                tags: ["retention", "finals"]
            ),
            currentVote: .none,
            isFavorited: false
        )
    }
    .padding()
    .background(AppColors.background.ignoresSafeArea())
}
