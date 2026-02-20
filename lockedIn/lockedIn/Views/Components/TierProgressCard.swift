import SwiftUI

struct TierProgressCard: View {
    let points: Int
    let tier: StatusTier
    var showDetails: Bool = true
    var animated: Bool = true

    private var progress: Double {
        tier.progressToNextTier(currentPoints: points)
    }

    private var pointsToNext: Int? {
        tier.pointsToNextTier(currentPoints: points)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Current tier and points
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.formattedTitle)
                        .font(.headline)
                        .foregroundColor(tier.color)

                    if animated {
                        AnimatedNumber(
                            value: points,
                            format: .points,
                            font: .subheadline,
                            color: .secondary
                        )
                    } else {
                        Text("\(points.formatted()) points")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Tier icon with subtle glow
                ZStack {
                    if tier.hasGlow {
                        Circle()
                            .fill(tier.color.opacity(0.1))
                            .frame(width: 56, height: 56)
                            .blur(radius: 4)
                    }

                    Circle()
                        .fill(tier.color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: tierIcon)
                        .font(.title2)
                        .foregroundColor(tier.color)
                }
            }

            if showDetails {
                // Progress bar
                if let next = tier.nextTier {
                    VStack(spacing: 8) {
                        if animated {
                            TierAnimatedProgressBar(progress: progress, tier: tier)
                        } else {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: tier.gradientColors,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * progress, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }

                        // Progress labels
                        HStack {
                            Text("\(tier.minimumPoints.formatted())")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            if let remaining = pointsToNext {
                                Text("\(remaining.formatted()) to \(next.displayName)")
                                    .font(.caption)
                                    .foregroundColor(next.color)
                            }

                            Spacer()

                            Text("\(next.minimumPoints.formatted())")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Max tier reached
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(tier.accentColor)
                        Text("Maximum tier achieved")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Subtle shimmer for obsidian
                        if tier == .obsidian {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundColor(AppColors.gold.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(tier.hasGlow ? tier.color.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

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

// MARK: - Compact Progress View

struct TierProgressCompact: View {
    let points: Int
    let tier: StatusTier

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tier.color)
                .frame(width: 8, height: 8)

            Text(tier.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(tier.color)

            Text("•")
                .foregroundColor(.secondary)

            Text("\(points.formatted()) pts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Progress Card") {
    VStack(spacing: 20) {
        TierProgressCard(points: 500, tier: .bronze)
        TierProgressCard(points: 3500, tier: .silver)
        TierProgressCard(points: 12000, tier: .gold)
        TierProgressCard(points: 150000, tier: .obsidian)
    }
    .padding()
}

#Preview("Compact") {
    VStack(spacing: 10) {
        TierProgressCompact(points: 500, tier: .bronze)
        TierProgressCompact(points: 25000, tier: .platinum)
        TierProgressCompact(points: 150000, tier: .obsidian)
    }
    .padding()
}
