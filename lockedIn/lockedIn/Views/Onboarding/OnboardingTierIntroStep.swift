import SwiftUI

struct OnboardingTierIntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Study Your Way Up")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("You start at Bronze. Every verified session, class contribution, and connection helps you climb toward Legend.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingTierPreview(highlightTier: .bronze)
                TierProgressionArrow()
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.surface)
            )

            HStack(spacing: 16) {
                tierRingExample(tier: .bronze, label: "Start")
                tierRingExample(tier: .gold, label: "Momentum")
                tierRingExample(tier: .obsidian, label: "Legend")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.backgroundSecondary)
            )

            VStack(spacing: 0) {
                OnboardingPointsExample(label: "Focus", points: "+1 / min")
                Divider().background(AppColors.borderSubtle)
                OnboardingPointsExample(label: "Add class", points: "+10", highlight: true)
                Divider().background(AppColors.borderSubtle)
                OnboardingPointsExample(label: "Verify grade (A)", points: "+25")
                Divider().background(AppColors.borderSubtle)
                OnboardingPointsExample(label: "New follower", points: "+5")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )

            Text("Bronze to Obsidian is a real progression arc. The more useful and consistent you are, the more status you build.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)
        }
        .focusCardStyle()
    }

    private func tierRingExample(tier: StatusTier, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tier.color.opacity(0.12))
                    .frame(width: 64, height: 64)
                TierRingView(tier: tier, size: 48)
                Image(systemName: symbol(for: tier))
                    .foregroundColor(tier == .obsidian ? AppColors.gold : .white)
            }
            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func symbol(for tier: StatusTier) -> String {
        switch tier {
        case .bronze: return "leaf.fill"
        case .silver: return "star"
        case .gold: return "star.fill"
        case .platinum: return "sparkles"
        case .diamond: return "diamond.fill"
        case .obsidian: return "crown.fill"
        }
    }
}

#Preview {
    ScrollView {
        OnboardingTierIntroStep()
            .padding()
    }
    .background(AppColors.background)
}
