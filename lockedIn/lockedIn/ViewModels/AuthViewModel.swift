import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let authService = AuthService.shared
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
                if isAuth {
                    Task {
                        await self?.loadCurrentUser()
                    }
                } else {
                    self?.currentUser = nil
                }
            }
            .store(in: &cancellables)
    }

    private func loadCurrentUser() async {
        guard let userId = authService.currentUserId else { return }

        do {
            currentUser = try await firebaseService.getUser(id: userId)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Validation

    var isSignUpFormValid: Bool {
        email.isValidEmail &&
        password.count >= 6 &&
        password == confirmPassword &&
        displayName.isNotEmpty
    }

    var isSignInFormValid: Bool {
        email.isValidEmail && password.isNotEmpty
    }

    // MARK: - Sign Up

    func signUp() async {
        guard isSignUpFormValid else {
            showError(message: "Please fill in all fields correctly")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signUp(
                email: email.trimmed,
                password: password,
                displayName: displayName.trimmed
            )
            currentUser = user
            clearForm()
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Sign In

    func signIn() async {
        guard isSignInFormValid else {
            showError(message: "Please enter a valid email and password")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signIn(email: email.trimmed, password: password)
            clearForm()
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
            clearForm()
            currentUser = nil
        } catch {
            handleError(error)
        }
    }

    // MARK: - Password Reset

    func resetPassword() async {
        guard email.isValidEmail else {
            showError(message: "Please enter a valid email address")
            return
        }

        isLoading = true

        do {
            try await authService.resetPassword(email: email.trimmed)
            showError(message: "Password reset email sent. Check your inbox.")
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
