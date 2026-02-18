import Foundation
import SwiftUI

enum StatusTier: String, CaseIterable, Codable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case obsidian

    // MARK: - Point Thresholds

    var minimumPoints: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1_000
        case .gold: return 5_000
        case .platinum: return 15_000
        case .diamond: return 40_000
        case .obsidian: return 100_000
        }
    }

    var maximumPoints: Int? {
        switch self {
        case .bronze: return 999
        case .silver: return 4_999
        case .gold: return 14_999
        case .platinum: return 39_999
        case .diamond: return 99_999
        case .obsidian: return nil
        }
    }

    // MARK: - Display Properties

    var title: String {
        switch self {
        case .bronze: return "Novice"
        case .silver: return "Apprentice"
        case .gold: return "Scholar"
        case .platinum: return "Elite"
        case .diamond: return "Master"
        case .obsidian: return "Legend"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    var formattedTitle: String {
        "◆ \(displayName) \(title)"
    }

    // MARK: - Colors

    var color: Color {
        switch self {
        case .bronze: return Color(hex: "8B7355")
        case .silver: return Color(hex: "9CA3AF")
        case .gold: return Color(hex: "C7A32E")
        case .platinum: return Color(hex: "A3B8CC")
        case .diamond: return Color(hex: "60A5FA")
        case .obsidian: return Color(hex: "1F2937")
        }
    }

    var accentColor: Color {
        switch self {
        case .obsidian: return Color(hex: "C7A32E") // Gold accent for obsidian
        default: return color
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(hex: "8B7355"), Color(hex: "6B5344")]
        case .silver:
            return [Color(hex: "C0C0C0"), Color(hex: "9CA3AF")]
        case .gold:
            return [Color(hex: "D4AF37"), Color(hex: "C7A32E")]
        case .platinum:
            return [Color(hex: "C0D6E8"), Color(hex: "A3B8CC")]
        case .diamond:
            return [Color(hex: "93C5FD"), Color(hex: "60A5FA"), Color(hex: "3B82F6")]
        case .obsidian:
            return [Color(hex: "374151"), Color(hex: "1F2937"), Color(hex: "C7A32E")]
        }
    }

    // MARK: - Ring Styling

    var ringWidth: CGFloat {
        switch self {
        case .bronze: return 2
        case .silver: return 2.5
        case .gold: return 3
        case .platinum: return 3
        case .diamond: return 3.5
        case .obsidian: return 4
        }
    }

    var hasGlow: Bool {
        switch self {
        case .bronze, .silver: return false
        case .gold, .platinum, .diamond, .obsidian: return true
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .bronze, .silver: return 0
        case .gold: return 4
        case .platinum: return 5
        case .diamond: return 6
        case .obsidian: return 8
        }
    }

    var hasAnimation: Bool {
        switch self {
        case .bronze, .silver: return false
        case .gold, .platinum, .diamond, .obsidian: return true
        }
    }

    // MARK: - Cosmetic Unlocks

    var unlockedCosmetics: [CosmeticUnlock] {
        switch self {
        case .bronze:
            return []
        case .silver:
            return [.customBannerColors]
        case .gold:
            return [.customBannerColors, .animatedAvatarRing]
        case .platinum:
            return [.customBannerColors, .animatedAvatarRing, .profileGradientBackgrounds]
        case .diamond:
            return [.customBannerColors, .animatedAvatarRing, .profileGradientBackgrounds, .customTitleText, .exclusiveFrames]
        case .obsidian:
            return CosmeticUnlock.allCases
        }
    }

    // MARK: - Tier Calculation

    static func tier(for points: Int) -> StatusTier {
        if points >= StatusTier.obsidian.minimumPoints {
            return .obsidian
        } else if points >= StatusTier.diamond.minimumPoints {
            return .diamond
        } else if points >= StatusTier.platinum.minimumPoints {
            return .platinum
        } else if points >= StatusTier.gold.minimumPoints {
            return .gold
        } else if points >= StatusTier.silver.minimumPoints {
            return .silver
        } else {
            return .bronze
        }
    }

    var nextTier: StatusTier? {
        switch self {
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .platinum
        case .platinum: return .diamond
        case .diamond: return .obsidian
        case .obsidian: return nil
        }
    }

    func progressToNextTier(currentPoints: Int) -> Double {
        guard let next = nextTier, maximumPoints != nil else { return 1.0 }
        let pointsInTier = currentPoints - minimumPoints
        let tierRange = next.minimumPoints - minimumPoints
        return Double(pointsInTier) / Double(tierRange)
    }

    func pointsToNextTier(currentPoints: Int) -> Int? {
        guard let next = nextTier else { return nil }
        return next.minimumPoints - currentPoints
    }
}

// MARK: - Cosmetic Unlocks

enum CosmeticUnlock: String, CaseIterable, Codable {
    case customBannerColors = "custom_banner_colors"
    case animatedAvatarRing = "animated_avatar_ring"
    case profileGradientBackgrounds = "profile_gradient_backgrounds"
    case customTitleText = "custom_title_text"
    case exclusiveFrames = "exclusive_frames"
    case foundingMemberBadge = "founding_member_badge"

    var displayName: String {
        switch self {
        case .customBannerColors: return "Custom Banner Colors"
        case .animatedAvatarRing: return "Animated Avatar Ring"
        case .profileGradientBackgrounds: return "Profile Gradient Backgrounds"
        case .customTitleText: return "Custom Title Text"
        case .exclusiveFrames: return "Exclusive Frames"
        case .foundingMemberBadge: return "Founding Member Badge"
        }
    }

    var requiredTier: StatusTier {
        switch self {
        case .customBannerColors: return .silver
        case .animatedAvatarRing: return .gold
        case .profileGradientBackgrounds: return .platinum
        case .customTitleText: return .diamond
        case .exclusiveFrames: return .diamond
        case .foundingMemberBadge: return .obsidian
        }
    }
}

// MARK: - Points System Reference

enum PointsAction {
    case focusSessionPerMinute
    case uploadClass
    case verifyGradeA
    case verifyGradeB
    case verifyGradeC
    case studyStackView
    case newFollower

    var points: Int {
        switch self {
        case .focusSessionPerMinute: return 1
        case .uploadClass: return 10
        case .verifyGradeA: return 25
        case .verifyGradeB: return 15
        case .verifyGradeC: return 5
        case .studyStackView: return 2
        case .newFollower: return 5
        }
    }

    var description: String {
        switch self {
        case .focusSessionPerMinute: return "Focus session (per minute)"
        case .uploadClass: return "Upload a class"
        case .verifyGradeA: return "Verify grade (A)"
        case .verifyGradeB: return "Verify grade (B)"
        case .verifyGradeC: return "Verify grade (C)"
        case .studyStackView: return "Study Stack viewed"
        case .newFollower: return "New follower"
        }
    }
}

// MARK: - Preview Helpers

extension StatusTier {
    static var previewTiers: [(tier: StatusTier, points: Int)] {
        [
            (.bronze, 500),
            (.silver, 2500),
            (.gold, 10000),
            (.platinum, 25000),
            (.diamond, 75000),
            (.obsidian, 150000)
        ]
    }
}
