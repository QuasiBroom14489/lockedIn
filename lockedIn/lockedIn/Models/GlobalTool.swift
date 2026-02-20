import Foundation
import FirebaseFirestore

struct GlobalTool: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    var aliases: [String]
    var category: String?
    var createdByUserId: String
    var usageCount: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case aliases
        case category
        case createdByUserId
        case usageCount
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        displayName: String,
        aliases: [String] = [],
        category: String? = nil,
        createdByUserId: String,
        usageCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.aliases = aliases
        self.category = category
        self.createdByUserId = createdByUserId
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func normalizedId(from value: String) -> String {
        let uppercased = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let collapsed = uppercased.replacingOccurrences(
            of: "[^A-Z0-9]+",
            with: "_",
            options: .regularExpression
        )

        return collapsed
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    static func normalizedAliasKeys(from value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalized = normalizedId(from: trimmed)
        let compact = trimmed
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)

        return Array(Set([normalized, compact].filter { !$0.isEmpty }))
    }
}
