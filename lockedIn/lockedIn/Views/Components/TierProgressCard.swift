import SwiftUI

struct TierProgressCard: View {
    let points: Int
    let tier: StatusTier
    var showDetails: Bool = true

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

                    Text("\(points.formatted()) points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tier icon
                ZStack {
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
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)

                                // Progress fill
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
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(tier.accentColor)
                        Text("Maximum tier achieved")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .fill(AppColors.cardBackground)
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
