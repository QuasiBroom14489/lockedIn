import Foundation
import Combine
import SwiftUI
import PhotosUI

enum ProfileTab: String, CaseIterable {
    case overview = "Overview"
    case posts = "Posts"
    case saved = "Saved"
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isCurrentUser = false

    @Published var editDisplayName = ""
    @Published var editMajor = ""
    @Published var editYear = ""
    @Published var editSpotifyURL = ""
    @Published var editStudyTools: [String] = []
    @Published var editTips = ""

    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?

    @Published var followersCount = 0
    @Published var followingCount = 0
    @Published var isFollowing = false

    @Published var recentSessions: [FocusSession] = []
    @Published var userPosts: [StudyPost] = []
    @Published var savedPosts: [StudyPost] = []
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

            if let user = user {
                populateEditFields(from: user)
            }

            // Load counts
            followersCount = try await firebaseService.getFollowersCount(userId: id)
            followingCount = try await firebaseService.getFollowingCount(userId: id)

            // Check if following (for non-current user)
            if !isCurrentUser, let currentUserId = authService.currentUserId {
                isFollowing = try await firebaseService.isFollowing(currentUserId: currentUserId, targetUserId: id)
            }

            // Load recent sessions
            recentSessions = try await firebaseService.getSessions(userId: id, limit: 5)

            // Load profile content tabs
            userPosts = try await firebaseService.getPostsByAuthor(userId: id, limit: 50)
            savedPosts = try await firebaseService.getFavoritedPosts(userId: id, limit: 50)

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    private func populateEditFields(from user: User) {
        editDisplayName = user.displayName
        editMajor = user.major ?? ""
        editYear = user.year ?? ""
        editSpotifyURL = user.spotifyPlaylistURL ?? ""
        editStudyTools = user.studyTools
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
        updatedUser.year = editYear.isNotEmpty ? editYear : nil
        updatedUser.spotifyPlaylistURL = editSpotifyURL.isNotEmpty ? editSpotifyURL.trimmed : nil
        updatedUser.studyTools = editStudyTools
        updatedUser.tips = editTips.isNotEmpty ? editTips.trimmed : nil
        updatedUser.updatedAt = Date()

        do {
            try await firebaseService.updateUser(updatedUser)
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
        } else {
            editStudyTools.append(tool)
        }
    }

    func addCustomTool(_ tool: String) {
        let trimmed = tool.trimmed
        guard trimmed.isNotEmpty, !editStudyTools.contains(trimmed) else { return }
        editStudyTools.append(trimmed)
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

    // MARK: - Helpers

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
