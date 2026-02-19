import Foundation

struct StudyStackItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var toolName: String
    var linkURL: String?
    var usageNote: String?

    init(
        id: String = UUID().uuidString,
        toolName: String,
        linkURL: String? = nil,
        usageNote: String? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.linkURL = linkURL
        self.usageNote = usageNote
    }
}
