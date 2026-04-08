import SwiftUI

struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    var iconColor: Color = AppColors.gold

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

struct OnboardingBulletPoint: View {
    let icon: String
    let text: String
    var iconColor: Color = AppColors.gold

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(text)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OnboardingPointsExample: View {
    let label: String
    let points: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(points)
                .font(AppFonts.caption())
                .fontWeight(.semibold)
                .foregroundColor(highlight ? AppColors.gold : AppColors.textPrimary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    VStack(spacing: 16) {
        OnboardingFeatureCard(
            icon: "timer",
            title: "Focus Timer",
            description: "Set your duration and stay focused to earn points"
        )

        VStack(alignment: .leading, spacing: 12) {
            OnboardingBulletPoint(icon: "timer", text: "Set your duration and stay focused")
            OnboardingBulletPoint(icon: "checkmark.seal.fill", text: "Complete sessions are verified")
            OnboardingBulletPoint(icon: "plus.circle.fill", text: "Earn 1 point per minute focused")
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        VStack(spacing: 0) {
            OnboardingPointsExample(label: "Focus: 1 pt/min", points: "+1")
            Divider().background(AppColors.borderSubtle)
            OnboardingPointsExample(label: "Add class", points: "+10", highlight: true)
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .background(AppColors.background)
}
