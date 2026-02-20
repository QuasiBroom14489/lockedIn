import Foundation
import FirebaseFirestore

struct UserClass: Identifiable, Codable, Hashable {
    var id: String
    var courseCode: String
    var term: String
    var displayName: String?
    var instructorName: String?
    var teacherReview: String
    var teacherRating: Int?
    var spotifyLinks: [SpotifyLink]
    var helpfulWebsites: [HelpfulLink]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case courseCode
        case term
        case displayName
        case instructorName
        case teacherReview
        case teacherRating
        case spotifyLinks
        case helpfulWebsites
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        term = try container.decodeIfPresent(String.self, forKey: .term) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        instructorName = try container.decodeIfPresent(String.self, forKey: .instructorName)
        teacherReview = try container.decodeIfPresent(String.self, forKey: .teacherReview) ?? ""
        teacherRating = try container.decodeIfPresent(Int.self, forKey: .teacherRating)
        spotifyLinks = try container.decodeIfPresent([SpotifyLink].self, forKey: .spotifyLinks) ?? []
        helpfulWebsites = try container.decodeIfPresent([HelpfulLink].self, forKey: .helpfulWebsites) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    init(
        id: String? = nil,
        courseCode: String,
        term: String,
        displayName: String? = nil,
        instructorName: String? = nil,
        teacherReview: String = "",
        teacherRating: Int? = nil,
        spotifyLinks: [SpotifyLink] = [],
        helpfulWebsites: [HelpfulLink] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let normalizedCode = courseCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        let normalizedTerm = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")

        self.id = id ?? "\(normalizedCode)_\(normalizedTerm)"
        self.courseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.instructorName = instructorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.teacherReview = teacherReview
        self.teacherRating = teacherRating
        self.spotifyLinks = spotifyLinks
        self.helpfulWebsites = helpfulWebsites
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ClassDashboard: Codable, Equatable {
    var topTools: [ToolUsageStat]
    var topStackPatterns: [StackPatternCount]
    var topTipTags: [TagUsageStat]
    var postCount: Int
    var stackCount: Int
    var tipCount: Int
    var lastUpdatedComputedAt: Date

    static var empty: ClassDashboard {
        ClassDashboard(
            topTools: [],
            topStackPatterns: [],
            topTipTags: [],
            postCount: 0,
            stackCount: 0,
            tipCount: 0,
            lastUpdatedComputedAt: Date()
        )
    }
}

struct ToolUsageStat: Codable, Hashable, Identifiable {
    var tool: String
    var count: Int

    var id: String { tool }
}

struct StackPatternCount: Codable, Hashable, Identifiable {
    var pattern: String
    var count: Int

    var id: String { pattern }
}

struct TagUsageStat: Codable, Hashable, Identifiable {
    var tag: String
    var count: Int

    var id: String { tag }
}
