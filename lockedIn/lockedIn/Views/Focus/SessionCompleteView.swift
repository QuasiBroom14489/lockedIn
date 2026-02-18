import SwiftUI

struct SessionCompleteView: View {
    let duration: Int
    let onDismiss: () -> Void

    @State private var showConfetti = true

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Celebration Icon
            ZStack {
                Circle()
                    .fill(AppColors.gold.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.gold)
                    .scaleEffect(showConfetti ? 1 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
            }

            // Congratulations Text
            VStack(spacing: 8) {
                Text("Great Focus Session!")
                    .font(AppFonts.title())
                    .foregroundColor(AppColors.navyBlue)

                Text("You stayed locked in for")
                    .font(AppFonts.body())
                    .foregroundColor(.secondary)
            }

            // Duration Display
            Text(duration.formattedAsDuration)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.navyBlue)

            // Stats
            HStack(spacing: 40) {
                StatDisplay(
                    value: "\(duration / 60)",
                    unit: "minutes",
                    icon: "clock.fill"
                )

                StatDisplay(
                    value: "1",
                    unit: "session",
                    icon: "flame.fill"
                )
            }
            .padding(.top, 16)

            Spacer()

            // Motivational Quote
            VStack(spacing: 8) {
                Text(motivationalQuote)
                    .font(AppFonts.body())
                    .italic()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Done Button
            Button(action: onDismiss) {
                Text("Done")
            }
            .primaryButtonStyle()
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    var motivationalQuote: String {
        let quotes = [
            "\"The secret of getting ahead is getting started.\" - Mark Twain",
            "\"Focus on being productive instead of busy.\" - Tim Ferriss",
            "\"It's not that I'm so smart, it's just that I stay with problems longer.\" - Einstein",
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
                .font(.system(size: 24))
                .foregroundColor(AppColors.gold)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.navyBlue)

            Text(unit)
                .font(AppFonts.caption())
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SessionCompleteView(
        duration: 1500,
        onDismiss: {}
    )
}
