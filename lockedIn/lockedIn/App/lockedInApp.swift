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
            if authViewModel.isAuthenticated {
                ContentView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
