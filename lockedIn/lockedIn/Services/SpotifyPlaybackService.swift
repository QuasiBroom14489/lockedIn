import Foundation
import SpotifyiOS
import Combine

@MainActor
final class SpotifyPlaybackService: MusicPlaybackService {
    static let shared = SpotifyPlaybackService()

    var onStateChange: ((FocusAudioState) -> Void)?

    private var state: FocusAudioState = .disconnected {
        didSet {
            onStateChange?(state)
        }
    }

    private var authManager: SpotifyAuthManager { SpotifyAuthManager.shared }
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe auth manager connection state
        authManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self else { return }
                self.state.isConnected = isConnected
                if !isConnected {
                    self.state.isPlaying = false
                    self.state.track = .placeholder
                }
            }
            .store(in: &cancellables)

        authManager.$connectionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.state.errorMessage = error
            }
            .store(in: &cancellables)

        // Subscribe to player state changes
        authManager.onPlayerStateChange = { [weak self] playerState in
            Task { @MainActor in
                self?.handlePlayerStateChange(playerState)
            }
        }
    }

    private func handlePlayerStateChange(_ playerState: SPTAppRemotePlayerState) {
        state.isPlaying = !playerState.isPaused

        let track = playerState.track
        state.track = FocusAudioTrack(
            title: track.name,
            artist: track.artist.name,
            artworkURL: nil // Will fetch artwork separately if needed
        )

        // Fetch artwork if available
        fetchArtwork(for: track)
    }

    private func fetchArtwork(for track: SPTAppRemoteTrack) {
        guard let appRemote = authManager.appRemote,
              appRemote.isConnected else { return }

        appRemote.imageAPI?.fetchImage(forItem: track, with: CGSize(width: 200, height: 200)) { [weak self] image, error in
            Task { @MainActor in
                if let image = image as? UIImage,
                   let imageData = image.pngData() {
                    // Store as base64 data URL for SwiftUI compatibility
                    let base64 = imageData.base64EncodedString()
                    self?.state.track.artworkURL = "data:image/png;base64,\(base64)"
                }
            }
        }
    }

    // MARK: - MusicPlaybackService

    func connect() async throws {
        guard !authManager.isConnected else { return }

        // Check if Spotify is installed
        guard authManager.isSpotifyInstalled() else {
            state.errorMessage = "Spotify app is not installed. Please install Spotify to use this feature."
            throw MusicPlaybackError.notConnected
        }

        authManager.initiateConnection()

        // Wait for connection or error (with timeout)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false

            let connectionSubscription = authManager.$isConnected
                .dropFirst()
                .first { $0 == true }
                .sink { _ in
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume()
                }

            let errorSubscription = authManager.$connectionError
                .dropFirst()
                .compactMap { $0 }
                .first()
                .sink { error in
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(throwing: MusicPlaybackError.notConnected)
                }

            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !didResume else { return }
                didResume = true
                connectionSubscription.cancel()
                errorSubscription.cancel()
                continuation.resume(throwing: MusicPlaybackError.notConnected)
            }
        }

        state.isConnected = true
        state.capability = .minimal
    }

    func disconnect() {
        authManager.disconnect()
        state = .disconnected
    }

    func refreshState() async {
        guard let appRemote = authManager.appRemote,
              appRemote.isConnected else {
            state.isConnected = false
            return
        }

        appRemote.playerAPI?.getPlayerState { [weak self] result, error in
            Task { @MainActor in
                if let playerState = result as? SPTAppRemotePlayerState {
                    self?.handlePlayerStateChange(playerState)
                } else if let error {
                    self?.state.warningMessage = error.localizedDescription
                }
            }
        }
    }

    func playPause() async throws {
        guard state.isConnected else { throw MusicPlaybackError.notConnected }
        guard state.capability.canPlayPause else {
            throw MusicPlaybackError.capabilityNotAvailable(action: "Play/Pause")
        }

        guard let appRemote = authManager.appRemote,
              appRemote.isConnected else {
            throw MusicPlaybackError.notConnected
        }

        if state.isPlaying {
            appRemote.playerAPI?.pause { [weak self] _, error in
                Task { @MainActor in
                    if let error {
                        self?.state.warningMessage = error.localizedDescription
                    } else {
                        self?.state.isPlaying = false
                    }
                }
            }
        } else {
            appRemote.playerAPI?.resume { [weak self] _, error in
                Task { @MainActor in
                    if let error {
                        self?.state.warningMessage = error.localizedDescription
                    } else {
                        self?.state.isPlaying = true
                    }
                }
            }
        }
    }

    func nextTrack() async throws {
        guard state.isConnected else { throw MusicPlaybackError.notConnected }
        guard state.capability.canSkip else {
            throw MusicPlaybackError.capabilityNotAvailable(action: "Skip")
        }

        guard let appRemote = authManager.appRemote,
              appRemote.isConnected else {
            throw MusicPlaybackError.notConnected
        }

        appRemote.playerAPI?.skip(toNext: { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.state.warningMessage = error.localizedDescription
                }
            }
        })
    }

    func previousTrack() async throws {
        guard state.isConnected else { throw MusicPlaybackError.notConnected }
        guard state.capability.canSkip else {
            throw MusicPlaybackError.capabilityNotAvailable(action: "Previous")
        }

        guard let appRemote = authManager.appRemote,
              appRemote.isConnected else {
            throw MusicPlaybackError.notConnected
        }

        appRemote.playerAPI?.skip(toPrevious: { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.state.warningMessage = error.localizedDescription
                }
            }
        })
    }

    func setVolume(_ value: Double) async throws {
        guard state.isConnected else { throw MusicPlaybackError.notConnected }
        guard state.capability.canAdjustVolume else {
            throw MusicPlaybackError.capabilityNotAvailable(action: "Volume")
        }

        // Note: SPTAppRemote doesn't directly support volume control
        // Volume is controlled through device volume
        // We update local state for UI consistency
        state.volume = min(max(value, 0), 1)
        state.warningMessage = "Volume control uses device volume"
    }

    func seekForward() async throws {
        throw MusicPlaybackError.externalNavigationBlocked
    }

    func openQueue() async throws {
        throw MusicPlaybackError.externalNavigationBlocked
    }

    // MARK: - Auto-reconnect

    func attemptReconnect() {
        authManager.reconnectIfNeeded()
    }
}
