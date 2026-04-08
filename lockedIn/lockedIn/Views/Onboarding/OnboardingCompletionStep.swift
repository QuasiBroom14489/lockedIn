import SwiftUI

struct OnboardingCompletionStep: View {
    let displayName: String
    let major: String
    let year: String
    let dorm: String
    let toolsCount: Int
    let classesCount: Int
    let onStartFocus: () -> Void
    let onExploreFeed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                CloverView.celebration
                    .goldGlow(radius: 18, opacity: 0.45)

                Text("You're all set")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)

                Text("Your profile is ready. lockedIn can now personalize your classes, tools, feed, and competition view.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(displayName)
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("Ready")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.gold)
                        .clipShape(Capsule())
                }

                Text("\(major) / \(year)")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 10) {
                    dormPill
                    countPill(label: "\(toolsCount) tool\(toolsCount == 1 ? "" : "s")")
                    countPill(label: "\(classesCount) class\(classesCount == 1 ? "" : "es")")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.surfaceElevated, AppColors.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.gold.opacity(0.35), lineWidth: 1)
            )
            .goldGlow(radius: 14, opacity: 0.18)

            VStack(spacing: 10) {
                Button(action: onStartFocus) {
                    Label("Start Your First Focus Session", systemImage: "timer")
                }
                .primaryButtonStyle()

                Button(action: onExploreFeed) {
                    Label("Explore the Feed", systemImage: "book.pages.fill")
                }
                .secondaryButtonStyle()
            }

            Text("You can change any of this later from your profile.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .focusCardStyle()
    }

    private var dormPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "building.columns.fill")
            Text(dorm)
                .lineLimit(1)
        }
        .modernCapsuleChipStyle(foreground: AppColors.background, background: AppColors.gold.opacity(0.9))
    }

    private func countPill(label: String) -> some View {
        Text(label)
            .modernCapsuleChipStyle()
    }
}

#Preview {
    ScrollView {
        OnboardingCompletionStep(
            displayName: "Zane",
            major: "Computer Science",
            year: "Junior",
            dorm: "Dillon Hall",
            toolsCount: 3,
            classesCount: 2,
            onStartFocus: {},
            onExploreFeed: {}
        )
        .padding()
    }
    .background(AppColors.background)
}
