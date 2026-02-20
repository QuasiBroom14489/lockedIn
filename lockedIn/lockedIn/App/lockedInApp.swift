import SwiftUI
import FirebaseCore

@main
struct lockedInApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !authViewModel.isAuthenticated {
                    LoginView()
                        .environmentObject(authViewModel)
                        .preferredColorScheme(.dark)
                } else if authViewModel.requiresOnboarding {
                    OnboardingFlowView {
                        Task { @MainActor in
                            await authViewModel.completeOnboarding()
                        }
                    }
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
                } else {
                    ContentView()
                        .environmentObject(authViewModel)
                        .preferredColorScheme(.dark)
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle Google callback
        if GoogleSignInService.shared.handleIncomingURL(url) {
            return
        }

        // Handle Spotify callback
        if url.scheme == "lockedin" && url.host == "spotify-callback" {
            Task { @MainActor in
                _ = SpotifyAuthManager.shared.handleAuthCallback(url: url)
            }
        }
    }
}
