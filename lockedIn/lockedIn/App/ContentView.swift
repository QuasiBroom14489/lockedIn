import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FocusTimerView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
                .tag(0)

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy.fill")
                }
                .tag(1)

            FeedView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(AppColors.gold)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
