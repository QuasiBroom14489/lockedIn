import Foundation
import FirebaseCore
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
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

        guard document.exists else { return nil }

        var user = try document.data(as: User.self)
        if user.id == nil {
            user.id = document.documentID
        }
        return user
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

        return decodeUsers(from: snapshot.documents)
    }

    func updateUserScreenTime(_ metrics: ScreenTimeMetrics, userId: String) async throws {
        try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .setData([
                "dailyProductiveMinutes": metrics.productiveMinutes,
                "dailyNonProductiveMinutes": metrics.nonProductiveMinutes,
                "screenTimeUpdatedAt": metrics.lastUpdated,
                "updatedAt": Date()
            ], merge: true)
    }

    // MARK: - Global Class Catalog

    func searchGlobalClasses(query: String, limit: Int = 20) async throws -> [GlobalClass] {
        let trimmed = query.trimmed
        let classesCollection = db.collection(Constants.Firebase.globalClassesCollection)

        if trimmed.isEmpty {
            let snapshot = try await classesCollection
                .order(by: "memberCount", descending: true)
                .limit(to: limit)
                .getDocuments()
            return decodeGlobalClasses(from: snapshot.documents)
        }

        let normalized = GlobalClass.normalizedId(from: trimmed)
        let byCourseSnapshot = try await classesCollection
            .whereField("courseCode", isGreaterThanOrEqualTo: normalized)
            .whereField("courseCode", isLessThanOrEqualTo: normalized + "\u{f8ff}")
            .limit(to: limit * 2)
            .getDocuments()

        let fallbackSnapshot = try await classesCollection
            .limit(to: max(limit * 5, 50))
            .getDocuments()

        let candidates = dedupeGlobalClasses(
            decodeGlobalClasses(from: byCourseSnapshot.documents)
            + decodeGlobalClasses(from: fallbackSnapshot.documents)
        )

        return candidates
            .map { ($0, classMatchScore(for: $0, query: trimmed)) }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.memberCount != rhs.0.memberCount { return lhs.0.memberCount > rhs.0.memberCount }
                return lhs.0.courseCode < rhs.0.courseCode
            }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Catalog Course Operations

    /// Fetches all pre-defined catalog courses, optionally filtered by school
    func getCatalogCourses(school: CatalogSchool? = nil) async throws -> [GlobalClass] {
        let classesCollection = db.collection(Constants.Firebase.globalClassesCollection)

        var query: Query = classesCollection
            .whereField("isCatalogCourse", isEqualTo: true)

        if let school = school {
            query = query.whereField("school", isEqualTo: school.rawValue)
        }

        let snapshot = try await query
            .order(by: "courseCode")
            .getDocuments()

        return decodeGlobalClasses(from: snapshot.documents)
    }

    /// Searches catalog courses by query (course code or name), optionally filtered by school
    func searchCatalogCourses(query: String, school: CatalogSchool? = nil) async throws -> [GlobalClass] {
        // Fetch all catalog courses (small set, <50 initially)
        let allCatalog = try await getCatalogCourses(school: school)

        let trimmed = query.trimmed
        if trimmed.isEmpty {
            return allCatalog.sorted { $0.courseCode < $1.courseCode }
        }

        // Filter client-side for flexible matching
        let lowerQuery = trimmed.lowercased()
        let normalizedQuery = GlobalClass.normalizedId(from: trimmed)

        return allCatalog
            .map { course -> (GlobalClass, Int) in
                var score = 0
                let code = course.courseCode.lowercased()
                let normalizedCode = GlobalClass.normalizedId(from: course.courseCode).lowercased()
                let displayName = course.displayName?.lowercased() ?? ""

                // Exact code match
                if normalizedCode == normalizedQuery.lowercased() {
                    score = 400
                }
                // Code prefix match
                else if normalizedCode.hasPrefix(normalizedQuery.lowercased()) {
                    score = 300
                }
                // Display name starts with query
                else if displayName.hasPrefix(lowerQuery) {
                    score = 250
                }
                // Code contains query
                else if normalizedCode.contains(normalizedQuery.lowercased()) {
                    score = 200
                }
                // Display name contains query
                else if displayName.contains(lowerQuery) {
                    score = 150
                }
                // Department match
                else if let dept = course.department?.lowercased(), dept.hasPrefix(lowerQuery) {
                    score = 100
                }

                return (course, score)
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.courseCode < rhs.0.courseCode
            }
            .map(\.0)
    }

    func createGlobalClassIfNeeded(
        courseCode: String,
        displayName: String? = nil,
        instructorName: String? = nil,
        term: String? = nil,
        createdByUserId: String
    ) async throws -> GlobalClass {
        let classId = GlobalClass.normalizedId(from: courseCode)
        guard classId.isNotEmpty else {
            throw FirebaseError.invalidData
        }

        let classRef = db.collection(Constants.Firebase.globalClassesCollection).document(classId)
        let existing = try await classRef.getDocument()
        let normalizedTerm = term?.trimmed
        let trimmedDisplayName = displayName?.trimmed
        let trimmedInstructorName = instructorName?.trimmed

        if existing.exists {
            var existingClass = (try? existing.data(as: GlobalClass.self))
                ?? fallbackGlobalClass(from: existing.data() ?? [:], documentId: existing.documentID)

            // Best effort metadata enrichment; this must not fail class joins for non-owner users.
            var metadataUpdates: [String: Any] = ["updatedAt": Date()]
            if let trimmedDisplayName, trimmedDisplayName.isNotEmpty {
                metadataUpdates["displayName"] = trimmedDisplayName
            }
            if let trimmedInstructorName, trimmedInstructorName.isNotEmpty {
                metadataUpdates["instructorName"] = trimmedInstructorName
            }
            if let normalizedTerm, normalizedTerm.isNotEmpty {
                metadataUpdates["recentTerms"] = FieldValue.arrayUnion([normalizedTerm])
            }
            if let trimmedInstructorName, trimmedInstructorName.isNotEmpty {
                metadataUpdates["instructorNames"] = FieldValue.arrayUnion([trimmedInstructorName])
            }

            if metadataUpdates.count > 1 {
                do {
                    try await classRef.setData(metadataUpdates, merge: true)
                } catch {
                    print("FirebaseService.createGlobalClassIfNeeded metadata merge skipped for \(classId): \(error.localizedDescription)")
                }
            }

            if existingClass == nil {
                existingClass = try await getGlobalClass(id: classId)
            }
            if let existingClass {
                return existingClass
            }
        }

        let now = Date()
        let initialRecentTerms = normalizedTerm.map { $0.isNotEmpty ? [$0] : [] } ?? []
        let initialInstructorNames = trimmedInstructorName.map { $0.isNotEmpty ? [$0] : [] } ?? []
        let newClass = GlobalClass(
            id: classId,
            courseCode: classId,
            displayName: trimmedDisplayName,
            instructorName: trimmedInstructorName,
            recentTerms: initialRecentTerms,
            instructorNames: initialInstructorNames,
            aliases: [],
            createdByUserId: createdByUserId,
            memberCount: 0,
            createdAt: now,
            updatedAt: now
        )
        try classRef.setData(from: newClass, merge: true)
        return newClass
    }

    func getGlobalClass(id: String) async throws -> GlobalClass? {
        let classId = GlobalClass.normalizedId(from: id)
        let doc = try await db.collection(Constants.Firebase.globalClassesCollection)
            .document(classId)
            .getDocument()
        guard doc.exists else { return nil }
        if let decoded = try? doc.data(as: GlobalClass.self) {
            return decoded
        }
        guard let data = doc.data() else { return nil }
        return fallbackGlobalClass(from: data, documentId: doc.documentID)
    }

    func getGlobalClassesByIds(_ ids: [String]) async throws -> [GlobalClass] {
        let uniqueIds = Array(Set(ids.map { GlobalClass.normalizedId(from: $0) }.filter(\.isNotEmpty)))
        guard !uniqueIds.isEmpty else { return [] }

        var result: [GlobalClass] = []
        for chunk in uniqueIds.chunked(into: 10) {
            let snapshot = try await db.collection(Constants.Firebase.globalClassesCollection)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            result.append(contentsOf: decodeGlobalClasses(from: snapshot.documents))
        }
        return dedupeGlobalClasses(result)
    }

    // MARK: - Global Tool Catalog

    func searchGlobalTools(query: String, limit: Int = 20) async throws -> [GlobalTool] {
        let trimmed = query.trimmed
        let collection = db.collection(Constants.Firebase.toolsCollection)

        if trimmed.isEmpty {
            let snapshot = try await collection
                .order(by: "usageCount", descending: true)
                .limit(to: limit)
                .getDocuments()
            return decodeGlobalTools(from: snapshot.documents)
        }

        let byDisplaySnapshot = try await collection
            .whereField("displayName", isGreaterThanOrEqualTo: trimmed)
            .whereField("displayName", isLessThanOrEqualTo: trimmed + "\u{f8ff}")
            .limit(to: limit * 2)
            .getDocuments()

        let fallbackSnapshot = try await collection
            .order(by: "usageCount", descending: true)
            .limit(to: max(limit * 6, 60))
            .getDocuments()

        let candidates = dedupeGlobalTools(
            decodeGlobalTools(from: byDisplaySnapshot.documents)
            + decodeGlobalTools(from: fallbackSnapshot.documents)
        )

        return candidates
            .map { ($0, toolMatchScore(for: $0, query: trimmed)) }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.usageCount != rhs.0.usageCount { return lhs.0.usageCount > rhs.0.usageCount }
                return lhs.0.displayName < rhs.0.displayName
            }
            .prefix(limit)
            .map(\.0)
    }

    func createGlobalToolIfNeeded(
        displayName: String,
        category: String? = nil,
        createdByUserId: String
    ) async throws -> GlobalTool {
        let trimmedName = displayName.trimmed
        let toolId = GlobalTool.normalizedId(from: trimmedName)
        guard toolId.isNotEmpty else {
            throw FirebaseError.invalidData
        }

        let toolRef = db.collection(Constants.Firebase.toolsCollection).document(toolId)
        let existingDoc = try await toolRef.getDocument()
        if existingDoc.exists, var existing = try? existingDoc.data(as: GlobalTool.self) {
            if existing.id.isEmpty { existing.id = existingDoc.documentID }
            // Any user can reference an existing canonical tool. Metadata enrichment is best effort.
            let aliases = Set(existing.aliases + GlobalTool.normalizedAliasKeys(from: trimmedName))
            let updatedCategory = existing.category?.trimmed.isNotEmpty == true ? existing.category : category?.trimmed
            do {
                try await toolRef.setData([
                    "aliases": Array(aliases).sorted(),
                    "category": updatedCategory as Any,
                    "updatedAt": Date()
                ], merge: true)
                existing.aliases = Array(aliases).sorted()
                existing.category = updatedCategory
            } catch {
                print("FirebaseService.createGlobalToolIfNeeded metadata merge skipped for \(toolId): \(error.localizedDescription)")
            }
            return existing
        }

        let nearDuplicate = try await findNearDuplicateTool(displayName: trimmedName)
        if var canonical = nearDuplicate {
            let canonicalRef = db.collection(Constants.Firebase.toolsCollection).document(canonical.id)
            let aliases = Set(canonical.aliases + GlobalTool.normalizedAliasKeys(from: trimmedName))
            do {
                try await canonicalRef.setData([
                    "aliases": Array(aliases).sorted(),
                    "updatedAt": Date()
                ], merge: true)
                canonical.aliases = Array(aliases).sorted()
            } catch {
                print("FirebaseService.createGlobalToolIfNeeded alias merge skipped for \(canonical.id): \(error.localizedDescription)")
            }
            return canonical
        }

        let now = Date()
        let newTool = GlobalTool(
            id: toolId,
            displayName: trimmedName,
            aliases: GlobalTool.normalizedAliasKeys(from: trimmedName),
            category: category?.trimmed,
            createdByUserId: createdByUserId,
            usageCount: 0,
            createdAt: now,
            updatedAt: now
        )
        try toolRef.setData(from: newTool, merge: true)
        return newTool
    }

    func incrementToolUsage(toolId: String, delta: Int = 1) async throws {
        let normalizedToolId = GlobalTool.normalizedId(from: toolId)
        guard normalizedToolId.isNotEmpty else { return }
        let safeDelta = max(1, delta)
        try await db.collection(Constants.Firebase.toolsCollection)
            .document(normalizedToolId)
            .setData([
                "usageCount": FieldValue.increment(Int64(safeDelta)),
                "updatedAt": Date()
            ], merge: true)
    }

    func getPopularGlobalTools(limit: Int = 30) async throws -> [GlobalTool] {
        let snapshot = try await db.collection(Constants.Firebase.toolsCollection)
            .order(by: "usageCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        return decodeGlobalTools(from: snapshot.documents)
    }

    // MARK: - User Class Membership

    func getUserClassMemberships(userId: String) async throws -> [UserClassMembership] {
        let collection = db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.classesCollection)

        let documents: [QueryDocumentSnapshot]
        do {
            documents = try await collection
                .order(by: "updatedAt", descending: true)
                .getDocuments()
                .documents
        } catch {
            documents = try await collection.getDocuments().documents
        }

        return documents.compactMap { document in
            if var membership = try? document.data(as: UserClassMembership.self) {
                if membership.id.isEmpty { membership.id = document.documentID }
                if membership.classId.isEmpty { membership.classId = document.documentID }
                return membership
            }

            // Legacy compatibility: decode old per-user UserClass into membership shape.
            if let legacy = try? document.data(as: UserClass.self) {
                let classId = GlobalClass.normalizedId(from: legacy.courseCode)
                return UserClassMembership(
                    id: classId,
                    classId: classId,
                    term: legacy.term,
                    teacherReview: legacy.teacherReview,
                    teacherRating: legacy.teacherRating,
                    spotifyLinks: legacy.spotifyLinks,
                    helpfulWebsites: legacy.helpfulWebsites,
                    joinedAt: legacy.createdAt,
                    updatedAt: legacy.updatedAt
                )
            }

            return nil
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func joinClass(userId: String, classId: String, term: String? = nil, seed: UserClassMembershipSeed? = nil) async throws {
        let normalizedClassId = GlobalClass.normalizedId(from: classId)
        guard normalizedClassId.isNotEmpty else {
            throw FirebaseError.invalidData
        }

        if let globalClass = try await getGlobalClass(id: normalizedClassId), globalClass.id.isNotEmpty {
            // exists
        } else {
            _ = try await createGlobalClassIfNeeded(
                courseCode: normalizedClassId,
                createdByUserId: userId
            )
        }

        let membershipRef = db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.classesCollection)
            .document(normalizedClassId)

        let now = Date()
        let existing = try await membershipRef.getDocument()
        let previousMembership = try? existing.data(as: UserClassMembership.self)
        let normalizedTerm = term?.trimmed ?? previousMembership?.term ?? ""
        let membership = UserClassMembership(
            id: normalizedClassId,
            classId: normalizedClassId,
            term: normalizedTerm,
            teacherReview: seed?.teacherReview?.trimmed ?? "",
            teacherRating: seed?.teacherRating,
            spotifyLinks: seed?.spotifyLinks ?? [],
            helpfulWebsites: seed?.helpfulWebsites ?? [],
            joinedAt: existing.exists ? previousMembership?.joinedAt ?? now : now,
            updatedAt: now
        )
        try membershipRef.setData(from: membership, merge: true)

        try await db.collection(Constants.Firebase.globalClassesCollection)
            .document(normalizedClassId)
            .setData([
                "memberCount": FieldValue.increment(Int64(existing.exists ? 0 : 1)),
                "updatedAt": now
            ], merge: true)
    }

    func leaveClass(userId: String, classId: String) async throws {
        let normalizedClassId = GlobalClass.normalizedId(from: classId)
        let membershipRef = db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.classesCollection)
            .document(normalizedClassId)

        let existing = try await membershipRef.getDocument()
        guard existing.exists else { return }
        try await membershipRef.delete()

        try await db.collection(Constants.Firebase.globalClassesCollection)
            .document(normalizedClassId)
            .setData([
                "memberCount": FieldValue.increment(Int64(-1)),
                "updatedAt": Date()
            ], merge: true)
    }

    func createOrJoinClassForUser(
        userId: String,
        courseCode: String,
        term: String,
        displayName: String? = nil,
        instructorName: String? = nil
    ) async throws -> GlobalClass {
        let normalizedCourseCode = GlobalClass.normalizedId(from: courseCode)
        let trimmedTerm = term.trimmed
        guard normalizedCourseCode.isNotEmpty, trimmedTerm.isNotEmpty else {
            throw FirebaseError.invalidData
        }

        let globalClass = try await createGlobalClassIfNeeded(
            courseCode: normalizedCourseCode,
            displayName: displayName,
            instructorName: instructorName,
            term: trimmedTerm,
            createdByUserId: userId
        )
        try await joinClass(
            userId: userId,
            classId: globalClass.id,
            term: trimmedTerm
        )
        return globalClass
    }

    func upsertUserClassPersonalData(
        userId: String,
        classId: String,
        term: String? = nil,
        teacherReview: String,
        teacherRating: Int?,
        spotifyLinks: [SpotifyLink],
        helpfulWebsites: [HelpfulLink]
    ) async throws {
        let normalizedClassId = GlobalClass.normalizedId(from: classId)
        for spotifyLink in spotifyLinks {
            guard isValidSpotifyURL(spotifyLink.url) else {
                throw FirebaseError.invalidData
            }
        }
        for website in helpfulWebsites {
            guard isValidWebURL(website.url) else {
                throw FirebaseError.invalidData
            }
        }

        let ref = db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.classesCollection)
            .document(normalizedClassId)

        let existing = try await ref.getDocument()
        let now = Date()
        let previousMembership = try? existing.data(as: UserClassMembership.self)
        let joinedAt = existing.exists
            ? previousMembership?.joinedAt ?? now
            : now
        let normalizedTerm = term?.trimmed ?? previousMembership?.term ?? ""

        let membership = UserClassMembership(
            id: normalizedClassId,
            classId: normalizedClassId,
            term: normalizedTerm,
            teacherReview: teacherReview.trimmed,
            teacherRating: teacherRating,
            spotifyLinks: spotifyLinks,
            helpfulWebsites: helpfulWebsites,
            joinedAt: joinedAt,
            updatedAt: now
        )
        try ref.setData(from: membership, merge: true)
    }

    // MARK: - Legacy User Class Compatibility

    func getUserClasses(userId: String) async throws -> [UserClass] {
        let memberships = try await getUserClassMemberships(userId: userId)
        let globals = try await getGlobalClassesByIds(memberships.map(\.classId))
        let globalsById = Dictionary(uniqueKeysWithValues: globals.map { ($0.id, $0) })

        return memberships.map { membership in
            let global = globalsById[membership.classId]
            return UserClass(
                id: membership.classId,
                courseCode: membership.classId,
                term: membership.term,
                displayName: global?.displayName,
                instructorName: global?.instructorName,
                teacherReview: membership.teacherReview,
                teacherRating: membership.teacherRating,
                spotifyLinks: membership.spotifyLinks,
                helpfulWebsites: membership.helpfulWebsites,
                createdAt: membership.joinedAt,
                updatedAt: membership.updatedAt
            )
        }
    }

    func upsertUserClass(userId: String, userClass: UserClass) async throws {
        let classId = GlobalClass.normalizedId(from: userClass.courseCode)
        let globalClass = try await createGlobalClassIfNeeded(
            courseCode: classId,
            displayName: userClass.displayName,
            instructorName: userClass.instructorName,
            createdByUserId: userId
        )
        try await joinClass(userId: userId, classId: globalClass.id)
        try await upsertUserClassPersonalData(
            userId: userId,
            classId: globalClass.id,
            term: userClass.term,
            teacherReview: userClass.teacherReview,
            teacherRating: userClass.teacherRating,
            spotifyLinks: userClass.spotifyLinks,
            helpfulWebsites: userClass.helpfulWebsites
        )
    }

    func deleteUserClass(userId: String, classKey: String) async throws {
        try await leaveClass(userId: userId, classId: classKey)
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
        let collection = db.collection(Constants.Firebase.studyPostsCollection)

        do {
            let orderedSnapshot = try await collection
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            let orderedResult = decodeStudyPosts(from: orderedSnapshot)
            print("FirebaseService.getStudyPosts primary query count=\(orderedResult.posts.count) missingCreatedAt=\(orderedResult.missingCreatedAtCount) missingUpdatedAt=\(orderedResult.missingUpdatedAtCount)")

            // Compatibility path: if the ordered query unexpectedly returns too few results,
            // pull a bounded unordered set and sort in memory.
            if orderedResult.posts.count <= 1, limit > 1 {
                let fallbackSnapshot = try await collection
                    .limit(to: limit)
                    .getDocuments()
                let fallbackResult = decodeStudyPosts(from: fallbackSnapshot)
                let sortedFallback = sortPostsForCompatibility(fallbackResult.posts)

                print("FirebaseService.getStudyPosts fallback (small primary result) count=\(sortedFallback.count) missingCreatedAt=\(fallbackResult.missingCreatedAtCount) missingUpdatedAt=\(fallbackResult.missingUpdatedAtCount)")

                if sortedFallback.count > orderedResult.posts.count {
                    return sortedFallback
                }
            }

            return orderedResult.posts
        } catch {
            // Compatibility path: legacy data shape / query issues should not blank the feed.
            print("FirebaseService.getStudyPosts primary query failed: \(error.localizedDescription). Falling back to unordered query.")

            let fallbackSnapshot = try await collection
                .limit(to: limit)
                .getDocuments()
            let fallbackResult = decodeStudyPosts(from: fallbackSnapshot)
            let sortedFallback = sortPostsForCompatibility(fallbackResult.posts)

            print("FirebaseService.getStudyPosts fallback (primary failure) count=\(sortedFallback.count) missingCreatedAt=\(fallbackResult.missingCreatedAtCount) missingUpdatedAt=\(fallbackResult.missingUpdatedAtCount)")

            return sortedFallback
        }
    }

    func getPostsByAuthor(userId: String, limit: Int = 50) async throws -> [StudyPost] {
        let collection = db.collection(Constants.Firebase.studyPostsCollection)

        do {
            let orderedSnapshot = try await collection
                .whereField("authorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            let orderedResult = decodeStudyPosts(from: orderedSnapshot)
            if !orderedResult.posts.isEmpty {
                return orderedResult.posts
            }

            // Compatibility fallback for legacy author posts missing createdAt.
            let fallbackSnapshot = try await collection
                .whereField("authorId", isEqualTo: userId)
                .limit(to: limit)
                .getDocuments()
            let fallbackResult = decodeStudyPosts(from: fallbackSnapshot)
            return sortPostsForCompatibility(fallbackResult.posts)
        } catch {
            let fallbackSnapshot = try await collection
                .whereField("authorId", isEqualTo: userId)
                .limit(to: limit)
                .getDocuments()
            let fallbackResult = decodeStudyPosts(from: fallbackSnapshot)
            return sortPostsForCompatibility(fallbackResult.posts)
        }
    }

    func getPostsByAuthorAndClass(userId: String, classKey: String, limit: Int = 200) async throws -> [StudyPost] {
        let normalizedClassId = GlobalClass.normalizedId(from: classKey)
        let collection = db.collection(Constants.Firebase.studyPostsCollection)
        do {
            let orderedSnapshot = try await collection
                .whereField("authorId", isEqualTo: userId)
                .whereField("classKeys", arrayContains: normalizedClassId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let orderedResult = decodeStudyPosts(from: orderedSnapshot)
            return orderedResult.posts
        } catch {
            let fallbackSnapshot = try await collection
                .whereField("authorId", isEqualTo: userId)
                .whereField("classKeys", arrayContains: normalizedClassId)
                .limit(to: limit)
                .getDocuments()
            let fallbackResult = decodeStudyPosts(from: fallbackSnapshot)
            return sortPostsForCompatibility(fallbackResult.posts)
        }
    }

    func buildGlobalClassDashboard(classId: String, period: ClassDashboardPeriod = .allTime, limit: Int = 500) async throws -> ClassDashboard {
        let normalizedClassId = GlobalClass.normalizedId(from: classId)
        let collection = db.collection(Constants.Firebase.studyPostsCollection)

        let posts: [StudyPost]
        do {
            let orderedSnapshot = try await collection
                .whereField("classKeys", arrayContains: normalizedClassId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            posts = decodeStudyPosts(from: orderedSnapshot).posts
        } catch {
            let fallbackSnapshot = try await collection
                .whereField("classKeys", arrayContains: normalizedClassId)
                .limit(to: limit)
                .getDocuments()
            posts = sortPostsForCompatibility(decodeStudyPosts(from: fallbackSnapshot).posts)
        }

        let cutoff = period.cutoffDate
        let filtered = posts.filter { post in
            guard cutoff != Date.distantPast else { return true }
            return post.createdAt >= cutoff
        }

        var toolCounts: [String: Int] = [:]
        var patternCounts: [String: Int] = [:]
        var tagCounts: [String: Int] = [:]
        var stackCount = 0
        var tipCount = 0

        for post in filtered {
            if post.type == .stack {
                stackCount += 1
            } else {
                tipCount += 1
            }

            var toolsForPost: [String] = []
            if let stackItems = post.stackItems, !stackItems.isEmpty {
                toolsForPost = stackItems.map(\.toolName)
            } else {
                toolsForPost = post.tools
            }

            let normalizedTools = Array(
                Set(
                    toolsForPost
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                )
            ).sorted()

            for tool in normalizedTools {
                toolCounts[tool, default: 0] += 1
            }

            if normalizedTools.count > 1 {
                let pattern = normalizedTools.joined(separator: " + ")
                patternCounts[pattern, default: 0] += 1
            }

            if post.type == .tip {
                for tag in post.tags {
                    let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !normalizedTag.isEmpty else { continue }
                    tagCounts[normalizedTag, default: 0] += 1
                }
            }
        }

        let topTools = toolCounts
            .map { ToolUsageStat(tool: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.tool < rhs.tool }
                return lhs.count > rhs.count
            }
            .prefix(8)

        let topPatterns = patternCounts
            .map { StackPatternCount(pattern: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.pattern < rhs.pattern }
                return lhs.count > rhs.count
            }
            .prefix(6)

        let topTags = tagCounts
            .map { TagUsageStat(tag: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.tag < rhs.tag }
                return lhs.count > rhs.count
            }
            .prefix(8)

        return ClassDashboard(
            topTools: Array(topTools),
            topStackPatterns: Array(topPatterns),
            topTipTags: Array(topTags),
            postCount: filtered.count,
            stackCount: stackCount,
            tipCount: tipCount,
            lastUpdatedComputedAt: Date()
        )
    }

    func buildClassDashboard(userId: String, classKey: String, limit: Int = 200) async throws -> ClassDashboard {
        // Legacy compatibility: existing callers can still request per-user aggregation.
        let posts = try await getPostsByAuthorAndClass(userId: userId, classKey: classKey, limit: limit)

        var toolCounts: [String: Int] = [:]
        var patternCounts: [String: Int] = [:]
        var tagCounts: [String: Int] = [:]
        var stackCount = 0
        var tipCount = 0

        for post in posts {
            if post.type == .stack {
                stackCount += 1
            } else {
                tipCount += 1
            }

            var toolsForPost: [String] = []
            if let stackItems = post.stackItems, !stackItems.isEmpty {
                toolsForPost = stackItems.map(\.toolName)
            } else {
                toolsForPost = post.tools
            }

            let normalizedTools = Array(Set(toolsForPost.map(\.trimmed).filter(\.isNotEmpty))).sorted()
            for tool in normalizedTools {
                toolCounts[tool, default: 0] += 1
            }
            if normalizedTools.count > 1 {
                patternCounts[normalizedTools.joined(separator: " + "), default: 0] += 1
            }
            if post.type == .tip {
                for tag in post.tags.map({ $0.trimmed.lowercased() }).filter({ !$0.isEmpty }) {
                    tagCounts[tag, default: 0] += 1
                }
            }
        }

        return ClassDashboard(
            topTools: toolCounts.map { ToolUsageStat(tool: $0.key, count: $0.value) }.sorted { $0.count > $1.count },
            topStackPatterns: patternCounts.map { StackPatternCount(pattern: $0.key, count: $0.value) }.sorted { $0.count > $1.count },
            topTipTags: tagCounts.map { TagUsageStat(tag: $0.key, count: $0.value) }.sorted { $0.count > $1.count },
            postCount: posts.count,
            stackCount: stackCount,
            tipCount: tipCount,
            lastUpdatedComputedAt: Date()
        )
    }

    func getFavoritedPosts(userId: String, limit: Int = 50) async throws -> [StudyPost] {
        let favorites = try await getFavorites(forUserId: userId, limit: limit)
        var posts: [StudyPost] = []
        posts.reserveCapacity(favorites.count)

        for favorite in favorites {
            if let post = try await getStudyPost(id: favorite.postId) {
                posts.append(post)
            }
        }

        return posts
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

        try await db.runTransaction { transaction, errorPointer in
            // Read post document
            let postDoc: DocumentSnapshot
            do {
                postDoc = try transaction.getDocument(postRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard postDoc.exists else {
                errorPointer?.pointee = NSError(
                    domain: "FirebaseService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Post not found"]
                )
                return nil
            }

            // Read current vote document
            let currentVoteDoc: DocumentSnapshot
            do {
                currentVoteDoc = try transaction.getDocument(voteRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let currentVote: VoteType
            if currentVoteDoc.exists,
               let voteData = currentVoteDoc.data() {
                if let typeRaw = voteData["type"] as? String,
                   let voteType = VoteType(rawValue: typeRaw) {
                    currentVote = voteType
                } else if let legacyType = voteData["type"] as? Int {
                    switch legacyType {
                    case 1:
                        currentVote = .upvote
                    case -1:
                        currentVote = .downvote
                    default:
                        currentVote = .none
                    }
                } else {
                    currentVote = .none
                }
            } else {
                currentVote = .none
            }

            // No-op if nothing changes
            guard currentVote != newType else { return nil }

            let delta = self.voteCounterDelta(from: currentVote, to: newType)
            let now = Date()

            // Update post counters
            transaction.updateData([
                "upvoteCount": FieldValue.increment(Int64(delta.upvotes)),
                "downvoteCount": FieldValue.increment(Int64(delta.downvotes)),
                "hotScore": FieldValue.increment(Double(delta.upvotes - delta.downvotes)),
                "updatedAt": now
            ], forDocument: postRef)

            // Update or delete vote document
            if newType == .none {
                transaction.deleteDocument(voteRef)
            } else {
                let existingCreatedAt = currentVoteDoc.exists
                    ? (currentVoteDoc.data()?["createdAt"] as? Timestamp ?? Timestamp(date: now))
                    : Timestamp(date: now)

                let voteData: [String: Any] = [
                    "postId": postId,
                    "userId": userId,
                    "type": newType.rawValue,
                    "createdAt": existingCreatedAt,
                    "updatedAt": Timestamp(date: now)
                ]
                transaction.setData(voteData, forDocument: voteRef, merge: true)
            }

            return nil
        }
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

    private func decodeStudyPosts(from snapshot: QuerySnapshot) -> (posts: [StudyPost], missingCreatedAtCount: Int, missingUpdatedAtCount: Int) {
        var posts: [StudyPost] = []
        posts.reserveCapacity(snapshot.documents.count)
        var missingCreatedAtCount = 0
        var missingUpdatedAtCount = 0

        for document in snapshot.documents {
            let raw = document.data()
            let createdAt = timestampDate(forKey: "createdAt", in: raw)
            let updatedAt = timestampDate(forKey: "updatedAt", in: raw)

            if createdAt == nil {
                missingCreatedAtCount += 1
            }
            if updatedAt == nil {
                missingUpdatedAtCount += 1
            }

            guard var post = try? document.data(as: StudyPost.self) else {
                continue
            }

            if post.id == nil {
                post.id = document.documentID
            }

            // Normalize legacy documents that are missing timestamps so sorting is stable.
            if createdAt == nil {
                post.createdAt = updatedAt ?? Date.distantPast
            }
            if updatedAt == nil {
                post.updatedAt = post.createdAt
            }

            posts.append(post)
        }

        return (posts, missingCreatedAtCount, missingUpdatedAtCount)
    }

    private func timestampDate(forKey key: String, in data: [String: Any]) -> Date? {
        if let timestamp = data[key] as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = data[key] as? Date {
            return date
        }
        return nil
    }

    private func sortPostsForCompatibility(_ posts: [StudyPost]) -> [StudyPost] {
        posts.sorted { lhs, rhs in
            let lhsDate = compatibilitySortDate(for: lhs)
            let rhsDate = compatibilitySortDate(for: rhs)
            return lhsDate > rhsDate
        }
    }

    private func compatibilitySortDate(for post: StudyPost) -> Date {
        if post.createdAt != Date.distantPast {
            return post.createdAt
        }
        if post.updatedAt != Date.distantPast {
            return post.updatedAt
        }
        return Date.distantPast
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

        try await db.runTransaction { transaction, errorPointer in
            // Read post document to ensure it exists
            let postDoc: DocumentSnapshot
            do {
                postDoc = try transaction.getDocument(postRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard postDoc.exists else {
                errorPointer?.pointee = NSError(
                    domain: "FirebaseService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Post not found"]
                )
                return nil
            }

            // Read current favorite state
            let currentFavoriteDoc: DocumentSnapshot
            do {
                currentFavoriteDoc = try transaction.getDocument(favoriteRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let currentlyFavorited = currentFavoriteDoc.exists

            // No-op if state is unchanged
            guard currentlyFavorited != isFavorite else { return nil }

            let now = Date()
            let delta = isFavorite ? 1 : -1

            // Update post favorite count
            transaction.updateData([
                "favoriteCount": FieldValue.increment(Int64(delta)),
                "updatedAt": now
            ], forDocument: postRef)

            // Add or remove favorite document
            if isFavorite {
                let favoriteData: [String: Any] = [
                    "postId": postId,
                    "userId": userId,
                    "createdAt": Timestamp(date: now),
                    "updatedAt": Timestamp(date: now)
                ]
                transaction.setData(favoriteData, forDocument: favoriteRef, merge: true)
            } else {
                transaction.deleteDocument(favoriteRef)
            }

            return nil
        }
    }

    func removeFavorite(postId: String, userId: String) async throws {
        try await setFavorite(postId: postId, userId: userId, isFavorite: false)
    }

    func getFavorites(forUserId userId: String, limit: Int = 200) async throws -> [Favorite] {
        let collection = db.collection(Constants.Firebase.favoritesCollection)

        do {
            let orderedSnapshot = try await collection
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let orderedFavorites = orderedSnapshot.documents.compactMap { try? $0.data(as: Favorite.self) }
            if !orderedFavorites.isEmpty {
                return orderedFavorites
            }

            let fallbackSnapshot = try await collection
                .whereField("userId", isEqualTo: userId)
                .limit(to: limit)
                .getDocuments()
            return sortedFavorites(fallbackSnapshot.documents.compactMap { try? $0.data(as: Favorite.self) })
        } catch {
            let fallbackSnapshot = try await collection
                .whereField("userId", isEqualTo: userId)
                .limit(to: limit)
                .getDocuments()
            return sortedFavorites(fallbackSnapshot.documents.compactMap { try? $0.data(as: Favorite.self) })
        }
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

    private func sortedFavorites(_ favorites: [Favorite]) -> [Favorite] {
        favorites.sorted { lhs, rhs in
            let lhsDate = lhs.createdAt >= lhs.updatedAt ? lhs.createdAt : lhs.updatedAt
            let rhsDate = rhs.createdAt >= rhs.updatedAt ? rhs.createdAt : rhs.updatedAt
            return lhsDate > rhsDate
        }
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

    func getFriendsLeaderboard(userId: String, period: LeaderboardPeriod = .allTime) async throws -> [LeaderboardEntry] {
        let followingIds = try await getFollowing(userId: userId)
        guard !followingIds.isEmpty else { return [] }

        var allIds = followingIds
        allIds.append(userId)

        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .whereField(FieldPath.documentID(), in: allIds)
            .getDocuments()

        let users = decodeUsers(from: snapshot.documents)

        if period == .allTime {
            if users.allSatisfy({ $0.totalFocusedSeconds == 0 }) {
                let recalculatedUsers = try await recalculateAllTimeTotalsForUsers(users)
                let ranked = rankedEntries(from: recalculatedUsers, limit: users.count)
                if !ranked.isEmpty {
                    return ranked
                }
            }

            return rankedEntries(from: users, limit: users.count)
        }

        // For weekly/monthly, aggregate from sessions
        var userTotals: [(user: User, seconds: Int)] = []
        let cutoffDate = period.cutoffDate

        for user in users {
            guard let userId = user.id else { continue }
            let periodSeconds = try await getSessionsTotal(userId: userId, since: cutoffDate)
            userTotals.append((user, periodSeconds))
        }

        let sorted = userTotals.sorted { $0.seconds > $1.seconds }
        return sorted.enumerated().map { index, item in
            var entry = LeaderboardEntry(from: item.user, rank: index + 1)
            entry.totalSeconds = item.seconds
            return entry
        }
    }

    func getLeaderboard(limit: Int = 100, period: LeaderboardPeriod = .allTime) async throws -> [LeaderboardEntry] {
        if period == .allTime {
            let snapshot = try await db.collection(Constants.Firebase.usersCollection)
                .order(by: "totalFocusedSeconds", descending: true)
                .limit(to: limit)
                .getDocuments()

            let users = decodeUsers(from: snapshot.documents)
            if users.allSatisfy({ $0.totalFocusedSeconds == 0 }) {
                let recalculatedUsers = try await recalculateAllTimeTotalsForUsers(users)
                let ranked = rankedEntries(from: recalculatedUsers, limit: limit)
                if !ranked.isEmpty {
                    return ranked
                }
            }

            return rankedEntries(from: users, limit: limit)
        }

        // For weekly/monthly, get top users and aggregate their sessions
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .order(by: "totalFocusedSeconds", descending: true)
            .limit(to: limit * 2) // Fetch more to account for reordering
            .getDocuments()

        let users = decodeUsers(from: snapshot.documents)

        var userTotals: [(user: User, seconds: Int)] = []
        let cutoffDate = period.cutoffDate

        for user in users {
            guard let userId = user.id else { continue }
            let periodSeconds = try await getSessionsTotal(userId: userId, since: cutoffDate)
            if periodSeconds > 0 {
                userTotals.append((user, periodSeconds))
            }
        }

        let sorted = userTotals.sorted { $0.seconds > $1.seconds }.prefix(limit)
        return sorted.enumerated().map { index, item in
            var entry = LeaderboardEntry(from: item.user, rank: index + 1)
            entry.totalSeconds = item.seconds
            return entry
        }
    }

    private func getSessionsTotal(userId: String, since cutoffDate: Date) async throws -> Int {
        let collection = db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .collection(Constants.Firebase.sessionsCollection)

        // All-time should include legacy sessions regardless of timestamp field shape.
        if cutoffDate == Date.distantPast {
            let snapshot = try await collection.getDocuments()
            let sessions = snapshot.documents.compactMap { try? $0.data(as: FocusSession.self) }
            return sessions.reduce(0) { partial, session in
                partial + max(session.durationSeconds, 0)
            }
        }

        // Fast path for modern schema.
        do {
            let filteredSnapshot = try await collection
                .whereField("completedAt", isGreaterThan: Timestamp(date: cutoffDate))
                .getDocuments()
            let filteredSessions = filteredSnapshot.documents.compactMap { try? $0.data(as: FocusSession.self) }
            let total = filteredSessions.reduce(0) { partial, session in
                partial + max(session.durationSeconds, 0)
            }
            if total > 0 {
                return total
            }
        } catch {
            // Fall through to compatibility scan below.
        }

        // Compatibility path for legacy sessions missing completedAt.
        let snapshot = try await collection.getDocuments()
        let sessions = snapshot.documents.compactMap { try? $0.data(as: FocusSession.self) }

        return sessions.reduce(0) { partial, session in
            let sessionDate = session.completedAt ?? session.endTime ?? session.startTime
            guard sessionDate >= cutoffDate else { return partial }
            return partial + max(session.durationSeconds, 0)
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
                guard var user = try? snapshot.data(as: User.self) else {
                    completion(nil)
                    return
                }
                if user.id == nil {
                    user.id = snapshot.documentID
                }
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
                let users = self.decodeUsers(from: snapshot.documents)
                if users.allSatisfy({ $0.totalFocusedSeconds == 0 }) {
                    Task {
                        do {
                            let recalculatedUsers = try await self.recalculateAllTimeTotalsForUsers(users)
                            let ranked = self.rankedEntries(from: recalculatedUsers, limit: limit)
                            completion(ranked.isEmpty ? self.rankedEntries(from: users, limit: limit) : ranked)
                        } catch {
                            completion(self.rankedEntries(from: users, limit: limit))
                        }
                    }
                } else {
                    completion(self.rankedEntries(from: users, limit: limit))
                }
            }
    }

    private func decodeUsers(from documents: [QueryDocumentSnapshot]) -> [User] {
        var users: [User] = []
        users.reserveCapacity(documents.count)

        for document in documents {
            guard var user = try? document.data(as: User.self) else {
                continue
            }
            if user.id == nil {
                user.id = document.documentID
            }
            users.append(user)
        }

        return users
    }

    private func decodeGlobalClasses(from documents: [QueryDocumentSnapshot]) -> [GlobalClass] {
        var classes: [GlobalClass] = []
        classes.reserveCapacity(documents.count)

        for document in documents {
            if var globalClass = try? document.data(as: GlobalClass.self) {
                if globalClass.id.isEmpty {
                    globalClass.id = document.documentID
                }
                if globalClass.courseCode.isEmpty {
                    globalClass.courseCode = document.documentID
                }
                classes.append(globalClass)
                continue
            }

            if let fallback = fallbackGlobalClass(from: document.data(), documentId: document.documentID) {
                classes.append(fallback)
            }
        }
        return classes
    }

    private func fallbackGlobalClass(from data: [String: Any], documentId: String) -> GlobalClass? {
        let courseCode = (data["courseCode"] as? String)?.trimmed
            ?? documentId
        let createdBy = (data["createdByUserId"] as? String)?.trimmed
            ?? auth.currentUser?.uid
            ?? "unknown"
        let displayName = (data["displayName"] as? String)?.trimmed
        let instructorName = (data["instructorName"] as? String)?.trimmed
        let recentTerms = (data["recentTerms"] as? [String]) ?? []
        let instructorNames = (data["instructorNames"] as? [String]) ?? []
        let aliases = data["aliases"] as? [String] ?? []
        let memberCount = data["memberCount"] as? Int ?? 0
        let createdAt = timestampDate(forKey: "createdAt", in: data) ?? Date()
        let updatedAt = timestampDate(forKey: "updatedAt", in: data) ?? createdAt

        guard courseCode.isNotEmpty else { return nil }

        return GlobalClass(
            id: documentId,
            courseCode: courseCode,
            displayName: displayName,
            instructorName: instructorName,
            recentTerms: recentTerms,
            instructorNames: instructorNames,
            aliases: aliases,
            createdByUserId: createdBy,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func dedupeGlobalClasses(_ classes: [GlobalClass]) -> [GlobalClass] {
        var seen = Set<String>()
        var deduped: [GlobalClass] = []
        for globalClass in classes {
            if !seen.contains(globalClass.id) {
                seen.insert(globalClass.id)
                deduped.append(globalClass)
            }
        }
        return deduped
    }

    private func decodeGlobalTools(from documents: [QueryDocumentSnapshot]) -> [GlobalTool] {
        var tools: [GlobalTool] = []
        tools.reserveCapacity(documents.count)

        for document in documents {
            if var tool = try? document.data(as: GlobalTool.self) {
                if tool.id.isEmpty {
                    tool.id = document.documentID
                }
                tools.append(tool)
                continue
            }

            if let fallback = fallbackGlobalTool(from: document.data(), documentId: document.documentID) {
                tools.append(fallback)
            }
        }

        return tools
    }

    private func fallbackGlobalTool(from data: [String: Any], documentId: String) -> GlobalTool? {
        let displayName = (data["displayName"] as? String)?.trimmed
        let createdBy = (data["createdByUserId"] as? String)?.trimmed ?? auth.currentUser?.uid ?? "unknown"
        let aliases = (data["aliases"] as? [String]) ?? []
        let category = (data["category"] as? String)?.trimmed
        let usageCount = data["usageCount"] as? Int ?? 0
        let createdAt = timestampDate(forKey: "createdAt", in: data) ?? Date()
        let updatedAt = timestampDate(forKey: "updatedAt", in: data) ?? createdAt

        guard let displayName, displayName.isNotEmpty else { return nil }

        return GlobalTool(
            id: documentId,
            displayName: displayName,
            aliases: aliases,
            category: category?.isEmpty == true ? nil : category,
            createdByUserId: createdBy,
            usageCount: usageCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func dedupeGlobalTools(_ tools: [GlobalTool]) -> [GlobalTool] {
        var seen = Set<String>()
        var deduped: [GlobalTool] = []
        for tool in tools {
            if !seen.contains(tool.id) {
                seen.insert(tool.id)
                deduped.append(tool)
            }
        }
        return deduped
    }

    private func classMatchScore(for globalClass: GlobalClass, query: String) -> Int {
        let normalizedQuery = GlobalClass.normalizedId(from: query)
        let lowerQuery = query.lowercased()
        let code = globalClass.courseCode.lowercased()
        let displayName = globalClass.displayName?.lowercased() ?? ""
        let aliases = globalClass.aliases.map { $0.lowercased() }

        if code == normalizedQuery.lowercased() { return 400 }
        if aliases.contains(where: { GlobalClass.normalizedId(from: $0).lowercased() == normalizedQuery.lowercased() }) {
            return 330
        }
        if code.hasPrefix(normalizedQuery.lowercased()) { return 260 }
        if displayName.hasPrefix(lowerQuery) { return 220 }
        if aliases.contains(where: { $0.hasPrefix(lowerQuery) }) { return 180 }
        if displayName.contains(lowerQuery) { return 120 }
        if aliases.contains(where: { $0.contains(lowerQuery) }) { return 100 }
        if code.contains(lowerQuery) { return 90 }
        return 0
    }

    private func toolMatchScore(for tool: GlobalTool, query: String) -> Int {
        let normalizedQuery = GlobalTool.normalizedId(from: query)
        let lowerQuery = query.lowercased()
        let toolIdLower = tool.id.lowercased()
        let displayLower = tool.displayName.lowercased()
        let aliasesLower = tool.aliases.map { $0.lowercased() }

        if toolIdLower == normalizedQuery.lowercased() { return 400 }
        if displayLower == lowerQuery { return 360 }
        if aliasesLower.contains(where: { $0 == normalizedQuery.lowercased() || $0 == lowerQuery }) { return 330 }
        if displayLower.hasPrefix(lowerQuery) { return 260 }
        if toolIdLower.hasPrefix(normalizedQuery.lowercased()) { return 240 }
        if aliasesLower.contains(where: { $0.hasPrefix(lowerQuery) || $0.hasPrefix(normalizedQuery.lowercased()) }) {
            return 180
        }
        if displayLower.contains(lowerQuery) { return 130 }
        if aliasesLower.contains(where: { $0.contains(lowerQuery) || $0.contains(normalizedQuery.lowercased()) }) {
            return 100
        }
        return 0
    }

    private func findNearDuplicateTool(displayName: String) async throws -> GlobalTool? {
        let normalizedId = GlobalTool.normalizedId(from: displayName)
        let aliasKeys = Set(GlobalTool.normalizedAliasKeys(from: displayName))
        if aliasKeys.isEmpty { return nil }

        let snapshot = try await db.collection(Constants.Firebase.toolsCollection)
            .order(by: "usageCount", descending: true)
            .limit(to: 200)
            .getDocuments()

        let candidates = decodeGlobalTools(from: snapshot.documents)
        return candidates.first { candidate in
            if GlobalTool.normalizedId(from: candidate.displayName) == normalizedId {
                return true
            }
            if candidate.id == normalizedId {
                return true
            }
            let candidateAliases = Set(candidate.aliases + GlobalTool.normalizedAliasKeys(from: candidate.displayName))
            return !candidateAliases.intersection(aliasKeys).isEmpty
        }
    }

    private func recalculateAllTimeTotalsForUsers(_ users: [User]) async throws -> [User] {
        var updatedUsers = users

        for index in updatedUsers.indices {
            guard let userId = updatedUsers[index].id else { continue }
            let sessionTotal = try await getSessionsTotal(userId: userId, since: Date.distantPast)
            if sessionTotal > updatedUsers[index].totalFocusedSeconds {
                updatedUsers[index].totalFocusedSeconds = sessionTotal
            }
        }

        return updatedUsers
    }

    private func rankedEntries(from users: [User], limit: Int) -> [LeaderboardEntry] {
        let sorted = users
            .sorted { lhs, rhs in
                if lhs.totalFocusedSeconds == rhs.totalFocusedSeconds {
                    return lhs.points > rhs.points
                }
                return lhs.totalFocusedSeconds > rhs.totalFocusedSeconds
            }
            .prefix(limit)

        return sorted.enumerated().map { index, user in
            LeaderboardEntry(from: user, rank: index + 1)
        }
    }

    func getSuggestedClassesForUserComposer(userId: String, query: String?) async throws -> [GlobalClass] {
        let memberships = try await getUserClassMemberships(userId: userId)
        let memberClassIds = memberships.map(\.classId)
        let memberClasses = try await getGlobalClassesByIds(memberClassIds)
        let queryClasses = try await searchGlobalClasses(query: query ?? "", limit: 20)

        var merged = memberClasses + queryClasses
        merged = dedupeGlobalClasses(merged)

        let memberSet = Set(memberClassIds)
        return merged.sorted { lhs, rhs in
            let lhsIsMember = memberSet.contains(lhs.id)
            let rhsIsMember = memberSet.contains(rhs.id)
            if lhsIsMember != rhsIsMember {
                return lhsIsMember
            }
            if lhs.memberCount == rhs.memberCount {
                return lhs.courseCode < rhs.courseCode
            }
            return lhs.memberCount > rhs.memberCount
        }
    }

    func getSuggestedToolsForUserComposer(userId: String, query: String?) async throws -> [GlobalTool] {
        let user = try await getUser(id: userId)
        let userToolIds = Set((user?.studyTools ?? []).map { GlobalTool.normalizedId(from: $0) }.filter(\.isNotEmpty))
        let popularTools = try await getPopularGlobalTools(limit: 30)
        let queryTools = try await searchGlobalTools(query: query ?? "", limit: 30)

        let merged = dedupeGlobalTools(popularTools + queryTools)
        return merged.sorted { lhs, rhs in
            let lhsIsUserTool = userToolIds.contains(lhs.id)
            let rhsIsUserTool = userToolIds.contains(rhs.id)
            if lhsIsUserTool != rhsIsUserTool {
                return lhsIsUserTool
            }
            if lhs.usageCount == rhs.usageCount {
                return lhs.displayName < rhs.displayName
            }
            return lhs.usageCount > rhs.usageCount
        }
    }

    // MARK: - URL Validation

    func isValidSpotifyURL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased()
        else {
            return false
        }
        return host == "open.spotify.com" || host == "spotify.link"
    }

    func isValidWebURL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty
        else {
            return false
        }
        return scheme == "https" || scheme == "http"
    }
}


// MARK: - Errors

enum FirebaseError: LocalizedError {
    case invalidData
    case notAuthenticated
    case userNotFound
    case postNotFound

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data provided"
        case .notAuthenticated:
            return "User is not authenticated"
        case .userNotFound:
            return "User not found"
        case .postNotFound:
            return "Post not found"
        }
    }
}
