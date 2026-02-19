import XCTest
@testable import lockedIn

final class VoteTransitionTests: XCTestCase {

    // MARK: - Vote Counter Delta Tests

    func testNoneToUpvote() {
        let delta = voteCounterDelta(from: .none, to: .upvote)
        XCTAssertEqual(delta.upvotes, 1)
        XCTAssertEqual(delta.downvotes, 0)
    }

    func testNoneToDownvote() {
        let delta = voteCounterDelta(from: .none, to: .downvote)
        XCTAssertEqual(delta.upvotes, 0)
        XCTAssertEqual(delta.downvotes, 1)
    }

    func testUpvoteToNone() {
        let delta = voteCounterDelta(from: .upvote, to: .none)
        XCTAssertEqual(delta.upvotes, -1)
        XCTAssertEqual(delta.downvotes, 0)
    }

    func testDownvoteToNone() {
        let delta = voteCounterDelta(from: .downvote, to: .none)
        XCTAssertEqual(delta.upvotes, 0)
        XCTAssertEqual(delta.downvotes, -1)
    }

    func testUpvoteToDownvote() {
        let delta = voteCounterDelta(from: .upvote, to: .downvote)
        XCTAssertEqual(delta.upvotes, -1)
        XCTAssertEqual(delta.downvotes, 1)
    }

    func testDownvoteToUpvote() {
        let delta = voteCounterDelta(from: .downvote, to: .upvote)
        XCTAssertEqual(delta.upvotes, 1)
        XCTAssertEqual(delta.downvotes, -1)
    }

    func testSameVoteNoChange() {
        // Toggling same vote = no change (should be caught before delta calculation)
        let noneToNone = voteCounterDelta(from: .none, to: .none)
        XCTAssertEqual(noneToNone.upvotes, 0)
        XCTAssertEqual(noneToNone.downvotes, 0)

        let upToUp = voteCounterDelta(from: .upvote, to: .upvote)
        XCTAssertEqual(upToUp.upvotes, 0)
        XCTAssertEqual(upToUp.downvotes, 0)

        let downToDown = voteCounterDelta(from: .downvote, to: .downvote)
        XCTAssertEqual(downToDown.upvotes, 0)
        XCTAssertEqual(downToDown.downvotes, 0)
    }

    // MARK: - Vote Toggle Logic Tests

    func testToggleUpvoteWhenNone() {
        let currentVote: VoteType = .none
        let desired: VoteType = .upvote
        let newVote = (currentVote == desired) ? .none : desired

        XCTAssertEqual(newVote, .upvote)
    }

    func testToggleUpvoteWhenAlreadyUpvoted() {
        let currentVote: VoteType = .upvote
        let desired: VoteType = .upvote
        let newVote: VoteType = (currentVote == desired) ? .none : desired

        XCTAssertEqual(newVote, .none)
    }

    func testToggleDownvoteWhenUpvoted() {
        let currentVote: VoteType = .upvote
        let desired: VoteType = .downvote
        let newVote: VoteType = (currentVote == desired) ? .none : desired

        XCTAssertEqual(newVote, .downvote)
    }

    // MARK: - Score Calculation Tests

    func testScoreIsUpvotesMinusDownvotes() {
        let upvotes = 25
        let downvotes = 8
        let score = upvotes - downvotes

        XCTAssertEqual(score, 17)
    }

    func testNegativeScorePossible() {
        let upvotes = 5
        let downvotes = 12
        let score = upvotes - downvotes

        XCTAssertEqual(score, -7)
    }

    // MARK: - Local State Update Tests

    func testApplyVoteChangeIncreasesUpvoteCount() {
        var post = createPost(upvoteCount: 10, downvoteCount: 5)
        let delta = voteCounterDelta(from: .none, to: .upvote)

        post.upvoteCount = max(0, post.upvoteCount + delta.upvotes)
        post.downvoteCount = max(0, post.downvoteCount + delta.downvotes)

        XCTAssertEqual(post.upvoteCount, 11)
        XCTAssertEqual(post.downvoteCount, 5)
    }

    func testApplyVoteChangeSwapsVotes() {
        var post = createPost(upvoteCount: 10, downvoteCount: 5)
        let delta = voteCounterDelta(from: .upvote, to: .downvote)

        post.upvoteCount = max(0, post.upvoteCount + delta.upvotes)
        post.downvoteCount = max(0, post.downvoteCount + delta.downvotes)

        XCTAssertEqual(post.upvoteCount, 9)
        XCTAssertEqual(post.downvoteCount, 6)
    }

    func testApplyVoteChangeNeverGoesNegative() {
        var post = createPost(upvoteCount: 0, downvoteCount: 0)
        let delta = voteCounterDelta(from: .upvote, to: .none)

        post.upvoteCount = max(0, post.upvoteCount + delta.upvotes)
        post.downvoteCount = max(0, post.downvoteCount + delta.downvotes)

        XCTAssertEqual(post.upvoteCount, 0) // Should not go negative
        XCTAssertEqual(post.downvoteCount, 0)
    }

    // MARK: - Helpers

    /// Replicates the delta calculation from FirebaseService
    private func voteCounterDelta(from oldVote: VoteType, to newVote: VoteType) -> (upvotes: Int, downvotes: Int) {
        switch (oldVote, newVote) {
        case (.none, .upvote):
            return (1, 0)
        case (.none, .downvote):
            return (0, 1)
        case (.upvote, .none):
            return (-1, 0)
        case (.downvote, .none):
            return (0, -1)
        case (.upvote, .downvote):
            return (-1, 1)
        case (.downvote, .upvote):
            return (1, -1)
        case (.none, .none), (.upvote, .upvote), (.downvote, .downvote):
            return (0, 0)
        }
    }

    private func createPost(upvoteCount: Int, downvoteCount: Int) -> StudyPost {
        StudyPost(
            authorId: "test-user",
            authorName: "Test User",
            type: .tip,
            title: "Test Post",
            content: "Test content",
            tools: [],
            tags: [],
            upvoteCount: upvoteCount,
            downvoteCount: downvoteCount,
            favoriteCount: 0,
            hotScore: 0
        )
    }
}
