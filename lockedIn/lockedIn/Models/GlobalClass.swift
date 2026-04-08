import Foundation
import FirebaseFirestore

// MARK: - Catalog School Enum

enum CatalogSchool: String, CaseIterable, Codable {
    case holyCross = "Holy Cross"
    case notreDame = "Notre Dame"

    var shortName: String {
        switch self {
        case .holyCross: return "HC"
        case .notreDame: return "ND"
        }
    }
}

// MARK: - GlobalClass Model

struct GlobalClass: Identifiable, Codable, Hashable {
    var id: String
    var courseCode: String
    var displayName: String?
    var instructorName: String?
    var recentTerms: [String]
    var instructorNames: [String]
    var aliases: [String]
    var createdByUserId: String
    var memberCount: Int
    var createdAt: Date
    var updatedAt: Date

    // Catalog fields
    var isCatalogCourse: Bool?
    var school: String?
    var department: String?
    var credits: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case courseCode
        case displayName
        case instructorName
        case recentTerms
        case instructorNames
        case aliases
        case createdByUserId
        case memberCount
        case createdAt
        case updatedAt
        case isCatalogCourse
        case school
        case department
        case credits
    }

    init(
        id: String,
        courseCode: String,
        displayName: String? = nil,
        instructorName: String? = nil,
        recentTerms: [String] = [],
        instructorNames: [String] = [],
        aliases: [String] = [],
        createdByUserId: String,
        memberCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isCatalogCourse: Bool? = nil,
        school: String? = nil,
        department: String? = nil,
        credits: Int? = nil
    ) {
        self.id = id
        self.courseCode = courseCode
        self.displayName = displayName
        self.instructorName = instructorName
        self.recentTerms = recentTerms
        self.instructorNames = instructorNames
        self.aliases = aliases
        self.createdByUserId = createdByUserId
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isCatalogCourse = isCatalogCourse
        self.school = school
        self.department = department
        self.credits = credits
    }

    static func normalizedId(from courseCode: String) -> String {
        courseCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
    }

    /// Extracts department prefix from course code (e.g., "THEO" from "THEO10001")
    static func extractDepartment(from courseCode: String) -> String? {
        let normalized = normalizedId(from: courseCode)
        let letters = normalized.prefix(while: { $0.isLetter })
        return letters.isEmpty ? nil : String(letters)
    }

    /// Returns the CatalogSchool enum if school string matches
    var catalogSchool: CatalogSchool? {
        guard let school = school else { return nil }
        return CatalogSchool(rawValue: school)
    }
}

struct UserClassMembership: Identifiable, Codable, Hashable {
    var id: String
    var classId: String
    var term: String
    var teacherReview: String
    var teacherRating: Int?
    var spotifyLinks: [SpotifyLink]
    var helpfulWebsites: [HelpfulLink]
    var joinedAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case classId
        case term
        case teacherReview
        case teacherRating
        case spotifyLinks
        case helpfulWebsites
        case joinedAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        classId = try container.decodeIfPresent(String.self, forKey: .classId) ?? id
        term = try container.decodeIfPresent(String.self, forKey: .term) ?? ""
        teacherReview = try container.decodeIfPresent(String.self, forKey: .teacherReview) ?? ""
        teacherRating = try container.decodeIfPresent(Int.self, forKey: .teacherRating)
        spotifyLinks = try container.decodeIfPresent([SpotifyLink].self, forKey: .spotifyLinks) ?? []
        helpfulWebsites = try container.decodeIfPresent([HelpfulLink].self, forKey: .helpfulWebsites) ?? []
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    init(
        id: String? = nil,
        classId: String,
        term: String = "",
        teacherReview: String = "",
        teacherRating: Int? = nil,
        spotifyLinks: [SpotifyLink] = [],
        helpfulWebsites: [HelpfulLink] = [],
        joinedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id ?? classId
        self.classId = classId
        self.term = term
        self.teacherReview = teacherReview
        self.teacherRating = teacherRating
        self.spotifyLinks = spotifyLinks
        self.helpfulWebsites = helpfulWebsites
        self.joinedAt = joinedAt
        self.updatedAt = updatedAt
    }
}

struct UserClassMembershipSeed {
    var teacherReview: String?
    var teacherRating: Int?
    var spotifyLinks: [SpotifyLink]
    var helpfulWebsites: [HelpfulLink]

    init(
        teacherReview: String? = nil,
        teacherRating: Int? = nil,
        spotifyLinks: [SpotifyLink] = [],
        helpfulWebsites: [HelpfulLink] = []
    ) {
        self.teacherReview = teacherReview
        self.teacherRating = teacherRating
        self.spotifyLinks = spotifyLinks
        self.helpfulWebsites = helpfulWebsites
    }
}

struct ProfileClassItem: Identifiable, Hashable {
    var global: GlobalClass
    var membership: UserClassMembership

    var id: String { global.id }
}

enum ClassDashboardPeriod: String, CaseIterable {
    case allTime = "All Time"
    case weekly = "Weekly"

    var cutoffDate: Date {
        switch self {
        case .allTime:
            return Date.distantPast
        case .weekly:
            return Date().addingTimeInterval(-(7 * 24 * 60 * 60))
        }
    }
}
