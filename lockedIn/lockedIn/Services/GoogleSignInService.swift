import Foundation
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct GoogleSignInTokens {
    let idToken: String
    let accessToken: String
}

final class GoogleSignInService {
    static let shared = GoogleSignInService()

    private init() {}

    func handleIncomingURL(_ url: URL) -> Bool {
#if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
#else
        return false
#endif
    }

    @MainActor
    func signIn() async throws -> GoogleSignInTokens {
#if canImport(GoogleSignIn)
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController
        else {
            throw AuthError.unknown("Unable to present Google Sign-In.")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleAccountMissingEmail
        }

        return GoogleSignInTokens(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
#else
        throw AuthError.googleSignInUnavailable
#endif
    }
}
