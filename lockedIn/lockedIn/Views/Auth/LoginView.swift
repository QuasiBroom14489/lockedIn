import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 30)

                authHeader

                if let banner = viewModel.authBannerMessage, !banner.isEmpty {
                    infoBanner(text: banner)
                        .padding(.horizontal, 20)
                }

                googleCard
                    .padding(.horizontal, 20)

                Text("Only @nd.edu Google accounts can access lockedIn.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()
            }
            .background(authBackground)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    private var authHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundColor(AppColors.gold)
                .goldGlow(radius: 12, opacity: 0.35)

            Text("Welcome to lockedIn")
                .font(AppFonts.title())
                .foregroundColor(AppColors.textPrimary)

            Text("Create account or sign in with your Notre Dame Google account")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var googleCard: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Text("G")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.background)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(AppColors.textPrimary))

                    if viewModel.isGoogleLoading {
                        ProgressView()
                            .tint(AppColors.textPrimary)
                    } else {
                        Text("Create Account / Sign In with Google")
                            .font(.headline)
                    }
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.UI.buttonHeight)
                .background(AppColors.surfaceElevated)
                .cornerRadius(Constants.UI.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .disabled(viewModel.isGoogleLoading || viewModel.isLoading)

            Text("@nd.edu only")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.gold)
        }
        .padding(18)
        .focusCardStyle()
    }

    private var authBackground: some View {
        LinearGradient(
            colors: [AppColors.background, AppColors.backgroundSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .ambientBackgroundLayer()
    }

    private func infoBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(AppColors.gold)
            Text(text)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppColors.surfaceElevated.opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.gold.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
