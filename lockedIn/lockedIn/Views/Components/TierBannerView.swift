import SwiftUI

struct TierBannerView: View {
    let tier: StatusTier
    var height: CGFloat = 120
    var showShimmer: Bool = true

    @State private var shimmerPhase: CGFloat = -1
    @State private var wavePhase: CGFloat = 0
    @State private var floatingParticles: [FloatingParticle] = []

    private var shouldAnimate: Bool {
        tier.hasAnimation && showShimmer
    }

    var body: some View {
        ZStack {
            // Base gradient with mesh-like effect
            GeometryReader { geometry in
                ZStack {
                    // Primary gradient
                    LinearGradient(
                        colors: tier.gradientColors + [tier.gradientColors.first ?? tier.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Animated wave overlay
                    if shouldAnimate {
                        waveOverlay(in: geometry.size)
                    }

                    // Floating particles for higher tiers
                    if tier.hasGlow {
                        ForEach(floatingParticles) { particle in
                            FloatingParticleView(particle: particle, tier: tier, containerSize: geometry.size)
                        }
                    }

                    // Subtle noise texture
                    noiseOverlay

                    // Shimmer sweep
                    if shouldAnimate {
                        shimmerOverlay(in: geometry.size)
                    }
                }
            }

            // Bottom gradient fade
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, AppColors.surface.opacity(0.3), AppColors.surface.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
            }

            // Top vignette
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
                Spacer()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .onAppear {
            if tier.hasGlow {
                generateParticles()
            }
            if shouldAnimate {
                startAnimations()
            }
        }
    }

    private func waveOverlay(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let waveHeight: CGFloat = 8
            let wavelength: CGFloat = 60

            for i in 0..<3 {
                var path = Path()
                let yOffset = canvasSize.height * (0.3 + CGFloat(i) * 0.25)

                path.move(to: CGPoint(x: 0, y: yOffset))

                for x in stride(from: 0, to: canvasSize.width + 10, by: 5) {
                    let relativeX = x / wavelength + wavePhase + CGFloat(i) * 0.5
                    let y = yOffset + sin(relativeX) * waveHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.05 - Double(i) * 0.01)),
                    lineWidth: 1
                )
            }
        }
    }

    private var noiseOverlay: some View {
        Rectangle()
            .fill(.white.opacity(0.02))
            .background(
                Canvas { context, size in
                    for _ in 0..<50 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        context.fill(
                            Rectangle().path(in: rect),
                            with: .color(.white.opacity(Double.random(in: 0.01...0.04)))
                        )
                    }
                }
            )
    }

    private func shimmerOverlay(in size: CGSize) -> some View {
        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.1),
                .white.opacity(0.2),
                .white.opacity(0.1),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size.width * 0.6)
        .rotationEffect(.degrees(15))
        .offset(x: shimmerPhase * size.width * 2)
        .mask(Rectangle())
    }

    private func generateParticles() {
        floatingParticles = (0..<15).map { _ in
            FloatingParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 2...5),
                speed: CGFloat.random(in: 0.3...0.8),
                delay: Double.random(in: 0...2)
            )
        }
    }

    private func startAnimations() {
        // Shimmer
        withAnimation(
            .linear(duration: 4)
            .repeatForever(autoreverses: false)
        ) {
            shimmerPhase = 1
        }

        // Wave
        withAnimation(
            .linear(duration: 6)
            .repeatForever(autoreverses: false)
        ) {
            wavePhase = .pi * 2
        }
    }
}

// MARK: - Floating Particle

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
                    colors: [.white.opacity(0.6), .white.opacity(0)],
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
}

// MARK: - Full Width Banner with Avatar

struct ProfileTierBanner: View {
    let tier: StatusTier
    let photoURL: String?
    let displayName: String
    var avatarSize: CGFloat = 100

    @State private var bannerAppeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Banner
            TierBannerView(tier: tier, height: 130)
                .opacity(bannerAppeared ? 1 : 0)
                .scaleEffect(y: bannerAppeared ? 1 : 0.95, anchor: .top)

            // Avatar overlapping the banner
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

// MARK: - Previews

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
            tier: .diamond,
            photoURL: nil,
            displayName: "John Doe"
        )

        Spacer()
    }
    .background(AppColors.background)
}
