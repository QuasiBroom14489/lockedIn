import Foundation
import FirebaseFirestore

struct LeaderboardEntry: Identifiable, Codable {
    var id: String { userId }
    var userId: String
    var displayName: String
    var photoURL: String?
    var totalSeconds: Int
    var rank: Int
    var points: Int

    var tier: StatusTier {
        StatusTier.tier(for: points)
    }

    var formattedTime: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    init(
        userId: String,
        displayName: String,
        photoURL: String? = nil,
        totalSeconds: Int,
        rank: Int,
        points: Int = 0
    ) {
        self.userId = userId
        self.displayName = displayName
        self.photoURL = photoURL
        self.totalSeconds = totalSeconds
        self.rank = rank
        self.points = points
    }

    init(from user: User, rank: Int) {
        self.userId = user.id ?? UUID().uuidString
        self.displayName = user.displayName
        self.photoURL = user.photoURL
        self.totalSeconds = user.totalFocusedSeconds
        self.rank = rank
        self.points = user.points
    }
}

extension LeaderboardEntry {
    static var preview: LeaderboardEntry {
        LeaderboardEntry(
            userId: "preview-user-id",
            displayName: "Test User",
            totalSeconds: 36000,
            rank: 1,
            points: 5500
        )
    }

    static var previewList: [LeaderboardEntry] {
        [
            LeaderboardEntry(userId: "1", displayName: "Alice Johnson", totalSeconds: 72000, rank: 1, points: 45000),
            LeaderboardEntry(userId: "2", displayName: "Bob Smith", totalSeconds: 64800, rank: 2, points: 18000),
            LeaderboardEntry(userId: "3", displayName: "Charlie Brown", totalSeconds: 54000, rank: 3, points: 7500),
            LeaderboardEntry(userId: "4", displayName: "Diana Ross", totalSeconds: 43200, rank: 4, points: 2500),
            LeaderboardEntry(userId: "5", displayName: "Eve Wilson", totalSeconds: 36000, rank: 5, points: 800)
        ]
    }
}

enum LeaderboardPeriod: String, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case allTime = "allTime"

    var displayName: String {
        switch self {
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .allTime: return "All Time"
        }
    }

    var cutoffDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime:
            return Date.distantPast
        }
    }
}
