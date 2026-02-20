import SwiftUI

struct AnimatedProgressBar: View {
    let progress: Double
    var gradientColors: [Color] = [AppColors.gold, AppColors.goldLight]
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var height: CGFloat = 8
    var cornerRadius: CGFloat = 4
    var animationDuration: Double = 1.0

    @State private var displayProgress: Double = 0
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .frame(height: height)

                // Progress fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * displayProgress, height: height)
            }
        }
        .frame(height: height)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            animateProgress()
        }
        .onChange(of: progress) { _, _ in
            animateProgress()
        }
    }

    private func animateProgress() {
        withAnimation(.easeOut(duration: animationDuration)) {
            displayProgress = min(max(progress, 0), 1)
        }
    }
}

// MARK: - Tier Progress Bar

struct TierAnimatedProgressBar: View {
    let progress: Double
    let tier: StatusTier
    var height: CGFloat = 8

    var body: some View {
        AnimatedProgressBar(
            progress: progress,
            gradientColors: tier.gradientColors,
            height: height
        )
    }
}

// MARK: - Previews

#Preview("Progress Bars") {
    VStack(spacing: 20) {
        AnimatedProgressBar(progress: 0.25)
        AnimatedProgressBar(progress: 0.5, gradientColors: [.blue, .cyan])
        AnimatedProgressBar(progress: 0.75, gradientColors: [.green, .mint])
        AnimatedProgressBar(progress: 1.0, gradientColors: [.purple, .pink])
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Tier Progress") {
    VStack(spacing: 20) {
        ForEach(StatusTier.allCases, id: \.self) { tier in
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.displayName)
                    .font(.caption)
                    .foregroundColor(tier.color)

                TierAnimatedProgressBar(progress: 0.65, tier: tier)
            }
        }
    }
    .padding()
    .background(AppColors.background)
}
