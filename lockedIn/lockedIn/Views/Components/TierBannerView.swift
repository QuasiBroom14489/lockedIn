import SwiftUI

struct TierBannerView: View {
    let tier: StatusTier
    var height: CGFloat = 120
    var showShimmer: Bool = true

    @State private var shimmerPhase: CGFloat = -1
    @State private var floatingParticles: [FloatingParticle] = []
    @State private var clovers: [BannerClover] = []

    private var shouldAnimate: Bool {
        tier.hasAnimation && showShimmer
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    bannerBase

                    ambientGlow(
                        color: tier.gradientColors.first ?? tier.color,
                        x: geometry.size.width * 0.18,
                        y: geometry.size.height * 0.26,
                        width: geometry.size.width * 0.55,
                        height: geometry.size.height * 0.95
                    )

                    ambientGlow(
                        color: tier.gradientColors.last ?? tier.color,
                        x: geometry.size.width * 0.82,
                        y: geometry.size.height * 0.22,
                        width: geometry.size.width * 0.5,
                        height: geometry.size.height * 0.88
                    )

                    ambientGlow(
                        color: tier.color.opacity(0.9),
                        x: geometry.size.width * 0.52,
                        y: geometry.size.height * 0.72,
                        width: geometry.size.width * 0.75,
                        height: geometry.size.height * 0.6
                    )

                    ForEach(clovers) { clover in
                        BannerCloverView(
                            clover: clover,
                            tier: tier,
                            containerSize: geometry.size
                        )
                    }

                    if tier.hasGlow {
                        ForEach(floatingParticles) { particle in
                            FloatingParticleView(
                                particle: particle,
                                tier: tier,
                                containerSize: geometry.size
                            )
                        }
                    }

                    if shouldAnimate {
                        shimmerOverlay(in: geometry.size)
                    }
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            .clear,
                            Color.black.opacity(0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(height: height)
        .clipped()
        .onAppear {
            if clovers.isEmpty {
                clovers = BannerClover.defaultLayout
            }
            if tier.hasGlow && floatingParticles.isEmpty {
                generateParticles()
            }
            if shouldAnimate {
                startAnimations()
            }
        }
    }

    private var bannerBase: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.backgroundSecondary,
                    (tier.gradientColors.first ?? tier.color).opacity(0.42),
                    (tier.gradientColors.last ?? tier.color).opacity(0.28),
                    AppColors.surfaceElevated
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [tier.color.opacity(0.16), .clear],
                center: .center,
                startRadius: 12,
                endRadius: 220
            )
        }
    }

    private func ambientGlow(
        color: Color,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        Ellipse()
            .fill(color.opacity(tier == .bronze ? 0.18 : 0.14))
            .frame(width: width, height: height)
            .blur(radius: 30)
            .position(x: x, y: y)
    }

    private func shimmerOverlay(in size: CGSize) -> some View {
        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.03),
                (tier == .obsidian ? AppColors.gold : .white).opacity(0.14),
                .white.opacity(0.03),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size.width * 0.5)
        .rotationEffect(.degrees(12))
        .offset(x: shimmerPhase * size.width * 2)
        .mask(Rectangle())
    }

    private func generateParticles() {
        floatingParticles = (0..<12).map { _ in
            FloatingParticle(
                x: CGFloat.random(in: 0.08...0.92),
                y: CGFloat.random(in: 0.12...0.88),
                size: CGFloat.random(in: 2...5),
                speed: CGFloat.random(in: 0.3...0.8),
                delay: Double.random(in: 0...2)
            )
        }
    }

    private func startAnimations() {
        withAnimation(
            .linear(duration: 4.8)
            .repeatForever(autoreverses: false)
        ) {
            shimmerPhase = 1
        }
    }
}

struct BannerClover: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let rotation: Double
    let opacity: Double

    static let defaultLayout: [BannerClover] = [
        BannerClover(x: 0.12, y: 0.22, size: 28, rotation: -14, opacity: 0.16),
        BannerClover(x: 0.24, y: 0.7, size: 38, rotation: 8, opacity: 0.12),
        BannerClover(x: 0.38, y: 0.32, size: 22, rotation: -8, opacity: 0.14),
        BannerClover(x: 0.53, y: 0.58, size: 44, rotation: 12, opacity: 0.1),
        BannerClover(x: 0.66, y: 0.18, size: 32, rotation: -10, opacity: 0.14),
        BannerClover(x: 0.8, y: 0.64, size: 26, rotation: 16, opacity: 0.16),
        BannerClover(x: 0.9, y: 0.34, size: 36, rotation: -18, opacity: 0.1)
    ]
}

struct BannerCloverView: View {
    let clover: BannerClover
    let tier: StatusTier
    let containerSize: CGSize

    private var cloverColor: Color {
        switch tier {
        case .bronze:
            return Color(hex: "B08861")
        case .silver:
            return Color(hex: "C9D1DB")
        case .gold:
            return Color(hex: "D8B24A")
        case .platinum:
            return Color(hex: "D6E2EC")
        case .diamond:
            return Color(hex: "90C8FF")
        case .obsidian:
            return AppColors.gold
        }
    }

    var body: some View {
        ZStack {
            ShamrockMark(color: cloverColor.opacity(clover.opacity))
                .frame(width: clover.size * 1.02, height: clover.size * 1.06)
                .rotationEffect(.degrees(clover.rotation))

            ShamrockMark(color: cloverColor.opacity(clover.opacity * 0.36))
                .frame(width: clover.size * 1.02, height: clover.size * 1.06)
                .rotationEffect(.degrees(clover.rotation))
                .blur(radius: 6)
        }
        .position(
            x: containerSize.width * clover.x,
            y: containerSize.height * clover.y
        )
    }
}

struct ShamrockMark: View {
    var color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                Circle()
                    .frame(width: width * 0.46, height: width * 0.46)
                    .offset(x: -width * 0.18, y: height * 0.15)

                Circle()
                    .frame(width: width * 0.42, height: width * 0.42)
                    .offset(x: -width * 0.02, y: -height * 0.08)

                Circle()
                    .frame(width: width * 0.42, height: width * 0.42)
                    .offset(x: width * 0.16, y: -height * 0.02)

                Circle()
                    .frame(width: width * 0.46, height: width * 0.46)
                    .offset(x: width * 0.21, y: height * 0.18)

                Capsule()
                    .frame(width: width * 0.12, height: height * 0.4)
                    .offset(x: -width * 0.02, y: height * 0.42)
                    .rotationEffect(.degrees(28))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .compositingGroup()
    }
}

struct FloatingParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var delay: Double
}

struct FloatingParticleView: View {
    let particle: FloatingParticle
    let tier: StatusTier
    let containerSize: CGSize

    @State private var yOffset: CGFloat = 0
    @State private var opacity: CGFloat = 0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        particleColor.opacity(0.55),
                        particleColor.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: particle.size
                )
            )
            .frame(width: particle.size * 2, height: particle.size * 2)
            .position(
                x: containerSize.width * particle.x,
                y: containerSize.height * particle.y + yOffset
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3 / particle.speed)
                    .repeatForever(autoreverses: true)
                    .delay(particle.delay)
                ) {
                    yOffset = -20
                    opacity = 0.8
                }
            }
    }

    private var particleColor: Color {
        tier == .obsidian ? AppColors.gold : .white
    }
}

struct ProfileTierBanner: View {
    let tier: StatusTier
    let photoURL: String?
    let displayName: String
    var avatarSize: CGFloat = 100

    @State private var bannerAppeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TierBannerView(tier: tier, height: 130)
                .opacity(bannerAppeared ? 1 : 0)
                .scaleEffect(y: bannerAppeared ? 1 : 0.97, anchor: .top)

            EnhancedTierAvatarView(
                photoURL: photoURL,
                displayName: displayName,
                tier: tier,
                size: avatarSize
            )
            .offset(y: avatarSize * 0.5)
        }
        .padding(.bottom, avatarSize * 0.5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                bannerAppeared = true
            }
        }
    }
}

#Preview("Tier Banners") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(StatusTier.allCases, id: \.self) { tier in
                VStack(spacing: 0) {
                    TierBannerView(tier: tier, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(tier.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(tier.color)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding()
    }
    .background(AppColors.background)
}

#Preview("Profile Banner") {
    VStack {
        ProfileTierBanner(
            tier: .bronze,
            photoURL: nil,
            displayName: "John Doe"
        )

        Spacer()
    }
    .background(AppColors.background)
}
