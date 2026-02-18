import SwiftUI

struct TierBadgeView: View {
    let tier: StatusTier
    var style: BadgeStyle = .full

    enum BadgeStyle {
        case full       // Icon + title + tier name
        case compact    // Icon + tier name only
        case minimal    // Just colored dot
        case icon       // Just icon with background
    }

    var body: some View {
        switch style {
        case .full:
            fullBadge
        case .compact:
            compactBadge
        case .minimal:
            minimalBadge
        case .icon:
            iconBadge
        }
    }

    // MARK: - Badge Styles

    private var fullBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: tierIcon)
                .font(.caption)

            Text(tier.formattedTitle)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(tier.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tier.color.opacity(0.15))
        )
    }

    private var compactBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: tierIcon)
                .font(.caption2)

            Text(tier.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(tier.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tier.color.opacity(0.12))
        )
    }

    private var minimalBadge: some View {
        Circle()
            .fill(tier.color)
            .frame(width: 8, height: 8)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(tier.color.opacity(0.15))
                .frame(width: 28, height: 28)

            Image(systemName: tierIcon)
                .font(.caption)
                .foregroundColor(tier.color)
        }
    }

    // MARK: - Tier Icon

    private var tierIcon: String {
        switch tier {
        case .bronze: return "leaf"
        case .silver: return "star"
        case .gold: return "star.fill"
        case .platinum: return "sparkles"
        case .diamond: return "diamond"
        case .obsidian: return "crown.fill"
        }
    }
}

// MARK: - Inline Tier Title

struct TierTitleView: View {
    let tier: StatusTier
    var showIcon: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Text("◆")
                    .font(.caption2)
            }
            Text("\(tier.displayName) \(tier.title)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(tier.color)
    }
}

// MARK: - Tier Label for Lists

struct TierLabelView: View {
    let tier: StatusTier
    let points: Int

    var body: some View {
        HStack(spacing: 8) {
            TierBadgeView(tier: tier, style: .icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.formattedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(tier.color)

                Text("\(points.formatted()) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Badge Styles") {
    VStack(spacing: 20) {
        ForEach(StatusTier.allCases, id: \.self) { tier in
            HStack(spacing: 12) {
                TierBadgeView(tier: tier, style: .full)
                TierBadgeView(tier: tier, style: .compact)
                TierBadgeView(tier: tier, style: .minimal)
                TierBadgeView(tier: tier, style: .icon)
            }
        }
    }
    .padding()
}

#Preview("Tier Title") {
    VStack(spacing: 10) {
        TierTitleView(tier: .bronze)
        TierTitleView(tier: .gold)
        TierTitleView(tier: .diamond)
        TierTitleView(tier: .obsidian, showIcon: false)
    }
}

#Preview("Tier Label") {
    VStack(spacing: 16) {
        TierLabelView(tier: .bronze, points: 500)
        TierLabelView(tier: .gold, points: 8500)
        TierLabelView(tier: .obsidian, points: 150000)
    }
    .padding()
}
