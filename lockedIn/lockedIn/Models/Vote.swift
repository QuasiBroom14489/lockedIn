import Foundation
import FirebaseFirestore

enum VoteType: String, Codable, CaseIterable {
    case upvote
    case downvote
    case none

    var scoreDelta: Int {
        switch self {
        case .upvote: return 1
        case .downvote: return -1
        case .none: return 0
        }
    }
}

struct Vote: Identifiable, Codable {
    @DocumentID var id: String?
    var postId: String
    var userId: String
    var type: VoteType
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, postId, userId, type, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        postId = try container.decodeIfPresent(String.self, forKey: .postId) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        type = try container.decodeIfPresent(VoteType.self, forKey: .type) ?? .none
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    init(
        id: String? = nil,
        postId: String,
        userId: String,
        type: VoteType,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Vote {
    static var previewUpvote: Vote {
        Vote(
            id: "preview-vote-up",
            postId: "preview-post",
            userId: "preview-user",
            type: .upvote
        )
    }

    static var previewDownvote: Vote {
        Vote(
            id: "preview-vote-down",
            postId: "preview-post",
            userId: "preview-user-2",
            type: .downvote
        )
    }
}
