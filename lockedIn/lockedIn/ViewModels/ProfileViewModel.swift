import Foundation
import Combine
import SwiftUI
import PhotosUI

enum ProfileTab: String, CaseIterable {
    case overview = "Overview"
    case classes = "Classes"
    case posts = "Posts"
    case saved = "Saved"
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isCurrentUser = false

    @Published var editDisplayName = ""
    @Published var editMajor = ""
    @Published var editDorm = ""
    @Published var editYear = ""
    @Published var editSpotifyURL = ""
    @Published var editStudyTools: [String] = []
    @Published var editPrimaryStudyTools: [String] = []
    @Published var editTips = ""

    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?

    @Published var followersCount = 0
    @Published var followingCount = 0
    @Published var isFollowing = false

    @Published var recentSessions: [FocusSession] = []
    @Published var userPosts: [StudyPost] = []
    @Published var savedPosts: [StudyPost] = []
    @Published var classItems: [ProfileClassItem] = []
    @Published var classSuggestions: [GlobalClass] = []
    @Published var classPeriod: ClassDashboardPeriod = .allTime
    @Published var classUserPosts: [StudyPost] = []
    @Published var isLoadingClassPosts = false

    // Catalog state
    @Published var catalogCourses: [GlobalClass] = []
    @Published var selectedCatalogSchool: CatalogSchool? = .holyCross
    @Published var catalogSearchQuery: String = ""
    @Published var isLoadingCatalog = false

    // Legacy compatibility for older views still using UserClass.
    @Published var userClasses: [UserClass] = []
    @Published var selectedClass: UserClass?
    @Published var classDashboard: ClassDashboard?
    @Published var isLoadingClassDashboard = false
    @Published var classErrorMessage: String?
    @Published var selectedTab: ProfileTab = .overview

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared
    private let analyticsService = AnalyticsService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        $selectedTab
            .dropFirst()
            .sink { [weak self] tab in
                self?.analyticsService.logProfileTabChanged(tab: tab.rawValue)
            }
            .store(in: &cancellables)
    }

    var yearOptions: [String] {
        ["Freshman", "Sophomore", "Junior", "Senior", "Graduate"]
    }

    var commonStudyTools: [String] {
        ["Notion", "Anki", "Quizlet", "Google Docs", "OneNote", "Obsidian", "GoodNotes", "Notability"]
    }

    // MARK: - Load Profile

    func loadProfile(userId: String?) async {
        let targetUserId = userId ?? authService.currentUserId

        guard let id = targetUserId else {
            showError(message: "User not found")
            return
        }

        isCurrentUser = (id == authService.currentUserId)
        isLoading = true

        do {
            user = try await firebaseService.getUser(id: id)
        } catch {
            handleError(error)
            isLoading = false
            return
        }

        if let user = user {
            populateEditFields(from: user)
        }

        do {
            followersCount = try await firebaseService.getFollowersCount(userId: id)
        } catch {
            reportSoftLoadIssue(section: "followers_count", userId: id, error: error)
        }

        do {
            followingCount = try await firebaseService.getFollowingCount(userId: id)
        } catch {
            reportSoftLoadIssue(section: "following_count", userId: id, error: error)
        }

        if !isCurrentUser, let currentUserId = authService.currentUserId {
            do {
                isFollowing = try await firebaseService.isFollowing(currentUserId: currentUserId, targetUserId: id)
            } catch {
                reportSoftLoadIssue(section: "is_following", userId: id, error: error)
            }
        }

        do {
            recentSessions = try await firebaseService.getSessions(userId: id, limit: 5)
        } catch {
            reportSoftLoadIssue(section: "recent_sessions", userId: id, error: error)
        }

        do {
            userPosts = try await firebaseService.getPostsByAuthor(userId: id, limit: 50)
        } catch {
            reportSoftLoadIssue(section: "user_posts", userId: id, error: error)
            userPosts = []
        }

        do {
            savedPosts = try await firebaseService.getFavoritedPosts(userId: id, limit: 50)
        } catch {
            reportSoftLoadIssue(section: "saved_posts", userId: id, error: error)
            savedPosts = []
        }

        do {
            await loadClassItems(userId: id)
            userClasses = try await firebaseService.getUserClasses(userId: id)
        } catch {
            reportSoftLoadIssue(section: "user_classes", userId: id, error: error)
            classItems = []
            userClasses = []
        }

        isLoading = false
    }

    private func populateEditFields(from user: User) {
        editDisplayName = user.displayName
        editMajor = user.major ?? ""
        editDorm = user.dorm ?? ""
        editYear = user.year ?? ""
        editSpotifyURL = user.spotifyPlaylistURL ?? ""
        editStudyTools = user.studyTools
        editPrimaryStudyTools = user.primaryStudyTools.isEmpty
            ? Array(user.studyTools.prefix(3))
            : user.primaryStudyTools
        editTips = user.tips ?? ""
    }

    // MARK: - Save Profile

    func saveProfile() async {
        guard var updatedUser = user else { return }

        isSaving = true

        // Upload photo if selected
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.8),
           let userId = updatedUser.id {
            do {
                let photoURL = try await firebaseService.uploadProfilePhoto(userId: userId, imageData: imageData)
                updatedUser.photoURL = photoURL
            } catch {
                handleError(error)
            }
        }

        // Update user fields
        updatedUser.displayName = editDisplayName.trimmed
        updatedUser.major = editMajor.isNotEmpty ? editMajor.trimmed : nil
        updatedUser.dorm = editDorm.isNotEmpty ? editDorm.trimmed : nil
        updatedUser.year = editYear.isNotEmpty ? editYear : nil
        updatedUser.spotifyPlaylistURL = editSpotifyURL.isNotEmpty ? editSpotifyURL.trimmed : nil
        updatedUser.studyTools = editStudyTools
        let normalizedPrimaryTools = editPrimaryStudyTools
            .map(\.trimmed)
            .filter(\.isNotEmpty)
        updatedUser.primaryStudyTools = normalizedPrimaryTools.isEmpty
            ? Array(editStudyTools.prefix(3))
            : normalizedPrimaryTools
        updatedUser.tips = editTips.isNotEmpty ? editTips.trimmed : nil
        updatedUser.updatedAt = Date()

        do {
            try await firebaseService.updateUser(updatedUser)
            if let userId = updatedUser.id {
                await syncToolsToGlobalLibrary(
                    tools: updatedUser.studyTools,
                    userId: userId
                )
            }
            user = updatedUser
            selectedImage = nil
            selectedPhotoItem = nil
        } catch {
            handleError(error)
        }

        isSaving = false
    }

    // MARK: - Photo Handling

    func loadPhoto() async {
        guard let item = selectedPhotoItem else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Study Tools

    func toggleStudyTool(_ tool: String) {
        if editStudyTools.contains(tool) {
            editStudyTools.removeAll { $0 == tool }
            editPrimaryStudyTools.removeAll { $0 == tool }
        } else {
            editStudyTools.append(tool)
            if let userId = user?.id {
                Task {
                    try? await firebaseService.createGlobalToolIfNeeded(
                        displayName: tool,
                        category: nil,
                        createdByUserId: userId
                    )
                }
            }
        }
    }

    func addCustomTool(_ tool: String) {
        let trimmed = tool.trimmed
        guard trimmed.isNotEmpty, !editStudyTools.contains(trimmed) else { return }
        editStudyTools.append(trimmed)
        if let userId = user?.id {
            Task {
                try? await firebaseService.createGlobalToolIfNeeded(
                    displayName: trimmed,
                    category: nil,
                    createdByUserId: userId
                )
            }
        }
    }

    func togglePrimaryStudyTool(_ tool: String) {
        if editPrimaryStudyTools.contains(tool) {
            editPrimaryStudyTools.removeAll { $0 == tool }
        } else {
            editPrimaryStudyTools.append(tool)
        }
    }

    // MARK: - Follow/Unfollow

    func toggleFollow() async {
        guard let targetUserId = user?.id,
              let currentUserId = authService.currentUserId,
              !isCurrentUser else { return }

        do {
            if isFollowing {
                try await firebaseService.unfollowUser(currentUserId: currentUserId, targetUserId: targetUserId)
                isFollowing = false
                followersCount -= 1
                analyticsService.logUserUnfollowed(targetUserId: targetUserId)
            } else {
                try await firebaseService.followUser(currentUserId: currentUserId, targetUserId: targetUserId)
                isFollowing = true
                followersCount += 1
                analyticsService.logUserFollowed(targetUserId: targetUserId)
            }
        } catch {
            handleError(error)
        }
    }

    // MARK: - Posts/Saved

    func loadUserPosts(userId: String) async {
        do {
            userPosts = try await firebaseService.getPostsByAuthor(userId: userId, limit: 50)
        } catch {
            handleError(error)
        }
    }

    func loadSavedPosts(userId: String) async {
        do {
            savedPosts = try await firebaseService.getFavoritedPosts(userId: userId, limit: 50)
        } catch {
            handleError(error)
        }
    }

    func loadClasses(userId: String) async {
        do {
            await loadClassItems(userId: userId)
            userClasses = try await firebaseService.getUserClasses(userId: userId)
            classErrorMessage = nil
        } catch {
            classErrorMessage = error.localizedDescription
        }
    }

    func loadClassItems(userId: String) async {
        do {
            let memberships = try await firebaseService.getUserClassMemberships(userId: userId)
            let globals = try await firebaseService.getGlobalClassesByIds(memberships.map(\.classId))
            let globalsById = Dictionary(uniqueKeysWithValues: globals.map { ($0.id, $0) })
            classItems = memberships.map { membership in
                let global = globalsById[membership.classId] ?? GlobalClass(
                    id: membership.classId,
                    courseCode: membership.classId,
                    displayName: nil,
                    instructorName: nil,
                    recentTerms: membership.term.isEmpty ? [] : [membership.term],
                    instructorNames: [],
                    aliases: [],
                    createdByUserId: userId,
                    memberCount: 0,
                    createdAt: membership.joinedAt,
                    updatedAt: membership.updatedAt
                )
                return ProfileClassItem(global: global, membership: membership)
            }
                .sorted { $0.membership.updatedAt > $1.membership.updatedAt }
            classErrorMessage = nil
        } catch {
            classItems = []
            classErrorMessage = error.localizedDescription
        }
    }

    func searchGlobalClassSuggestions(query: String) async {
        do {
            classSuggestions = try await firebaseService.searchGlobalClasses(query: query, limit: 12)
        } catch {
            classSuggestions = []
            classErrorMessage = error.localizedDescription
        }
    }

    func addOrJoinClass(
        courseCode: String,
        term: String,
        displayName: String?,
        instructorName: String?
    ) async -> Bool {
        guard let userId = user?.id else {
            classErrorMessage = "Profile not loaded. Try again."
            return false
        }
        do {
            let globalClass = try await firebaseService.createOrJoinClassForUser(
                userId: userId,
                courseCode: courseCode,
                term: term,
                displayName: displayName,
                instructorName: instructorName
            )
            await loadClassItems(userId: userId)
            userClasses = try await firebaseService.getUserClasses(userId: userId)
            classErrorMessage = nil
            return true
        } catch {
            let message = "Add class failed. classCode=\(courseCode) term=\(term) reason=\(error.localizedDescription)"
            print(message)
            classErrorMessage = message
            return false
        }
    }

    func saveClass(_ userClass: UserClass) async -> Bool {
        await addOrJoinClass(
            courseCode: userClass.courseCode,
            term: userClass.term,
            displayName: userClass.displayName,
            instructorName: userClass.instructorName
        )
    }

    func removeClass(classKey: String) async {
        guard let userId = user?.id else { return }
        do {
            try await firebaseService.leaveClass(userId: userId, classId: classKey)
            classItems.removeAll { $0.global.id == classKey }
            userClasses.removeAll { $0.id == classKey }
            if selectedClass?.id == classKey {
                selectedClass = nil
                classDashboard = nil
            }
            classErrorMessage = nil
        } catch {
            classErrorMessage = error.localizedDescription
        }
    }

    func loadClassDashboard(classKey: String) async {
        await loadGlobalClassDashboard(classId: classKey, period: classPeriod)
    }

    func loadGlobalClassDashboard(classId: String, period: ClassDashboardPeriod) async {
        guard let userId = user?.id else { return }
        isLoadingClassDashboard = true
        isLoadingClassPosts = true
        classDashboard = nil
        classUserPosts = []
        defer {
            isLoadingClassDashboard = false
            isLoadingClassPosts = false
        }

        do {
            classDashboard = try await firebaseService.buildGlobalClassDashboard(classId: classId, period: period)
            classUserPosts = try await firebaseService.getPostsByAuthorAndClass(userId: userId, classKey: classId, limit: 50)
            classErrorMessage = nil
        } catch {
            classDashboard = nil
            classUserPosts = []
            classErrorMessage = error.localizedDescription
        }
    }

    func loadUserPostsForClass(classId: String, userId: String) async {
        isLoadingClassPosts = true
        defer { isLoadingClassPosts = false }
        do {
            classUserPosts = try await firebaseService.getPostsByAuthorAndClass(userId: userId, classKey: classId, limit: 50)
            classErrorMessage = nil
        } catch {
            classUserPosts = []
            classErrorMessage = error.localizedDescription
        }
    }

    func saveMembershipData(for item: ProfileClassItem) async -> Bool {
        guard let userId = user?.id else {
            classErrorMessage = "Profile not loaded. Try again."
            return false
        }
        do {
            try await firebaseService.upsertUserClassPersonalData(
                userId: userId,
                classId: item.global.id,
                teacherReview: item.membership.teacherReview,
                teacherRating: item.membership.teacherRating,
                spotifyLinks: item.membership.spotifyLinks,
                helpfulWebsites: item.membership.helpfulWebsites
            )
            await loadClassItems(userId: userId)
            return true
        } catch {
            classErrorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Catalog Operations

    func loadCatalogCourses() async {
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }

        do {
            catalogCourses = try await firebaseService.getCatalogCourses(school: selectedCatalogSchool)
            classErrorMessage = nil
        } catch {
            catalogCourses = []
            classErrorMessage = error.localizedDescription
        }
    }

    func searchCatalogCourses() async {
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }

        do {
            catalogCourses = try await firebaseService.searchCatalogCourses(
                query: catalogSearchQuery,
                school: selectedCatalogSchool
            )
            classErrorMessage = nil
        } catch {
            catalogCourses = []
            classErrorMessage = error.localizedDescription
        }
    }

    func joinCatalogCourse(_ course: GlobalClass, term: String) async -> Bool {
        guard let userId = user?.id else {
            classErrorMessage = "Profile not loaded. Try again."
            return false
        }

        do {
            try await firebaseService.joinClass(userId: userId, classId: course.id, term: term)
            await loadClassItems(userId: userId)
            userClasses = try await firebaseService.getUserClasses(userId: userId)
            classErrorMessage = nil
            return true
        } catch {
            classErrorMessage = "Could not join class. \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private func reportSoftLoadIssue(section: String, userId: String, error: Error) {
        print("Profile soft load issue. section=\(section) userId=\(userId) reason=\(error.localizedDescription)")
    }

    private func syncToolsToGlobalLibrary(tools: [String], userId: String) async {
        let uniqueTools = Set(tools.map(\.trimmed).filter(\.isNotEmpty))
        for tool in uniqueTools {
            do {
                _ = try await firebaseService.createGlobalToolIfNeeded(
                    displayName: tool,
                    category: nil,
                    createdByUserId: userId
                )
            } catch {
                print("Profile tool sync soft failure. tool=\(tool) userId=\(userId) reason=\(error.localizedDescription)")
            }
        }
    }
}
