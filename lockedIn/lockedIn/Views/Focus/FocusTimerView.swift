import SwiftUI

struct FocusTimerView: View {
    @StateObject private var viewModel = FocusViewModel()
    @StateObject private var spotifyAuth = SpotifyAuthManager.shared
    @State private var showHistory = false
    @State private var isConnectingSpotify = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.background, AppColors.backgroundSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .ambientBackgroundLayer()

                VStack(spacing: 22) {
                    topHeader

                    timerHero

                    if !viewModel.isSessionActive {
                        DurationPickerView(
                            selectedDuration: $viewModel.selectedDurationMinutes,
                            options: viewModel.durationOptions
                        )
                        .focusCardStyle()

                        spotifyConnectionCard
                    }

                    actionSection

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showHistory) {
                SessionHistoryView(sessions: viewModel.recentSessions)
            }
            .fullScreenCover(isPresented: $viewModel.isSessionActive) {
                ActiveSessionView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showSessionComplete) {
                SessionCompleteView(
                    duration: viewModel.completedSessionDuration,
                    onDismiss: {
                        viewModel.showSessionComplete = false
                    }
                )
            }
            .task {
                await viewModel.loadRecentSessions()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    private var topHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundColor(AppColors.gold)

                Text("Locked In")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer(minLength: 0)

            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(AppColors.gold)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(AppColors.surface.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
        }
        .focusCardStyle()
    }

    private var timerHero: some View {
        VStack(spacing: 12) {
            Text(viewModel.isSessionActive ? viewModel.timerDisplay : "\(viewModel.selectedDurationMinutes):00")
                .font(AppFonts.focusDisplay())
                .foregroundColor(AppColors.gold)
                .monospacedDigit()
                .goldGlow(radius: 12, opacity: 0.32)

            if !viewModel.isSessionActive {
                Text("Select duration and start focusing")
                    .font(AppFonts.focusBody())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("Session in progress")
                    .font(AppFonts.focusCaption())
                    .foregroundColor(AppColors.textSecondary)
            }

            if viewModel.isSessionActive {
                ZStack {
                    Circle()
                        .stroke(AppColors.borderSubtle, lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            AppColors.gold,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.progress)
                        .goldGlow(radius: 12, opacity: 0.4)
                }
                .frame(width: 190, height: 190)
                .padding(.top, 4)
            }
        }
        .focusCardStyle()
    }

    private var spotifyConnectionCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundColor(AppColors.greenLight)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify")
                        .font(AppFonts.focusBody())
                        .foregroundColor(AppColors.textPrimary)

                    if spotifyAuth.isConnected {
                        Text("Connected")
                            .font(AppFonts.focusCaption())
                            .foregroundColor(AppColors.success)
                    } else if let error = spotifyAuth.connectionError {
                        Text(error)
                            .font(AppFonts.focusCaption())
                            .foregroundColor(AppColors.warning)
                            .lineLimit(1)
                    } else {
                        Text("Control playback during focus")
                            .font(AppFonts.focusCaption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if spotifyAuth.isConnected {
                    Button {
                        spotifyAuth.disconnect()
                    } label: {
                        Text("Disconnect")
                            .font(AppFonts.focusCaption())
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.surface)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        isConnectingSpotify = true
                        spotifyAuth.initiateConnection()
                    } label: {
                        HStack(spacing: 4) {
                            if spotifyAuth.isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AppColors.background)
                            } else {
                                Text("Connect")
                            }
                        }
                        .font(AppFonts.focusCaption().weight(.semibold))
                        .foregroundColor(AppColors.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.greenLight)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(spotifyAuth.isConnecting)
                }
            }

            if !spotifyAuth.isSpotifyInstalled() && !spotifyAuth.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Spotify app not installed")
                        .font(AppFonts.focusCaption())
                }
                .foregroundColor(AppColors.warning)
            }
        }
        .focusCardStyle()
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if viewModel.isSessionActive {
                Button {
                    Task { await viewModel.endSession(early: true) }
                } label: {
                    Text("End Session")
                }
                .secondaryButtonStyle()
            } else {
                Button {
                    Task { await viewModel.startSession() }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Focus Session")
                    }
                }
                .primaryButtonStyle()
            }
        }
    }
}

// MARK: - Duration Picker

struct DurationPickerView: View {
    @Binding var selectedDuration: Int
    let options: [Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { duration in
                    DurationOption(
                        minutes: duration,
                        isSelected: selectedDuration == duration,
                        onTap: { selectedDuration = duration }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct DurationOption: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.title2.weight(.bold))
                Text("min")
                    .font(AppFonts.focusCaption())
            }
            .foregroundColor(isSelected ? AppColors.background : AppColors.gold)
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppColors.gold : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.gold.opacity(isSelected ? 0 : 0.45), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session History

struct SessionHistoryView: View {
    let sessions: [FocusSession]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "clock",
                        description: Text("Complete your first focus session to see it here")
                    )
                } else {
                    ForEach(sessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.formattedDuration)
                                    .font(.headline)
                                Text(session.formattedStartTime)
                                    .font(AppFonts.caption())
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if session.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FocusTimerView()
}
