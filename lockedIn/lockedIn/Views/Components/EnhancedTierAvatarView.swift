import SwiftUI

struct EnhancedTierAvatarView: View {
    let photoURL: String?
    let displayName: String
    let tier: StatusTier
    let size: CGFloat
    var showAnimation: Bool = true

    @State private var pulsePhase: CGFloat = 0
    @State private var rotationPhase: CGFloat = 0
    @State private var particlePhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.6
    @State private var appearScale: CGFloat = 0.8
    @State private var appearOpacity: CGFloat = 0

    private var glowLayers: Int {
        switch tier {
        case .bronze, .silver: return 1
        case .gold: return 2
        case .platinum: return 3
        case .diamond: return 4
        case .obsidian: return 5
        }
    }

    private var shouldPulse: Bool {
        tier.hasAnimation && showAnimation
    }

    private var particleCount: Int {
        switch tier {
        case .bronze, .silver: return 0
        case .gold: return 6
        case .platinum: return 8
        case .diamond: return 12
        case .obsidian: return 16
        }
    }

    var body: some View {
        ZStack {
            // Ambient glow background
            if tier.hasGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tier.color.opacity(0.4 * glowIntensity),
                                tier.color.opacity(0.2 * glowIntensity),
                                tier.color.opacity(0)
                            ],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.9
                        )
                    )
                    .frame(width: size * 1.8, height: size * 1.8)
                    .blur(radius: 20)
            }

            // Orbiting particles
            if particleCount > 0 {
                ForEach(0..<particleCount, id: \.self) { index in
                    ParticleView(
                        tier: tier,
                        index: index,
                        totalCount: particleCount,
                        orbitRadius: size * 0.65,
                        phase: particlePhase
                    )
                }
            }

            // Multi-layer glow rings
            ForEach(0..<glowLayers, id: \.self) { index in
                glowRing(layer: index)
            }

            // Main tier ring with gradient
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: tier.gradientColors + [tier.gradientColors.first ?? tier.color],
                            center: .center,
                            startAngle: .degrees(rotationPhase),
                            endAngle: .degrees(rotationPhase + 360)
                        ),
                        lineWidth: tier.ringWidth + 2
                    )
                    .frame(width: size + tier.ringWidth + 4, height: size + tier.ringWidth + 4)
                    .blur(radius: 4)
                    .opacity(tier.hasGlow ? 0.6 : 0.3)

                // Main ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: tier.gradientColors + [tier.gradientColors.first ?? tier.color],
                            center: .center,
                            startAngle: .degrees(shouldPulse ? rotationPhase : 0),
                            endAngle: .degrees(shouldPulse ? rotationPhase + 360.0 : 360.0)
                        ),
                        lineWidth: tier.ringWidth
                    )
                    .frame(width: size + tier.ringWidth, height: size + tier.ringWidth)
            }

            // Avatar image with inner shadow
            avatarImage
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .frame(width: size + (tier.ringWidth * 2) + 24, height: size + (tier.ringWidth * 2) + 24)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }

            if shouldPulse {
                startPulseAnimation()
                startRotationAnimation()
                startParticleAnimation()
            }
        }
    }

    private func glowRing(layer: Int) -> some View {
        let baseOffset = CGFloat(layer) * 6
        let pulseAmount = shouldPulse ? sin(pulsePhase + CGFloat(layer) * 0.8) * 3 : 0

        return Circle()
            .stroke(
                AngularGradient(
                    colors: tier.gradientColors,
                    center: .center,
                    startAngle: .degrees(rotationPhase * (layer % 2 == 0 ? 1.0 : -1.0) + Double(layer * 45)),
                    endAngle: .degrees(rotationPhase * (layer % 2 == 0 ? 1.0 : -1.0) + 360.0 + Double(layer * 45))
                ),
                lineWidth: max(1, 2 - CGFloat(layer) * 0.3)
            )
            .frame(
                width: size + tier.ringWidth * 2 + baseOffset + 12,
                height: size + tier.ringWidth * 2 + baseOffset + 12
            )
            .blur(radius: tier.glowRadius + CGFloat(layer * 3))
            .opacity(tier.hasGlow ? (0.5 - Double(layer) * 0.08 + Double(pulseAmount) * 0.05) : 0)
            .scaleEffect(1 + pulseAmount * 0.015)
    }

    private var avatarImage: some View {
        Group {
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
                        ZStack {
                            Circle()
                                .fill(tier.color.opacity(0.1))
                            ProgressView()
                                .tint(tier.color)
                        }
                        .frame(width: size, height: size)
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
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tier.color.opacity(0.3), tier.color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(displayName.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(tier.color)
        }
        .frame(width: size, height: size)
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            pulsePhase = .pi * 2
            glowIntensity = 1.0
        }
    }

    private func startRotationAnimation() {
        withAnimation(
            .linear(duration: 10)
            .repeatForever(autoreverses: false)
        ) {
            rotationPhase = 360
        }
    }

    private func startParticleAnimation() {
        withAnimation(
            .linear(duration: 8)
            .repeatForever(autoreverses: false)
        ) {
            particlePhase = .pi * 2
        }
    }
}

// MARK: - Particle View

struct ParticleView: View {
    let tier: StatusTier
    let index: Int
    let totalCount: Int
    let orbitRadius: CGFloat
    let phase: CGFloat

    private var baseAngle: CGFloat {
        CGFloat(index) / CGFloat(totalCount) * .pi * 2
    }

    private var currentAngle: CGFloat {
        baseAngle + phase
    }

    private var particleSize: CGFloat {
        let sizes: [CGFloat] = [3, 4, 5, 4, 3, 5, 4, 3]
        return sizes[index % sizes.count]
    }

    var body: some View {
        Circle()
            .fill(tier.color)
            .frame(width: particleSize, height: particleSize)
            .blur(radius: 1)
            .shadow(color: tier.color.opacity(0.8), radius: 4)
            .offset(
                x: cos(currentAngle) * orbitRadius,
                y: sin(currentAngle) * orbitRadius
            )
            .opacity(0.6 + Double(sin(Float(phase * 2 + CGFloat(index)))) * 0.4)
    }
}

// MARK: - Tier Title View

struct TierTitleView: View {
    let tier: StatusTier
    var showIcon: Bool = true

    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 8))
                    .foregroundColor(tier.color)
            }
            Text("\(tier.displayName) \(tier.title)")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(tier.color)
        .overlay(
            tier.hasGlow ?
            LinearGradient(
                colors: [.clear, .white.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40)
            .offset(x: shimmerOffset)
            .mask(
                Text("\(tier.displayName) \(tier.title)")
                    .font(.subheadline.weight(.semibold))
            )
            : nil
        )
        .onAppear {
            if tier.hasGlow {
                withAnimation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false)
                    .delay(1)
                ) {
                    shimmerOffset = 200
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Enhanced Avatars") {
    ScrollView {
        VStack(spacing: 50) {
            ForEach(StatusTier.allCases, id: \.self) { tier in
                HStack(spacing: 20) {
                    EnhancedTierAvatarView(
                        photoURL: nil,
                        displayName: tier.title,
                        tier: tier,
                        size: 80
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.displayName)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        TierTitleView(tier: tier)

                        Text("Particles: \(tier.hasGlow ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 40)
    }
    .background(AppColors.background)
}

#Preview("Single Avatar - Diamond") {
    EnhancedTierAvatarView(
        photoURL: nil,
        displayName: "Test User",
        tier: .diamond,
        size: 120
    )
    .padding(60)
    .background(AppColors.background)
}
