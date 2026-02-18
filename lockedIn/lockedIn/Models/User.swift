import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var photoURL: String?
    var major: String?
    var year: String?
    var spotifyPlaylistURL: String?
    var studyTools: [String]
    var tips: String?
    var totalFocusedSeconds: Int
    var points: Int
    var selectedTitle: String?
    var selectedFrame: String?
    var unlockedCosmetics: [String]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, displayName, photoURL, major, year
        case spotifyPlaylistURL, studyTools, tips, totalFocusedSeconds
        case points, selectedTitle, selectedFrame, unlockedCosmetics
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // DocumentID is handled separately by Firestore
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        major = try container.decodeIfPresent(String.self, forKey: .major)
        year = try container.decodeIfPresent(String.self, forKey: .year)
        spotifyPlaylistURL = try container.decodeIfPresent(String.self, forKey: .spotifyPlaylistURL)
        studyTools = try container.decodeIfPresent([String].self, forKey: .studyTools) ?? []
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
        totalFocusedSeconds = try container.decodeIfPresent(Int.self, forKey: .totalFocusedSeconds) ?? 0
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
        selectedTitle = try container.decodeIfPresent(String.self, forKey: .selectedTitle)
        selectedFrame = try container.decodeIfPresent(String.self, forKey: .selectedFrame)
        unlockedCosmetics = try container.decodeIfPresent([String].self, forKey: .unlockedCosmetics) ?? []
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
        year: String? = nil,
        spotifyPlaylistURL: String? = nil,
        studyTools: [String] = [],
        tips: String? = nil,
        totalFocusedSeconds: Int = 0,
        points: Int = 0,
        selectedTitle: String? = nil,
        selectedFrame: String? = nil,
        unlockedCosmetics: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.major = major
        self.year = year
        self.spotifyPlaylistURL = spotifyPlaylistURL
        self.studyTools = studyTools
        self.tips = tips
        self.totalFocusedSeconds = totalFocusedSeconds
        self.points = points
        self.selectedTitle = selectedTitle
        self.selectedFrame = selectedFrame
        self.unlockedCosmetics = unlockedCosmetics
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
            year: "Junior",
            studyTools: ["Notion", "Anki", "Quizlet"],
            tips: "I find that studying in Hesburgh Library helps me focus better.",
            totalFocusedSeconds: 36000,
            points: 8500
        )
    }
}
