import Foundation
import FirebaseAnalytics

final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Focus Session Events

    func logFocusSessionStarted(durationGoal: Int) {
        Analytics.logEvent("focus_session_started", parameters: [
            "duration_goal_seconds": durationGoal
        ])
    }

    func logFocusSessionCompleted(durationSeconds: Int, pointsEarned: Int) {
        Analytics.logEvent("focus_session_completed", parameters: [
            "duration_seconds": durationSeconds,
            "points_earned": pointsEarned
        ])
    }

    func logFocusSessionEndedBackground(durationSeconds: Int) {
        Analytics.logEvent("focus_session_ended_background", parameters: [
            "duration_seconds": durationSeconds
        ])
    }

    func logFocusTipDisplayed(tipIndex: Int) {
        Analytics.logEvent("focus_tip_displayed", parameters: [
            "tip_index": tipIndex
        ])
    }

    // MARK: - Screen Time Events

    func logScreenTimeSynced(productiveMinutes: Int, nonProductiveMinutes: Int) {
        Analytics.logEvent("screen_time_synced", parameters: [
            "productive_minutes": productiveMinutes,
            "non_productive_minutes": nonProductiveMinutes,
            "total_minutes": productiveMinutes + nonProductiveMinutes
        ])
    }

    // MARK: - Post Events

    func logPostCreated(type: String, toolCount: Int, tagCount: Int) {
        let eventName = type == "stack" ? "post_created_stack" : "post_created_suggestion"
        Analytics.logEvent(eventName, parameters: [
            "tool_count": toolCount,
            "tag_count": tagCount
        ])
    }

    func logPostDeleted(postId: String) {
        Analytics.logEvent("post_deleted", parameters: [
            "post_id": postId
        ])
    }

    // MARK: - Voting Events

    func logVote(postId: String, voteType: String) {
        Analytics.logEvent("post_voted", parameters: [
            "post_id": postId,
            "vote_type": voteType
        ])
    }

    func logFavoriteToggled(postId: String, isFavorited: Bool) {
        Analytics.logEvent("post_favorite_toggled", parameters: [
            "post_id": postId,
            "is_favorited": isFavorited
        ])
    }

    // MARK: - Profile Events

    func logProfileTabChanged(tab: String) {
        Analytics.logEvent("profile_tab_changed", parameters: [
            "tab": tab
        ])
    }

    func logProfileViewed(isOwnProfile: Bool) {
        Analytics.logEvent("profile_viewed", parameters: [
            "is_own_profile": isOwnProfile
        ])
    }

    // MARK: - Leaderboard Events

    func logLeaderboardViewed(period: String, showFriendsOnly: Bool) {
        Analytics.logEvent("leaderboard_viewed", parameters: [
            "period": period,
            "friends_only": showFriendsOnly
        ])
    }

    // MARK: - Social Events

    func logUserFollowed(targetUserId: String) {
        Analytics.logEvent("user_followed", parameters: [
            "target_user_id": targetUserId
        ])
    }

    func logUserUnfollowed(targetUserId: String) {
        Analytics.logEvent("user_unfollowed", parameters: [
            "target_user_id": targetUserId
        ])
    }
}
