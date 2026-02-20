import SwiftUI

struct PostHeaderView: View {
    let post: StudyPost
    var showCompactHeader: Bool = false
    var onAuthorTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            authorButton

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.authorName)
                        .font(showCompactHeader ? .subheadline.weight(.semibold) : .headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    postTypeBadge
                }

                Text(post.relativeTimeString)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
    }

    private var authorButton: some View {
        Button(action: { onAuthorTap?() }) {
            avatar
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        Group {
            if let urlString = post.authorPhotoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill(AppColors.surfaceElevated)
                            .overlay(
                                Text(String(post.authorName.prefix(1)).uppercased())
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            )
                    }
                }
            } else {
                Circle()
                    .fill(AppColors.surfaceElevated)
                    .overlay(
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(.caption.weight(.semibold))
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
            .modernCapsuleChipStyle(
                foreground: post.type == .stack ? AppColors.gold : AppColors.success,
                background: (post.type == .stack ? AppColors.gold : AppColors.success).opacity(0.18)
            )
    }
}

#Preview {
    PostHeaderView(post: .preview)
        .padding()
        .background(AppColors.background)
}
