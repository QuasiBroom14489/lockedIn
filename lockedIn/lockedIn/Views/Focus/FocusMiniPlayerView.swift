import SwiftUI

struct FocusMiniPlayerView: View {
    @ObservedObject var viewModel: FocusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                artwork

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.audioState.track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(viewModel.audioState.track.artist)
                        .font(AppFonts.focusCaption())
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if viewModel.isMusicConnecting {
                    ProgressView()
                        .tint(AppColors.gold)
                } else {
                    Text(viewModel.audioState.providerName)
                        .font(AppFonts.focusCaption())
                        .foregroundColor(AppColors.gold)
                }
            }

            HStack(spacing: 12) {
                miniButton(systemName: "backward.fill", isEnabled: viewModel.audioState.capability.canSkip) {
                    Task { await viewModel.skipPrevious() }
                }

                miniButton(systemName: viewModel.audioState.isPlaying ? "pause.fill" : "play.fill", isEnabled: viewModel.audioState.capability.canPlayPause) {
                    Task { await viewModel.togglePlayPause() }
                }

                miniButton(systemName: "forward.fill", isEnabled: viewModel.audioState.capability.canSkip) {
                    Task { await viewModel.skipNext() }
                }

                miniButton(systemName: "goforward", isEnabled: true) {
                    Task {
                        if viewModel.audioState.capability.canSeek {
                            await viewModel.seekForward()
                        } else {
                            viewModel.handleBlockedExternalMusicAction(action: "seek")
                        }
                    }
                }

                miniButton(systemName: "text.line.first.and.arrowtriangle.forward", isEnabled: true) {
                    Task {
                        if viewModel.audioState.capability.canOpenQueue {
                            await viewModel.openQueue()
                        } else {
                            viewModel.handleBlockedExternalMusicAction(action: "queue")
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Slider(
                    value: Binding(
                        get: { viewModel.audioState.volume },
                        set: { value in
                            Task { await viewModel.updateVolume(value) }
                        }
                    ),
                    in: 0...1
                )
                .tint(AppColors.gold)
                .disabled(!viewModel.audioState.capability.canAdjustVolume)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            if let warning = viewModel.musicWarningMessage, warning.isNotEmpty {
                Text(warning)
                    .font(.caption)
                    .foregroundColor(AppColors.warning)
                    .onTapGesture {
                        viewModel.clearMusicWarning()
                    }
            }
        }
        .focusCardStyle()
    }

    private func miniButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .foregroundColor(isEnabled ? AppColors.textPrimary : AppColors.textTertiary)
                .frame(width: Constants.UI.miniPlayerControlSize, height: Constants.UI.miniPlayerControlSize)
                .background(
                    Circle()
                        .fill(isEnabled ? AppColors.surface.opacity(0.85) : AppColors.surface.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var artwork: some View {
        Group {
            if let artwork = viewModel.audioState.track.artworkURL,
               let url = URL(string: artwork) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppColors.surface)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.gold)
            )
    }
}

#Preview {
    FocusMiniPlayerView(viewModel: FocusViewModel())
        .padding()
        .background(AppColors.background)
}
