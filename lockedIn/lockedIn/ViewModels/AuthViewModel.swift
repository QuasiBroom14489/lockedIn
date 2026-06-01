import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var requiresOnboarding = false
    @Published var authBannerMessage: String?
    @Published var isGoogleLoading = false

    private let authService = AuthService.shared
    private let firebaseService = FirebaseService.shared
    private let googleSignInService = GoogleSignInService.shared
    private let analyticsService = AnalyticsService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        authService.$isAuthenticated
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
                if isAuth {
                    Task { await self?.loadCurrentUser() }
                } else {
                    self?.currentUser = nil
                    self?.requiresOnboarding = false
                    self?.authBannerMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    func loadCurrentUser() async {
        guard let userId = authService.currentUserId else { return }

        do {
            currentUser = try await firebaseService.getUser(id: userId)
            requiresOnboarding = userNeedsOnboarding(currentUser)
        } catch {
            handleError(error)
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            currentUser = nil
            requiresOnboarding = false
            authBannerMessage = nil
        } catch {
            handleError(error)
        }
    }

    func signInWithGoogle() async {
        isGoogleLoading = true
        authBannerMessage = nil
        analyticsService.logAuthGoogleSigninStarted()
        defer { isGoogleLoading = false }

        do {
            let tokens = try await googleSignInService.signIn()
            try await authService.signInWithGoogle(idToken: tokens.idToken, accessToken: tokens.accessToken)
            try await authService.refreshCurrentUser()

            guard let signedInEmail = authService.currentUser?.email,
                  authService.isAllowedEmail(signedInEmail)
            else {
                try? authService.signOut()
                throw AuthError.googleNonNDEmailRejected
            }

            await loadCurrentUser()
            analyticsService.logAuthGoogleSigninSucceeded()
            authBannerMessage = nil
        } catch AuthError.googleNonNDEmailRejected {
            analyticsService.logAuthGoogleRejectedNonND()
            analyticsService.logAuthGoogleSigninFailed(reason: AuthError.googleNonNDEmailRejected.localizedDescription)
            handleError(AuthError.googleNonNDEmailRejected)
        } catch {
            analyticsService.logAuthGoogleSigninFailed(reason: error.localizedDescription)
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = mapErrorMessage(error)
        showError = true
    }

    func completeOnboarding() async {
        await loadCurrentUser()
        requiresOnboarding = false
    }

    private func userNeedsOnboarding(_ user: User?) -> Bool {
        guard let user else { return true }
        let hasDisplayName = user.displayName.trimmed.isNotEmpty
        let hasMajor = user.major?.trimmed.isNotEmpty == true
        let hasYear = user.year?.trimmed.isNotEmpty == true
        let hasDorm = user.dorm?.trimmed.isNotEmpty == true
        let hasTools = !user.primaryStudyTools.isEmpty || !user.studyTools.isEmpty
        let completed = user.onboardingCompletedAt != nil
        return !(hasDisplayName && hasMajor && hasYear && hasDorm && hasTools && completed)
    }

    private func mapErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return error.localizedDescription
        }

        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .tooManyRequests:
            return "Too many requests from this device. Please wait and try again."
        case .networkError:
            return "Network issue while contacting Firebase. Check your connection and try again."
        default:
            return error.localizedDescription
        }
    }
}
