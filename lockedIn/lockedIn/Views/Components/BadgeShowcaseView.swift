import SwiftUI

// MARK: - Badge Types

enum BadgeType: Identifiable {
    case tier(StatusTier)
    case dorm(Dorm)
    case achievement(AchievementBadge)

    var id: String {
        switch self {
        case .tier(let tier): return "tier_\(tier.rawValue)"
        case .dorm(let dorm): return "dorm_\(dorm.rawValue)"
        case .achievement(let badge): return "achievement_\(badge.id)"
        }
    }

    var isLocked: Bool {
        switch self {
        case .tier, .dorm:
            return false
        case .achievement(let badge):
            return !badge.isUnlocked
        }
    }

    var icon: String {
        switch self {
        case .tier(let tier):
            switch tier {
            case .bronze: return "leaf.fill"
            case .silver: return "star.fill"
            case .gold: return "star.circle.fill"
            case .platinum: return "sparkles"
            case .diamond: return "diamond.fill"
            case .obsidian: return "crown.fill"
            }
        case .dorm(let dorm):
            return dorm.icon
        case .achievement(let badge):
            return badge.icon
        }
    }

    var title: String {
        switch self {
        case .tier(let tier): return tier.displayName
        case .dorm(let dorm): return dorm.shortName
        case .achievement(let badge): return badge.title
        }
    }

    var color: Color {
        switch self {
        case .tier(let tier): return tier.color
        case .dorm(let dorm): return dorm.color
        case .achievement(let badge): return badge.color
        }
    }

    var description: String {
        switch self {
        case .tier(let tier):
            return "Reached \(tier.displayName) tier with \(tier.minimumPoints.formatted())+ points"
        case .dorm(let dorm):
            return "Member of \(dorm.displayName)"
        case .achievement(let badge):
            return badge.description
        }
    }
}

// MARK: - Achievement Badges

struct AchievementBadge: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    var isUnlocked: Bool = false
    var unlockedAt: Date?

    static let earlyAdopter = AchievementBadge(
        id: "early_adopter",
        title: "Early Adopter",
        description: "Joined during the beta period",
        icon: "star.circle.fill",
        color: AppColors.gold
    )

    static let streakWeek = AchievementBadge(
        id: "streak_week",
        title: "7 Day Streak",
        description: "Studied for 7 days in a row",
        icon: "flame.fill",
        color: .orange
    )

    static let nightOwl = AchievementBadge(
        id: "night_owl",
        title: "Night Owl",
        description: "Completed a session after midnight",
        icon: "moon.fill",
        color: .purple
    )

    static let centurion = AchievementBadge(
        id: "centurion",
        title: "Centurion",
        description: "Completed 100 focus sessions",
        icon: "100.circle.fill",
        color: AppColors.gold
    )

    static let allBadges: [AchievementBadge] = [
        .earlyAdopter,
        .streakWeek,
        .nightOwl,
        .centurion
    ]
}

// MARK: - Badge Showcase View

struct BadgeShowcaseView: View {
    let badges: [BadgeType]
    var title: String = "Badges"
    var showCount: Bool = true

    @State private var selectedBadge: BadgeType?
    @State private var hasAppeared = false

    private var unlockedCount: Int {
        badges.filter { !$0.isLocked }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with animated count
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "rosette")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.gold)

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                if showCount {
                    HStack(spacing: 4) {
                        Text("\(unlockedCount)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(AppColors.gold)
                        Text("/")
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(badges.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.gold.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // Scrollable badge row with staggered animation
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(badges.enumerated()), id: \.element.id) { index, badge in
                        BadgeItemView(
                            badge: badge,
                            index: index,
                            hasAppeared: hasAppeared
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedBadge = badge
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceElevated, AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                hasAppeared = true
            }
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Badge Item

struct BadgeItemView: View {
    let badge: BadgeType
    let index: Int
    let hasAppeared: Bool

    @State private var isHovered = false
    @State private var pulseScale: CGFloat = 1.0

    private var entranceDelay: Double {
        Double(index) * 0.08
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer glow ring for unlocked badges
                if !badge.isLocked {
                    Circle()
                        .fill(badge.color.opacity(0.2))
                        .frame(width: 68, height: 68)
                        .blur(radius: 8)
                        .scaleEffect(pulseScale)
                }

                // Background with gradient
                Circle()
                    .fill(
                        badge.isLocked ?
                        LinearGradient(
                            colors: [AppColors.surface, AppColors.backgroundSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [badge.color.opacity(0.25), badge.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // Border ring
                Circle()
                    .stroke(
                        badge.isLocked ?
                        AppColors.borderSubtle :
                        badge.color.opacity(0.5),
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)

                // Icon with bounce
                Image(systemName: badge.isLocked ? "lock.fill" : badge.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        badge.isLocked ?
                        AnyShapeStyle(AppColors.textTertiary) :
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [badge.color, badge.color.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                    .shadow(color: badge.isLocked ? .clear : badge.color.opacity(0.5), radius: 4)
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)

            // Title
            Text(badge.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(badge.isLocked ? AppColors.textTertiary : AppColors.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 75)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7).delay(entranceDelay),
            value: hasAppeared
        )
        .onAppear {
            if !badge.isLocked {
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.15
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isHovered = pressing
            }
        }, perform: {})
    }
}

// MARK: - Badge Detail Sheet

struct BadgeDetailSheet: View {
    let badge: BadgeType
    @Environment(\.dismiss) private var dismiss
    @State private var iconRotation: Double = 0
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 28) {
            // Large badge icon with effects
            ZStack {
                // Animated background rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(badge.color.opacity(0.1 - Double(i) * 0.03), lineWidth: 2)
                        .frame(width: 140 + CGFloat(i) * 30, height: 140 + CGFloat(i) * 30)
                        .scaleEffect(showConfetti ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: showConfetti
                        )
                }

                // Main circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [badge.color.opacity(0.4), badge.color.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)

                // Icon
                Image(systemName: badge.isLocked ? "lock.fill" : badge.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(
                        badge.isLocked ?
                        AnyShapeStyle(AppColors.textTertiary) :
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [badge.color, badge.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .rotationEffect(.degrees(iconRotation))
                    .shadow(color: badge.color.opacity(0.5), radius: 8)
            }

            // Title and description
            VStack(spacing: 10) {
                Text(badge.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppColors.textPrimary)

                Text(badge.description)
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Status pill
            HStack(spacing: 8) {
                Image(systemName: badge.isLocked ? "lock.fill" : "checkmark.circle.fill")
                    .font(.subheadline)
                Text(badge.isLocked ? "Not yet unlocked" : "Unlocked!")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(badge.isLocked ? AppColors.textTertiary : AppColors.success)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(badge.isLocked ? AppColors.surface : AppColors.success.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(badge.isLocked ? AppColors.borderSubtle : AppColors.success.opacity(0.3), lineWidth: 1)
            )

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
        .background(AppColors.background)
        .onAppear {
            showConfetti = true
            if !badge.isLocked {
                withAnimation(.easeInOut(duration: 0.5)) {
                    iconRotation = 10
                }
                withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                    iconRotation = 0
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Badge Showcase") {
    BadgeShowcaseView(
        badges: [
            .tier(.gold),
            .dorm(.dillon),
            .achievement(.streakWeek.with(unlocked: true)),
            .achievement(.nightOwl),
            .achievement(.centurion)
        ]
    )
    .padding()
    .background(AppColors.background)
}

#Preview("Badge Detail") {
    BadgeDetailSheet(badge: .tier(.diamond))
}

// Helper extension for preview
extension AchievementBadge {
    func with(unlocked: Bool) -> AchievementBadge {
        var badge = self
        badge.isUnlocked = unlocked
        badge.unlockedAt = unlocked ? Date() : nil
        return badge
    }
}
