import SwiftUI

struct OnboardingFocusIntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus Timer")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("The core of lockedIn. Pick a duration, lock in, and earn points for every minute you actually study.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            timerMockup

            VStack(alignment: .leading, spacing: 12) {
                OnboardingBulletPoint(
                    icon: "timer",
                    text: "Set your duration and stay focused"
                )

                OnboardingBulletPoint(
                    icon: "checkmark.seal.fill",
                    text: "Complete sessions are verified"
                )

                OnboardingBulletPoint(
                    icon: "plus.circle.fill",
                    text: "Earn 1 point per minute"
                )

                OnboardingBulletPoint(
                    icon: "flame.fill",
                    text: "Build streaks by studying consistently",
                    iconColor: .orange
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.surface)
            )

            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.gold)

                Text("A 25-minute session = 25 points toward your next tier")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.gold.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .focusCardStyle()
    }

    private var timerMockup: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppColors.surface, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.gold, AppColors.goldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("16:15")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)

                    Text("remaining")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .shadow(color: AppColors.gold.opacity(0.3), radius: 12, x: 0, y: 0)

            HStack(spacing: 8) {
                ForEach([15, 25, 45, 60, 90], id: \.self) { mins in
                    Text("\(mins)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(mins == 25 ? AppColors.background : AppColors.textTertiary)
                        .frame(width: 36, height: 28)
                        .background(mins == 25 ? AppColors.gold : AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .fill(AppColors.backgroundSecondary)
        )
    }
}

#Preview {
    ScrollView {
        OnboardingFocusIntroStep()
            .padding()
    }
    .background(AppColors.background)
}
