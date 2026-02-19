import SwiftUI

struct ActiveSessionView: View {
    @ObservedObject var viewModel: FocusViewModel
    @State private var showEndConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.surface)
                        .frame(height: geometry.size.height * 0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.gold)
                                Text("Stay locked in")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Leaving the app ends your focus session.")
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        }
                        .padding()

                Spacer()

                // Timer Display
                VStack(spacing: 16) {
                    Text(viewModel.timerDisplay)
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.gold)
                        .goldGlow(radius: 12, opacity: 0.4)

                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.borderSubtle)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.gold)
                                .frame(width: geometry.size.width * viewModel.progress, height: 8)
                                .animation(.linear(duration: 1), value: viewModel.progress)
                                .goldGlow(radius: 8, opacity: 0.3)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)

                    Text(viewModel.currentTip)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .id(viewModel.currentTip)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: viewModel.currentTip)
                }
                .padding(.vertical, 32)

                Spacer()

                // Status Indicators
                HStack(spacing: 24) {
                    StatusIndicator(
                        icon: "lock.fill",
                        label: "Locked In",
                        isActive: true
                    )

                    if viewModel.isPaused {
                        StatusIndicator(
                            icon: "pause.fill",
                            label: "Paused",
                            isActive: true,
                            color: .orange
                        )
                    }
                }
                .padding(.vertical, 16)

                // End Session Button
                Button {
                    showEndConfirmation = true
                } label: {
                    Text("End Session Early")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(Constants.UI.cornerRadius)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            }
        }
        .confirmationDialog(
            "End Session?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                Task {
                    await viewModel.endSession(early: true)
                }
            }
            Button("Continue Focusing", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this focus session early? Your progress will still be saved if you've focused for at least 1 minute.")
        }
        .onAppear {
            // Keep screen awake
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let icon: String
    let label: String
    let isActive: Bool
    var color: Color = AppColors.success

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? color.opacity(0.2) : AppColors.surface)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .foregroundColor(isActive ? color : AppColors.textTertiary)
            }

            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)
        }
    }
}

#Preview {
    ActiveSessionView(viewModel: FocusViewModel())
}
