import Foundation

struct MusicControlCapability: Equatable, Codable {
    var canPlayPause: Bool
    var canSkip: Bool
    var canAdjustVolume: Bool
    var canSeek: Bool
    var canOpenQueue: Bool

    static let minimal = MusicControlCapability(
        canPlayPause: true,
        canSkip: true,
        canAdjustVolume: true,
        canSeek: false,
        canOpenQueue: false
    )
}

struct FocusAudioTrack: Equatable, Codable {
    var title: String
    var artist: String
    var artworkURL: String?

    static let placeholder = FocusAudioTrack(
        title: "No track playing",
        artist: "Spotify",
        artworkURL: nil
    )
}

struct FocusAudioState: Equatable, Codable {
    var isConnected: Bool
    var isPlaying: Bool
    var providerName: String
    var track: FocusAudioTrack
    var volume: Double
    var capability: MusicControlCapability
    var warningMessage: String?
    var errorMessage: String?

    static let disconnected = FocusAudioState(
        isConnected: false,
        isPlaying: false,
        providerName: "Spotify",
        track: .placeholder,
        volume: 0.6,
        capability: .minimal,
        warningMessage: nil,
        errorMessage: nil
    )
}
