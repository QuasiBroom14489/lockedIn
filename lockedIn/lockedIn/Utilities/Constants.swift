import Foundation
import SwiftUI

enum Constants {
    enum Firebase {
        static let usersCollection = "users"
        static let globalClassesCollection = "classes"
        static let sessionsCollection = "sessions"
        static let followingCollection = "following"
        static let followersCollection = "followers"
        static let classesCollection = "classes"
        static let leaderboardCollection = "leaderboard"
        static let studyPostsCollection = "studyPosts"
        static let votesCollection = "votes"
        static let favoritesCollection = "favorites"
        static let toolsCollection = "tools"
    }

    enum Storage {
        static let profilePhotosPath = "profile_photos"
    }

    enum Session {
        static let minimumDurationSeconds = 60
        static let verificationIntervalSeconds = 30
        static let defaultDurationMinutes = 25
        static let tipRotationInterval: TimeInterval = 30
        static let focusTips: [String] = [
            "One focused minute now saves ten later.",
            "Small progress compounds. Keep going.",
            "Protect this block. Your future self will thank you.",
            "Deep work first, dopamine later.",
            "Finish the next chunk, not the whole mountain.",
            "Discipline beats motivation when it counts.",
            "You are building study momentum right now.",
            "Stay in the app, stay in flow.",
            "Your consistency is your competitive edge.",
            "Focus is a skill. You are training it.",
            "One session at a time, one win at a time.",
            "Less switching, more finishing.",
            "Locked in now means less stress later.",
            "Keep attention on what moves grades forward.",
            "You do not need perfect, just focused."
        ]
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 50
        static let profileImageSize: CGFloat = 100
        static let leaderboardRowImageSize: CGFloat = 44
        static let feedRowImageSize: CGFloat = 40
        static let postCardCornerRadius: CGFloat = 18
        static let postCardVerticalSpacing: CGFloat = 14
        static let postChipCornerRadius: CGFloat = 12
        static let postCollapsedLineLimit: Int = 3
        static let postCollapsedStackCount: Int = 2
        static let focusCardCornerRadius: CGFloat = 20
        static let focusHeroPadding: CGFloat = 18
        static let focusAmbientOpacity: Double = 0.35
        static let focusAnimationDuration: Double = 0.35
        static let miniPlayerControlSize: CGFloat = 38
    }

    enum Spotify {
        // TODO: Replace with your Spotify Developer app credentials
        static let clientID = "1c378f859f5c4b40ba4c4b20bcf68f64"
        static let redirectURL = URL(string: "lockedin://spotify-callback")!
        static let scopes: [String] = [
            "app-remote-control",
            "user-modify-playback-state",
            "user-read-playback-state",
            "user-read-currently-playing"
        ]
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

    static func focusDisplay() -> Font {
        .system(size: 76, weight: .bold, design: .rounded)
    }

    static func focusHeader() -> Font {
        .system(size: 24, weight: .bold, design: .rounded)
    }

    static func focusBody() -> Font {
        .system(size: 17, weight: .regular, design: .rounded)
    }

    static func focusCaption() -> Font {
        .system(size: 13, weight: .medium, design: .rounded)
    }
}
