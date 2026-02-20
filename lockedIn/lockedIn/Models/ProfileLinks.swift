import Foundation

struct SpotifyLink: Identifiable, Codable, Hashable {
    var id: String
    var url: String
    var title: String?
    var note: String?
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        url: String,
        title: String? = nil,
        note: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.note = note
        self.addedAt = addedAt
    }
}

struct HelpfulLink: Identifiable, Codable, Hashable {
    var id: String
    var url: String
    var title: String
    var note: String?
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        url: String,
        title: String,
        note: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.note = note
        self.addedAt = addedAt
    }
}
