import SwiftUI

struct FocusTimerView: View {
    @StateObject private var viewModel = FocusViewModel()
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Timer Display
                VStack(spacing: 8) {
                    Text(viewModel.isSessionActive ? viewModel.timerDisplay : "\(viewModel.selectedDurationMinutes):00")
                        .font(AppFonts.timer())
                        .foregroundColor(AppColors.gold)
                        .monospacedDigit()
                        .goldGlow(radius: 8, opacity: 0.25)

                    if !viewModel.isSessionActive {
                        Text("Select duration and start focusing")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Duration Picker (when not in session)
                if !viewModel.isSessionActive {
                    DurationPickerView(
                        selectedDuration: $viewModel.selectedDurationMinutes,
                        options: viewModel.durationOptions
                    )
                }

                // Progress Ring (during session)
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

                        VStack {
                            Text("Stay Focused")
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .padding()
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    if viewModel.isSessionActive {
                        // End Session Button
                        Button {
                            Task {
                                await viewModel.endSession(early: true)
                            }
                        } label: {
                            Text("End Session")
                        }
                        .secondaryButtonStyle()
                    } else {
                        // Start Button
                        Button {
                            Task {
                                await viewModel.startSession()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Focus Session")
                            }
                        }
                        .primaryButtonStyle()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding()
            .background(AppColors.background)
            .navigationTitle("Focus")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
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
            .padding(.horizontal)
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
                    .font(.title2)
                    .fontWeight(.bold)
                Text("min")
                    .font(AppFonts.caption())
            }
            .foregroundColor(isSelected ? AppColors.background : AppColors.gold)
            .frame(width: 70, height: 70)
            .background(isSelected ? AppColors.gold : AppColors.surface)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.gold.opacity(isSelected ? 0 : 0.5), lineWidth: isSelected ? 0 : 1.5)
            )
        }
        .goldGlow(radius: isSelected ? 6 : 0, opacity: isSelected ? 0.25 : 0)
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
