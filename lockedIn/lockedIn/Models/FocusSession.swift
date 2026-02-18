import Foundation
import FirebaseFirestore

struct FocusSession: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var startTime: Date
    var endTime: Date?
    var durationSeconds: Int
    var verified: Bool
    var completedAt: Date?

    var isActive: Bool {
        endTime == nil
    }

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: completedAt ?? startTime, relativeTo: Date())
    }

    init(
        id: String? = nil,
        userId: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationSeconds: Int = 0,
        verified: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.verified = verified
        self.completedAt = completedAt
    }
}

extension FocusSession {
    static var preview: FocusSession {
        FocusSession(
            id: "preview-session-id",
            userId: "preview-user-id",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            durationSeconds: 3600,
            verified: true,
            completedAt: Date()
        )
    }
}

struct FeedItem: Identifiable {
    let id: String
    let session: FocusSession
    let user: User

    init(session: FocusSession, user: User) {
        self.id = session.id ?? UUID().uuidString
        self.session = session
        self.user = user
    }
}
