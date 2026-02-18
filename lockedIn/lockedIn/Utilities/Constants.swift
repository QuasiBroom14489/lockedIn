import Foundation
import SwiftUI

enum Constants {
    enum Firebase {
        static let usersCollection = "users"
        static let sessionsCollection = "sessions"
        static let followingCollection = "following"
        static let followersCollection = "followers"
        static let leaderboardCollection = "leaderboard"
    }

    enum Storage {
        static let profilePhotosPath = "profile_photos"
    }

    enum Session {
        static let minimumDurationSeconds = 60
        static let verificationIntervalSeconds = 30
        static let defaultDurationMinutes = 25
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 50
        static let profileImageSize: CGFloat = 100
        static let leaderboardRowImageSize: CGFloat = 44
        static let feedRowImageSize: CGFloat = 40
    }
}

enum AppColors {
    // MARK: - Notre Dame Navy Backgrounds
    static let background = Color(hex: "0C2340")
    static let backgroundSecondary = Color(hex: "0F2A4A")
    static let surface = Color(hex: "143254")
    static let surfaceElevated = Color(hex: "1A3A5E")

    // MARK: - Borders
    static let border = Color(hex: "1E4468")
    static let borderSubtle = Color(hex: "163050")

    // MARK: - Notre Dame Gold
    static let gold = Color(hex: "C7A32E")
    static let goldLight = Color(hex: "D4B84A")
    static let goldMuted = Color(hex: "8B7220")

    // MARK: - Notre Dame Green
    static let green = Color(hex: "00843D")
    static let greenLight = Color(hex: "00A34B")
    static let greenMuted = Color(hex: "005C2A")

    // MARK: - Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // MARK: - Legacy (for compatibility)
    static let navyBlue = gold // Redirect to gold for dark mode
    static let primary = gold
    static let secondary = surface
    static let cardBackground = surface

    // MARK: - Status Colors
    static let success = Color(hex: "00A34B")
    static let warning = Color.orange
    static let error = Color.red
}

enum AppFonts {
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    static func headline() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }

    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .rounded)
    }

    static func caption() -> Font {
        .system(size: 14, weight: .regular, design: .rounded)
    }

    static func timer() -> Font {
        .system(size: 72, weight: .bold, design: .monospaced)
    }
}
