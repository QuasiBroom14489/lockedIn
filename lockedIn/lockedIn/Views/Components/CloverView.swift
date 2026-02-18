import SwiftUI

/// A shamrock/clover view using Unicode character (U+2618)
/// Used as subtle Notre Dame accent throughout the app
struct CloverView: View {
    enum Size {
        case small   // 12pt - inline accents
        case medium  // 24pt - empty states
        case large   // 48pt - celebrations

        var fontSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 24
            case .large: return 48
            }
        }
    }

    let size: Size
    var color: Color = AppColors.greenMuted
    var animated: Bool = false

    @State private var isAnimating = false

    var body: some View {
        Text("☘")
            .font(.system(size: size.fontSize))
            .foregroundColor(color)
            .scaleEffect(animated && isAnimating ? 1.1 : 1.0)
            .opacity(animated && isAnimating ? 0.8 : 1.0)
            .animation(
                animated ? Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )
            .onAppear {
                if animated {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Convenience Initializers

extension CloverView {
    /// Gold clover for login/branding accents
    static var goldSmall: CloverView {
        CloverView(size: .small, color: AppColors.goldMuted)
    }

    /// Green clover for empty states
    static var emptyState: CloverView {
        CloverView(size: .medium, color: AppColors.greenMuted)
    }

    /// Animated gold clover for celebrations
    static var celebration: CloverView {
        CloverView(size: .large, color: AppColors.gold, animated: true)
    }

    /// Small green clover for Obsidian tier badge accent
    static var obsidianAccent: CloverView {
        CloverView(size: .small, color: AppColors.gold)
    }
}

#Preview {
    VStack(spacing: 32) {
        CloverView(size: .small)
        CloverView(size: .medium)
        CloverView(size: .large, color: AppColors.gold, animated: true)
    }
    .padding()
    .background(AppColors.background)
}
