import SwiftUI

struct StudyPostRow: View {
    let post: StudyPost
    let currentVote: VoteType
    let isFavorited: Bool

    var onAuthorTap: (() -> Void)? = nil
    var onUpvote: () -> Void = {}
    var onDownvote: () -> Void = {}
    var onFavorite: () -> Void = {}
    var onShare: () -> Void = {}

    private var upvoteSelected: Bool { currentVote == .upvote }
    private var downvoteSelected: Bool { currentVote == .downvote }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if post.title.isNotEmpty {
                Text(post.title)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
            }

            Text(post.content)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(5)

            if post.type == .stack {
                stackContent
            } else {
                suggestionContent
            }

            actionRow
        }
        .cardStyle()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: { onAuthorTap?() }) {
                avatar
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.authorName)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    postTypeBadge
                }

                Text(post.relativeTimeString)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = post.authorPhotoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                        .tint(AppColors.gold)
                }
            } else {
                Circle()
                    .fill(AppColors.surfaceElevated)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    )
            }
        }
        .frame(width: Constants.UI.feedRowImageSize, height: Constants.UI.feedRowImageSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var postTypeBadge: some View {
        Text(post.type.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(post.type == .stack ? AppColors.gold : AppColors.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill((post.type == .stack ? AppColors.gold : AppColors.success).opacity(0.18))
            )
    }

    @ViewBuilder
    private var stackContent: some View {
        if let stackItems = post.stackItems, !stackItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Study Stack")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.gold)

                ForEach(stackItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.toolName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if let linkURL = item.linkURL,
                               let url = URL(string: linkURL),
                               !linkURL.isEmpty {
                                Link(destination: url) {
                                    Label("Open", systemImage: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.gold)
                                }
                            }
                        }

                        if let note = item.usageNote, note.isNotEmpty {
                            Text(note)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.surfaceElevated)
                    )
                }
            }
        } else if !post.tools.isEmpty {
            toolChips(post.tools)
        }

        if !post.tags.isEmpty {
            tagChips(post.tags)
        }
    }

    @ViewBuilder
    private var suggestionContent: some View {
        if !post.tags.isEmpty {
            tagChips(post.tags)
        }

        if !post.tools.isEmpty {
            toolChips(post.tools)
        }
    }

    private func toolChips(_ tools: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tools, id: \.self) { tool in
                    Text(tool)
                        .font(.caption)
                        .foregroundColor(AppColors.greenLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.greenMuted.opacity(0.2))
                        )
                }
            }
        }
    }

    private func tagChips(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.surfaceElevated)
                        )
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button(action: onUpvote) {
                HStack(spacing: 4) {
                    Image(systemName: upvoteSelected ? "arrow.up.circle.fill" : "arrow.up.circle")
                    Text("\(post.upvoteCount)")
                }
                .font(.caption)
                .foregroundColor(upvoteSelected ? AppColors.success : AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: onDownvote) {
                HStack(spacing: 4) {
                    Image(systemName: downvoteSelected ? "arrow.down.circle.fill" : "arrow.down.circle")
                    Text("\(post.downvoteCount)")
                }
                .font(.caption)
                .foregroundColor(downvoteSelected ? AppColors.warning : AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: onFavorite) {
                HStack(spacing: 4) {
                    Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                    Text("\(post.favoriteCount)")
                }
                .font(.caption)
                .foregroundColor(isFavorited ? AppColors.gold : AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StudyPostRow(
            post: .preview,
            currentVote: .upvote,
            isFavorited: true
        )

        StudyPostRow(
            post: StudyPost.preview,
            currentVote: .none,
            isFavorited: false
        )
    }
    .padding()
    .background(AppColors.background.ignoresSafeArea())
}
