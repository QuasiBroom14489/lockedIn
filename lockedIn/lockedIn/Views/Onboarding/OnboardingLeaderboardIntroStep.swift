import SwiftUI

struct OnboardingLeaderboardIntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compete Together")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("The leaderboard turns consistent studying into momentum for you and your dorm.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 12) {
                leaderboardRow(rank: 1, title: "You", subtitle: "Daily focus adds up fast", icon: "medal.fill", color: AppColors.gold)
                leaderboardRow(rank: 2, title: "Your Dorm", subtitle: "Dorm competition makes every session count", icon: "building.columns.fill", color: AppColors.greenMuted)
                leaderboardRow(rank: 3, title: "Campus", subtitle: "See who is climbing this week", icon: "chart.line.uptrend.xyaxis", color: AppColors.textSecondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(AppColors.gold)
                Text("Leaderboard rank is driven by real work: focus sessions, class progress, and the value you add to the community.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.surface)
            )
        }
        .focusCardStyle()
    }

    private func leaderboardRow(rank: Int, title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(AppFonts.body())
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 32)

            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
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
    }
}

#Preview {
    ScrollView {
        OnboardingLeaderboardIntroStep()
            .padding()
    }
    .background(AppColors.background)
}
