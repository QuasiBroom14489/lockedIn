import SwiftUI

struct TierRingView: View {
    let tier: StatusTier
    let size: CGFloat
    var showAnimation: Bool = true

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Glow effect for higher tiers
            if tier.hasGlow {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: tier.gradientColors,
                            center: .center,
                            startAngle: .degrees(animationPhase),
                            endAngle: .degrees(animationPhase + 360)
                        ),
                        lineWidth: tier.ringWidth
                    )
                    .blur(radius: tier.glowRadius)
                    .frame(width: size + tier.ringWidth, height: size + tier.ringWidth)
            }

            // Main ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: tier.gradientColors,
                        center: .center,
                        startAngle: .degrees(showAnimation && tier.hasAnimation ? animationPhase : 0),
                        endAngle: .degrees(showAnimation && tier.hasAnimation ? animationPhase + 360 : 360)
                    ),
                    lineWidth: tier.ringWidth
                )
                .frame(width: size + tier.ringWidth, height: size + tier.ringWidth)
        }
        .onAppear {
            if showAnimation && tier.hasAnimation {
                withAnimation(
                    .linear(duration: 4)
                    .repeatForever(autoreverses: false)
                ) {
                    animationPhase = 360
                }
            }
        }
    }
}

// MARK: - Avatar with Tier Ring

struct TierAvatarView: View {
    let photoURL: String?
    let displayName: String
    let tier: StatusTier
    let size: CGFloat
    var showAnimation: Bool = true

    var body: some View {
        ZStack {
            TierRingView(tier: tier, size: size, showAnimation: showAnimation)

            // Avatar
            if let photoURL = photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        avatarPlaceholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        avatarPlaceholder
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: size + (tier.ringWidth * 2) + 4, height: size + (tier.ringWidth * 2) + 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(tier.color.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(displayName.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(tier.color)
            )
    }
}

// MARK: - Previews

#Preview("All Tiers") {
    ScrollView {
        VStack(spacing: 30) {
            ForEach(StatusTier.allCases, id: \.self) { tier in
                HStack(spacing: 20) {
                    TierAvatarView(
                        photoURL: nil,
                        displayName: tier.title,
                        tier: tier,
                        size: 60
                    )

                    VStack(alignment: .leading) {
                        Text(tier.displayName)
                            .font(.headline)
                        Text(tier.title)
                            .font(.subheadline)
                            .foregroundColor(tier.color)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

#Preview("Single Tier - Gold") {
    TierAvatarView(
        photoURL: nil,
        displayName: "John Doe",
        tier: .gold,
        size: 100
    )
}

#Preview("Ring Only") {
    HStack(spacing: 20) {
        TierRingView(tier: .bronze, size: 50)
        TierRingView(tier: .gold, size: 50)
        TierRingView(tier: .diamond, size: 50)
        TierRingView(tier: .obsidian, size: 50)
    }
}
