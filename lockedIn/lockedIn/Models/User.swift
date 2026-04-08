import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var photoURL: String?
    var major: String?
    var dorm: String?
    var year: String?
    var spotifyPlaylistURL: String?
    var studyTools: [String]
    var primaryStudyTools: [String]
    var tips: String?
    var totalFocusedSeconds: Int
    var points: Int
    var dailyProductiveMinutes: Int
    var dailyNonProductiveMinutes: Int
    var screenTimeUpdatedAt: Date?
    var screenTimeVisibilityEnabled: Bool
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var selectedTitle: String?
    var selectedFrame: String?
    var unlockedCosmetics: [String]
    var onboardingCompletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, displayName, photoURL, major, dorm, year
        case spotifyPlaylistURL, studyTools, primaryStudyTools, tips, totalFocusedSeconds
        case points, dailyProductiveMinutes, dailyNonProductiveMinutes
        case screenTimeUpdatedAt, screenTimeVisibilityEnabled
        case currentStreak, longestStreak, lastActiveDate
        case selectedTitle, selectedFrame, unlockedCosmetics
        case onboardingCompletedAt, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // DocumentID is handled separately by Firestore
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        major = try container.decodeIfPresent(String.self, forKey: .major)
        dorm = try container.decodeIfPresent(String.self, forKey: .dorm)
        year = try container.decodeIfPresent(String.self, forKey: .year)
        spotifyPlaylistURL = try container.decodeIfPresent(String.self, forKey: .spotifyPlaylistURL)
        studyTools = try container.decodeIfPresent([String].self, forKey: .studyTools) ?? []
        primaryStudyTools = try container.decodeIfPresent([String].self, forKey: .primaryStudyTools) ?? []
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
        totalFocusedSeconds = try container.decodeIfPresent(Int.self, forKey: .totalFocusedSeconds) ?? 0
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
        dailyProductiveMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyProductiveMinutes) ?? 0
        dailyNonProductiveMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyNonProductiveMinutes) ?? 0
        screenTimeUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .screenTimeUpdatedAt)
        screenTimeVisibilityEnabled = try container.decodeIfPresent(Bool.self, forKey: .screenTimeVisibilityEnabled) ?? false
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        lastActiveDate = try container.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        selectedTitle = try container.decodeIfPresent(String.self, forKey: .selectedTitle)
        selectedFrame = try container.decodeIfPresent(String.self, forKey: .selectedFrame)
        unlockedCosmetics = try container.decodeIfPresent([String].self, forKey: .unlockedCosmetics) ?? []
        onboardingCompletedAt = try container.decodeIfPresent(Date.self, forKey: .onboardingCompletedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // MARK: - Computed Properties

    var tier: StatusTier {
        StatusTier.tier(for: points)
    }

    var formattedTotalTime: String {
        let hours = totalFocusedSeconds / 3600
        let minutes = (totalFocusedSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var yearOptions: [String] {
        ["Freshman", "Sophomore", "Junior", "Senior", "Graduate"]
    }

    init(
        id: String? = nil,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        major: String? = nil,
        dorm: String? = nil,
        year: String? = nil,
        spotifyPlaylistURL: String? = nil,
        studyTools: [String] = [],
        primaryStudyTools: [String] = [],
        tips: String? = nil,
        totalFocusedSeconds: Int = 0,
        points: Int = 0,
        dailyProductiveMinutes: Int = 0,
        dailyNonProductiveMinutes: Int = 0,
        screenTimeUpdatedAt: Date? = nil,
        screenTimeVisibilityEnabled: Bool = false,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastActiveDate: Date? = nil,
        selectedTitle: String? = nil,
        selectedFrame: String? = nil,
        unlockedCosmetics: [String] = [],
        onboardingCompletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.major = major
        self.dorm = dorm
        self.year = year
        self.spotifyPlaylistURL = spotifyPlaylistURL
        self.studyTools = studyTools
        self.primaryStudyTools = primaryStudyTools
        self.tips = tips
        self.totalFocusedSeconds = totalFocusedSeconds
        self.points = points
        self.dailyProductiveMinutes = dailyProductiveMinutes
        self.dailyNonProductiveMinutes = dailyNonProductiveMinutes
        self.screenTimeUpdatedAt = screenTimeUpdatedAt
        self.screenTimeVisibilityEnabled = screenTimeVisibilityEnabled
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
        self.selectedTitle = selectedTitle
        self.selectedFrame = selectedFrame
        self.unlockedCosmetics = unlockedCosmetics
        self.onboardingCompletedAt = onboardingCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension User {
    static var empty: User {
        User(email: "", displayName: "")
    }

    static var preview: User {
        User(
            id: "preview-user-id",
            email: "test@nd.edu",
            displayName: "Test User",
            major: "Computer Science",
            dorm: "Dillon Hall",
            year: "Junior",
            studyTools: ["Notion", "Anki", "Quizlet"],
            primaryStudyTools: ["Notion", "Anki"],
            tips: "I find that studying in Hesburgh Library helps me focus better.",
            totalFocusedSeconds: 36000,
            points: 8500,
            dailyProductiveMinutes: 210,
            dailyNonProductiveMinutes: 95,
            screenTimeUpdatedAt: Date(),
            screenTimeVisibilityEnabled: true,
            currentStreak: 7,
            longestStreak: 14,
            lastActiveDate: Date()
        )
    }
}
