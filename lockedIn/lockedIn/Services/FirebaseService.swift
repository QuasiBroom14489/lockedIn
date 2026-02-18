import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class FirebaseService {
    static let shared = FirebaseService()

    let db: Firestore
    let storage: Storage
    let auth: Auth

    private init() {
        self.db = Firestore.firestore()
        self.storage = Storage.storage()
        self.auth = Auth.auth()
    }

    // MARK: - User Operations

    func createUser(_ user: User) async throws {
        guard let userId = user.id else {
            throw FirebaseError.invalidData
        }
        try db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .setData(from: user)
    }

    func getUser(id: String) async throws -> User? {
        let document = try await db.collection(Constants.Firebase.usersCollection)
            .document(id)
            .getDocument()
        return try document.data(as: User.self)
    }

    func updateUser(_ user: User) async throws {
        guard let userId = user.id else {
            throw FirebaseError.invalidData
        }
        try db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .setData(from: user, merge: true)
    }

    func searchUsers(query: String) async throws -> [User] {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .whereField("displayName", isGreaterThanOrEqualTo: query)
            .whereField("displayName", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: User.self) }
    }

    // MARK: - Session Operations

    func createSession(_ session: FocusSession, userId: String) async throws -> String {
        let docRef = try db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.sessionsCollection)
            .addDocument(from: session)
        return docRef.documentID
    }

    func updateSession(_ session: FocusSession, userId: String) async throws {
        guard let sessionId = session.id else {
            throw FirebaseError.invalidData
        }
        try db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.sessionsCollection)
            .document(sessionId)
            .setData(from: session, merge: true)
    }

    func getSessions(userId: String, limit: Int = 50) async throws -> [FocusSession] {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.sessionsCollection)
            .order(by: "completedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: FocusSession.self) }
    }

    // MARK: - Study Post Operations

    func createStudyPost(_ post: StudyPost) async throws -> String {
        var postToCreate = post
        let now = Date()
        postToCreate.createdAt = now
        postToCreate.updatedAt = now

        let docRef = try db.collection(Constants.Firebase.studyPostsCollection)
            .addDocument(from: postToCreate)
        return docRef.documentID
    }

    func getStudyPost(id: String) async throws -> StudyPost? {
        let document = try await db.collection(Constants.Firebase.studyPostsCollection)
            .document(id)
            .getDocument()
        return try document.data(as: StudyPost.self)
    }

    func getStudyPosts(limit: Int = 50) async throws -> [StudyPost] {
        let snapshot = try await db.collection(Constants.Firebase.studyPostsCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: StudyPost.self) }
    }

    func updateStudyPost(_ post: StudyPost) async throws {
        guard let postId = post.id else {
            throw FirebaseError.invalidData
        }

        var postToUpdate = post
        postToUpdate.updatedAt = Date()

        try db.collection(Constants.Firebase.studyPostsCollection)
            .document(postId)
            .setData(from: postToUpdate, merge: true)
    }

    func deleteStudyPost(postId: String) async throws {
        try await db.collection(Constants.Firebase.studyPostsCollection)
            .document(postId)
            .delete()
    }

    // MARK: - Voting Operations

    func getVote(postId: String, userId: String) async throws -> VoteType {
        let voteId = voteDocumentId(postId: postId, userId: userId)
        let document = try await db.collection(Constants.Firebase.votesCollection)
            .document(voteId)
            .getDocument()

        guard document.exists, let vote = try? document.data(as: Vote.self) else {
            return .none
        }
        return vote.type
    }

    func setVote(postId: String, userId: String, type newType: VoteType) async throws {
        let voteId = voteDocumentId(postId: postId, userId: userId)
        let voteRef = db.collection(Constants.Firebase.votesCollection).document(voteId)
        let postRef = db.collection(Constants.Firebase.studyPostsCollection).document(postId)

        let currentVoteDoc = try await voteRef.getDocument()
        let currentVote = (try? currentVoteDoc.data(as: Vote.self))?.type ?? .none

        // No-op if nothing changes.
        guard currentVote != newType else { return }

        let delta = voteCounterDelta(from: currentVote, to: newType)
        let batch = db.batch()
        let now = Date()

        batch.updateData([
            "upvoteCount": FieldValue.increment(Int64(delta.upvotes)),
            "downvoteCount": FieldValue.increment(Int64(delta.downvotes)),
            "hotScore": FieldValue.increment(Double(delta.upvotes - delta.downvotes)),
            "updatedAt": now
        ], forDocument: postRef)

        if newType == .none {
            batch.deleteDocument(voteRef)
        } else {
            let voteData: [String: Any] = [
                "postId": postId,
                "userId": userId,
                "type": newType.rawValue,
                "createdAt": currentVoteDoc.exists
                    ? (currentVoteDoc.data()?["createdAt"] as? Timestamp ?? Timestamp(date: now))
                    : Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ]
            batch.setData(voteData, forDocument: voteRef, merge: true)
        }

        try await batch.commit()
    }

    func clearVote(postId: String, userId: String) async throws {
        try await setVote(postId: postId, userId: userId, type: .none)
    }

    func getVotes(for postId: String, limit: Int = 200) async throws -> [Vote] {
        let snapshot = try await db.collection(Constants.Firebase.votesCollection)
            .whereField("postId", isEqualTo: postId)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Vote.self) }
    }

    private func voteDocumentId(postId: String, userId: String) -> String {
        "\(postId)_\(userId)"
    }

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
        default:
            return (0, 0)
        }
    }

    // MARK: - Favorite Operations

    func isFavorited(postId: String, userId: String) async throws -> Bool {
        let favoriteId = favoriteDocumentId(postId: postId, userId: userId)
        let document = try await db.collection(Constants.Firebase.favoritesCollection)
            .document(favoriteId)
            .getDocument()
        return document.exists
    }

    func setFavorite(postId: String, userId: String, isFavorite: Bool) async throws {
        let favoriteId = favoriteDocumentId(postId: postId, userId: userId)
        let favoriteRef = db.collection(Constants.Firebase.favoritesCollection).document(favoriteId)
        let postRef = db.collection(Constants.Firebase.studyPostsCollection).document(postId)

        let currentFavoriteDoc = try await favoriteRef.getDocument()
        let currentlyFavorited = currentFavoriteDoc.exists

        // No-op if state is unchanged.
        guard currentlyFavorited != isFavorite else { return }

        let batch = db.batch()
        let now = Date()
        let delta = isFavorite ? 1 : -1

        batch.updateData([
            "favoriteCount": FieldValue.increment(Int64(delta)),
            "updatedAt": now
        ], forDocument: postRef)

        if isFavorite {
            let favoriteData: [String: Any] = [
                "postId": postId,
                "userId": userId,
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ]
            batch.setData(favoriteData, forDocument: favoriteRef, merge: true)
        } else {
            batch.deleteDocument(favoriteRef)
        }

        try await batch.commit()
    }

    func removeFavorite(postId: String, userId: String) async throws {
        try await setFavorite(postId: postId, userId: userId, isFavorite: false)
    }

    func getFavorites(forUserId userId: String, limit: Int = 200) async throws -> [Favorite] {
        let snapshot = try await db.collection(Constants.Firebase.favoritesCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Favorite.self) }
    }

    func getFavorites(forPostId postId: String, limit: Int = 200) async throws -> [Favorite] {
        let snapshot = try await db.collection(Constants.Firebase.favoritesCollection)
            .whereField("postId", isEqualTo: postId)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Favorite.self) }
    }

    private func favoriteDocumentId(postId: String, userId: String) -> String {
        "\(postId)_\(userId)"
    }

    // MARK: - Social Operations

    func followUser(currentUserId: String, targetUserId: String) async throws {
        let batch = db.batch()

        let followingRef = db.collection(Constants.Firebase.usersCollection)
            .document(currentUserId)
            .collection(Constants.Firebase.followingCollection)
            .document(targetUserId)

        let followerRef = db.collection(Constants.Firebase.usersCollection)
            .document(targetUserId)
            .collection(Constants.Firebase.followersCollection)
            .document(currentUserId)

        let data: [String: Any] = ["followedAt": FieldValue.serverTimestamp()]

        batch.setData(data, forDocument: followingRef)
        batch.setData(data, forDocument: followerRef)

        try await batch.commit()
    }

    func unfollowUser(currentUserId: String, targetUserId: String) async throws {
        let batch = db.batch()

        let followingRef = db.collection(Constants.Firebase.usersCollection)
            .document(currentUserId)
            .collection(Constants.Firebase.followingCollection)
            .document(targetUserId)

        let followerRef = db.collection(Constants.Firebase.usersCollection)
            .document(targetUserId)
            .collection(Constants.Firebase.followersCollection)
            .document(currentUserId)

        batch.deleteDocument(followingRef)
        batch.deleteDocument(followerRef)

        try await batch.commit()
    }

    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool {
        let document = try await db.collection(Constants.Firebase.usersCollection)
            .document(currentUserId)
            .collection(Constants.Firebase.followingCollection)
            .document(targetUserId)
            .getDocument()
        return document.exists
    }

    func getFollowing(userId: String) async throws -> [String] {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.followingCollection)
            .getDocuments()
        return snapshot.documents.map { $0.documentID }
    }

    func getFollowers(userId: String) async throws -> [String] {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.followersCollection)
            .getDocuments()
        return snapshot.documents.map { $0.documentID }
    }

    func getFollowingCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.followingCollection)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    func getFollowersCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.followersCollection)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    // MARK: - Leaderboard Operations

    func getLeaderboard(limit: Int = 100) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .order(by: "totalFocusedSeconds", descending: true)
            .limit(to: limit)
            .getDocuments()

        let users = snapshot.documents.compactMap { try? $0.data(as: User.self) }
        return users.enumerated().map { index, user in
            LeaderboardEntry(from: user, rank: index + 1)
        }
    }

    func getFriendsLeaderboard(userId: String) async throws -> [LeaderboardEntry] {
        let followingIds = try await getFollowing(userId: userId)
        guard !followingIds.isEmpty else { return [] }

        var allIds = followingIds
        allIds.append(userId)

        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .whereField(FieldPath.documentID(), in: allIds)
            .getDocuments()

        let users = snapshot.documents.compactMap { try? $0.data(as: User.self) }
        let sorted = users.sorted { $0.totalFocusedSeconds > $1.totalFocusedSeconds }
        return sorted.enumerated().map { index, user in
            LeaderboardEntry(from: user, rank: index + 1)
        }
    }

    // MARK: - Storage Operations

    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String {
        let ref = storage.reference()
            .child(Constants.Storage.profilePhotosPath)
            .child("\(userId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Real-time Listeners

    func addUserListener(userId: String, completion: @escaping (User?) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    completion(nil)
                    return
                }
                let user = try? snapshot.data(as: User.self)
                completion(user)
            }
    }

    func addLeaderboardListener(limit: Int = 100, completion: @escaping ([LeaderboardEntry]) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Firebase.usersCollection)
            .order(by: "totalFocusedSeconds", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    completion([])
                    return
                }
                let users = snapshot.documents.compactMap { try? $0.data(as: User.self) }
                let entries = users.enumerated().map { index, user in
                    LeaderboardEntry(from: user, rank: index + 1)
                }
                completion(entries)
            }
    }
}

// MARK: - Errors

enum FirebaseError: LocalizedError {
    case invalidData
    case notAuthenticated
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data provided"
        case .notAuthenticated:
            return "User is not authenticated"
        case .userNotFound:
            return "User not found"
        }
    }
}
