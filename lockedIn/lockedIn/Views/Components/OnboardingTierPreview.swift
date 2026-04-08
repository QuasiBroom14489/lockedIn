import SwiftUI

struct OnboardingTierPreview: View {
    var highlightTier: StatusTier = .bronze

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StatusTier.allCases, id: \.self) { tier in
                    TierPreviewItem(
                        tier: tier,
                        isHighlighted: tier == highlightTier
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TierPreviewItem: View {
    let tier: StatusTier
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if tier.hasGlow {
                    Circle()
                        .fill(tier.color.opacity(0.2))
                        .frame(width: 52, height: 52)
                        .blur(radius: 4)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: tier.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: tierIcon(for: tier))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tier == .obsidian ? AppColors.gold : .white)
            }

            VStack(spacing: 2) {
                Text(tier.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isHighlighted ? tier.color : AppColors.textPrimary)

                Text(formatPoints(tier.minimumPoints))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? tier.color.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHighlighted ? tier.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func tierIcon(for tier: StatusTier) -> String {
        switch tier {
        case .bronze: return "leaf"
        case .silver: return "star"
        case .gold: return "star.fill"
        case .platinum: return "sparkles"
        case .diamond: return "diamond"
        case .obsidian: return "crown.fill"
        }
    }

    private func formatPoints(_ points: Int) -> String {
        if points >= 1000 {
            return "\(points / 1000)k+"
        }
        return "\(points)"
    }
}

struct TierProgressionArrow: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatusTier.allCases, id: \.self) { tier in
                if tier != .bronze {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }

                Circle()
                    .fill(tier.color)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingTierPreview(highlightTier: .bronze)

        OnboardingTierPreview(highlightTier: .gold)

        TierProgressionArrow()
    }
    .padding()
    .background(AppColors.background)
}
