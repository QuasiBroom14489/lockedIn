import Foundation
import FirebaseAuth
import Combine
internal import FirebaseFirestoreInternal

class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated = false

    private var authStateListener: AuthStateDidChangeListenerHandle?

    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    var currentUserId: String? {
        currentUser?.uid
    }

    func isNDEmail(_ email: String) -> Bool {
        email.trimmed.lowercased().hasSuffix("@nd.edu")
    }

    func refreshCurrentUser() async throws {
        guard let user = currentUser else { return }
        try await user.reload()
        await MainActor.run {
            self.currentUser = Auth.auth().currentUser
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let result = try await Auth.auth().signIn(with: credential)
        guard let email = result.user.email else {
            try Auth.auth().signOut()
            throw AuthError.googleAccountMissingEmail
        }

        if !isNDEmail(email) {
            try Auth.auth().signOut()
            throw AuthError.googleNonNDEmailRejected
        }

        let userDoc = try await FirebaseService.shared.getUser(id: result.user.uid)
        if userDoc == nil {
            let displayName = result.user.displayName?.trimmed
            let fallbackName = displayName?.isEmpty == false ? displayName! : email.components(separatedBy: "@").first ?? "Student"
            let newUser = User(
                id: result.user.uid,
                email: email,
                displayName: fallbackName,
                photoURL: result.user.photoURL?.absoluteString
            )
            try await FirebaseService.shared.createUser(newUser)
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }

        if let userId = currentUserId {
            try await FirebaseService.shared.db
                .collection(Constants.Firebase.usersCollection)
                .document(userId)
                .delete()
        }

        try await user.delete()
    }

    // MARK: - Update Email

    func updateEmail(to newEmail: String) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }

    // MARK: - Update Password

    func updatePassword(to newPassword: String) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        try await user.updatePassword(to: newPassword)
    }

    // MARK: - Reauthenticate

    func reauthenticate(email: String, password: String) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }

}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case nonNDEmailNotAllowed
    case googleSignInUnavailable
    case googleAccountMissingEmail
    case googleNonNDEmailRejected
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .invalidCredentials:
            return "Invalid email or password"
        case .nonNDEmailNotAllowed:
            return "Only @nd.edu email addresses can access lockedIn."
        case .googleSignInUnavailable:
            return "Google Sign-In is not available on this build."
        case .googleAccountMissingEmail:
            return "Google account did not provide an email address."
        case .googleNonNDEmailRejected:
            return "Only @nd.edu Google accounts are allowed."
        case .unknown(let message):
            return message
        }
    }
}
