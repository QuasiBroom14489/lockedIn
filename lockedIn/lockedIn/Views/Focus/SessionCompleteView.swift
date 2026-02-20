import SwiftUI
import UIKit

struct SessionCompleteView: View {
    let duration: Int
    let onDismiss: () -> Void

    @State private var animateBadge = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.background, AppColors.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .ambientBackgroundLayer()

            VStack(spacing: 20) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(AppColors.gold.opacity(0.18))
                        .frame(width: 126, height: 126)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 82))
                        .foregroundColor(AppColors.gold)
                        .scaleEffect(animateBadge ? 1 : 0.82)
                        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: animateBadge)
                }

                Text("Great Focus Session")
                    .font(AppFonts.focusHeader())
                    .foregroundColor(AppColors.textPrimary)

                Text("You stayed locked in for")
                    .font(AppFonts.focusBody())
                    .foregroundColor(AppColors.textSecondary)

                Text(duration.formattedAsDuration)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.gold)

                HStack(spacing: 18) {
                    StatDisplay(value: "\(duration / 60)", unit: "minutes", icon: "clock.fill")
                    StatDisplay(value: "1", unit: "session", icon: "flame.fill")
                }

                Text(motivationalQuote)
                    .font(AppFonts.focusBody())
                    .italic()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer(minLength: 20)

                Button(action: onDismiss) {
                    Text("Done")
                }
                .primaryButtonStyle()
            }
            .padding(20)
            .focusCardStyle()
            .padding(16)
        }
        .onAppear {
            animateBadge = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    var motivationalQuote: String {
        let quotes = [
            "\"The secret of getting ahead is getting started.\" - Mark Twain",
            "\"Focus on being productive instead of busy.\" - Tim Ferriss",
            "\"Stay with the problem long enough and it gives way.\"",
            "\"The successful warrior is the average person with laser-like focus.\" - Bruce Lee",
            "\"Concentrate all your thoughts upon the work at hand.\" - Alexander Graham Bell"
        ]
        return quotes.randomElement() ?? quotes[0]
    }
}

// MARK: - Stat Display

struct StatDisplay: View {
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.gold)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            Text(unit)
                .font(AppFonts.focusCaption())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface.opacity(0.78))
        )
    }
}

#Preview {
    SessionCompleteView(
        duration: 1500,
        onDismiss: {}
    )
}
