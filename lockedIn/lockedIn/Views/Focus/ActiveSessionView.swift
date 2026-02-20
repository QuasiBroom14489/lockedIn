import SwiftUI
import UIKit

struct ActiveSessionView: View {
    @ObservedObject var viewModel: FocusViewModel
    @State private var showEndConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.background, AppColors.backgroundSecondary, AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .ambientBackgroundLayer()

            VStack(spacing: 18) {
                topLockCard

                timerCard

                if viewModel.showMusicControls {
                    FocusMiniPlayerView(viewModel: viewModel)
                }

                Spacer(minLength: 8)

                Button {
                    showEndConfirmation = true
                } label: {
                    Text("End Session Early")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.UI.buttonHeight)
                        .background(Color.red.opacity(0.82))
                        .cornerRadius(Constants.UI.cornerRadius)
                }
            }
            .padding(16)
        }
        .confirmationDialog(
            "End Session?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                Task { await viewModel.endSession(early: true) }
            }
            Button("Continue Focusing", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this focus session early? Your progress will still be saved if you've focused for at least 1 minute.")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var topLockCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundColor(AppColors.gold)

            VStack(alignment: .leading, spacing: 3) {
                Text("Locked In")
                    .font(AppFonts.focusHeader())
                    .foregroundColor(AppColors.textPrimary)

                Text("Leaving the app ends your focus session.")
                    .font(AppFonts.focusCaption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer(minLength: 0)

            if viewModel.isPaused {
                Text("Paused")
                    .modernCapsuleChipStyle(
                        foreground: AppColors.warning,
                        background: AppColors.warning.opacity(0.18)
                    )
            } else {
                Text("Active")
                    .modernCapsuleChipStyle(
                        foreground: AppColors.success,
                        background: AppColors.success.opacity(0.2)
                    )
            }
        }
        .focusCardStyle()
    }

    private var timerCard: some View {
        VStack(spacing: 16) {
            Text(viewModel.timerDisplay)
                .font(AppFonts.focusDisplay())
                .foregroundColor(AppColors.gold)
                .monospacedDigit()
                .goldGlow(radius: 14, opacity: 0.35)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.borderSubtle)
                    .frame(height: 10)

                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.gold)
                        .frame(width: proxy.size.width * viewModel.progress, height: 10)
                        .animation(.linear(duration: 1), value: viewModel.progress)
                }
            }
            .frame(height: 10)

            Text(viewModel.currentTip)
                .font(AppFonts.focusBody())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .id(viewModel.currentTip)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: Constants.UI.focusAnimationDuration), value: viewModel.currentTip)
                .padding(.horizontal, 8)
        }
        .focusCardStyle()
    }
}

#Preview {
    ActiveSessionView(viewModel: FocusViewModel())
}
