import SwiftUI

struct OnboardingFeedIntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Study Feed")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Share what actually works, discover better workflows, and surface the best ideas through voting.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 12) {
                OnboardingFeatureCard(
                    icon: "square.and.arrow.up.fill",
                    title: "Share your stack",
                    description: "Post the exact tools, steps, and timing behind a productive study session."
                )
                OnboardingFeatureCard(
                    icon: "hand.thumbsup.fill",
                    title: "Vote on what helps",
                    description: "Upvote the most useful resources so great workflows rise for your classes."
                )
                OnboardingFeatureCard(
                    icon: "magnifyingglass",
                    title: "Discover by class",
                    description: "Browse tips and stacks tied to the same classes and majors you care about."
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Two post types")
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text("Study Stacks show a repeatable workflow. Suggestions share quick tactics, shortcuts, and advice.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(AppColors.backgroundSecondary)
            )
        }
        .focusCardStyle()
    }
}

#Preview {
    ScrollView {
        OnboardingFeedIntroStep()
            .padding()
    }
    .background(AppColors.background)
}
