import Foundation
import FirebaseFirestore

struct Favorite: Identifiable, Codable {
    @DocumentID var id: String?
    var postId: String
    var userId: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, postId, userId, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        postId = try container.decodeIfPresent(String.self, forKey: .postId) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    init(
        id: String? = nil,
        postId: String,
        userId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Favorite {
    static var preview: Favorite {
        Favorite(
            id: "preview-favorite",
            postId: "preview-post",
            userId: "preview-user"
        )
    }
}
