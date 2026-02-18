import Foundation
import FirebaseFirestore

enum StudyPostType: String, Codable, CaseIterable {
    case stack
    case tip

    var displayName: String {
        switch self {
        case .stack: return "Study Stack"
        case .tip: return "Study Tip"
        }
    }
}

struct StudyPost: Identifiable, Codable {
    @DocumentID var id: String?
    var authorId: String
    var authorName: String
    var authorPhotoURL: String?
    var type: StudyPostType
    var title: String
    var content: String
    var tools: [String]
    var tags: [String]
    var upvoteCount: Int
    var downvoteCount: Int
    var favoriteCount: Int
    var hotScore: Double
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, authorId, authorName, authorPhotoURL
        case type, title, content, tools, tags
        case upvoteCount, downvoteCount, favoriteCount, hotScore
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        authorId = try container.decodeIfPresent(String.self, forKey: .authorId) ?? ""
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName) ?? "Anonymous"
        authorPhotoURL = try container.decodeIfPresent(String.self, forKey: .authorPhotoURL)
        type = try container.decodeIfPresent(StudyPostType.self, forKey: .type) ?? .tip
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        tools = try container.decodeIfPresent([String].self, forKey: .tools) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        upvoteCount = try container.decodeIfPresent(Int.self, forKey: .upvoteCount) ?? 0
        downvoteCount = try container.decodeIfPresent(Int.self, forKey: .downvoteCount) ?? 0
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        hotScore = try container.decodeIfPresent(Double.self, forKey: .hotScore) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    init(
        id: String? = nil,
        authorId: String,
        authorName: String,
        authorPhotoURL: String? = nil,
        type: StudyPostType,
        title: String,
        content: String,
        tools: [String] = [],
        tags: [String] = [],
        upvoteCount: Int = 0,
        downvoteCount: Int = 0,
        favoriteCount: Int = 0,
        hotScore: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorPhotoURL = authorPhotoURL
        self.type = type
        self.title = title
        self.content = content
        self.tools = tools
        self.tags = tags
        self.upvoteCount = upvoteCount
        self.downvoteCount = downvoteCount
        self.favoriteCount = favoriteCount
        self.hotScore = hotScore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var score: Int {
        upvoteCount - downvoteCount
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension StudyPost {
    static var preview: StudyPost {
        StudyPost(
            id: "preview-post",
            authorId: "preview-user",
            authorName: "Alex Student",
            type: .stack,
            title: "My 90-minute exam prep stack",
            content: "25m deep work, 5m break, then active recall on 30 flashcards.",
            tools: ["Anki", "Notion", "Forest"],
            tags: ["exam", "deep-work", "active-recall"],
            upvoteCount: 32,
            downvoteCount: 3,
            favoriteCount: 18,
            hotScore: 78.4,
            createdAt: Date().addingTimeInterval(-60 * 60 * 4),
            updatedAt: Date().addingTimeInterval(-60 * 60 * 2)
        )
    }
}
