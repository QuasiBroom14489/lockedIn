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

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let firebaseUser = result.user

        let changeRequest = firebaseUser.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        let user = User(
            id: firebaseUser.uid,
            email: email,
            displayName: displayName
        )

        try await FirebaseService.shared.createUser(user)

        return user
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
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
    case emailAlreadyInUse
    case weakPassword
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .unknown(let message):
            return message
        }
    }
}
