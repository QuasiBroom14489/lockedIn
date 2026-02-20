import Foundation
import Combine
import SpotifyiOS
import UIKit

@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()

    // MARK: - Published State

    @Published private(set) var isConnected = false
    @Published private(set) var isConnecting = false
    @Published private(set) var connectionError: String?

    // MARK: - SPTAppRemote

    private(set) var appRemote: SPTAppRemote?

    private var accessToken: String? {
        get { KeychainHelper.readString(forKey: "spotifyAccessToken") }
        set {
            if let token = newValue {
                try? KeychainHelper.save(token, forKey: "spotifyAccessToken")
            } else {
                KeychainHelper.delete(forKey: "spotifyAccessToken")
            }
        }
    }

    // MARK: - Callbacks

    var onPlayerStateChange: ((SPTAppRemotePlayerState) -> Void)?

    // MARK: - Init

    private override init() {
        super.init()
        configureAppRemote()
    }

    // MARK: - Configuration

    private func configureAppRemote() {
        let configuration = SPTConfiguration(
            clientID: Constants.Spotify.clientID,
            redirectURL: Constants.Spotify.redirectURL
        )

        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.delegate = self

        // Restore previous token if available
        if let token = accessToken {
            appRemote?.connectionParameters.accessToken = token
        }
    }

    // MARK: - Connection

    func initiateConnection() {
        guard !isConnecting else { return }

        isConnecting = true
        connectionError = nil

        // Check if Spotify is installed
        guard isSpotifyInstalled() else {
            connectionError = "Spotify app is not installed"
            isConnecting = false
            return
        }

        // If we have a token, try to connect directly
        if let token = accessToken {
            appRemote?.connectionParameters.accessToken = token
            appRemote?.connect()
        } else {
            // Otherwise, authorize via Spotify app
            authorizeAndConnect()
        }
    }

    private func authorizeAndConnect() {
        guard let appRemote else { return }

        // Use the session manager approach for authorization
        appRemote.authorizeAndPlayURI("")
    }

    func handleAuthCallback(url: URL) -> Bool {
        guard let appRemote else { return false }

        // Extract access token from URL parameters
        let params = appRemote.authorizationParameters(from: url)

        if let token = params?[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
            return true
        } else if let errorDescription = params?[SPTAppRemoteErrorDescriptionKey] {
            connectionError = errorDescription
            isConnecting = false
            return false
        }

        return false
    }

    func disconnect() {
        appRemote?.disconnect()
        accessToken = nil
        isConnected = false
        isConnecting = false
        connectionError = nil
    }

    func reconnectIfNeeded() {
        guard let appRemote, !isConnected, accessToken != nil else { return }
        appRemote.connect()
    }

    // MARK: - Helpers

    func isSpotifyInstalled() -> Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

// MARK: - SPTAppRemoteDelegate

extension SpotifyAuthManager: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in
            self.isConnected = true
            self.isConnecting = false
            self.connectionError = nil

            // Subscribe to player state updates
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
                if let error {
                    print("Error subscribing to player state: \(error)")
                }
            })
        }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.isConnecting = false
            if let error {
                self.connectionError = error.localizedDescription
            }
        }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.isConnecting = false
            if let error {
                self.connectionError = error.localizedDescription
                // Clear invalid token
                self.accessToken = nil
            }
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate

extension SpotifyAuthManager: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in
            self.onPlayerStateChange?(playerState)
        }
    }
}
