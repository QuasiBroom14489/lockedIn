import Foundation

protocol MusicPlaybackService: AnyObject {
    var onStateChange: ((FocusAudioState) -> Void)? { get set }

    func connect() async throws
    func disconnect()
    func refreshState() async
    func playPause() async throws
    func nextTrack() async throws
    func previousTrack() async throws
    func setVolume(_ value: Double) async throws

    func seekForward() async throws
    func openQueue() async throws
}

enum MusicPlaybackError: LocalizedError {
    case notConnected
    case capabilityNotAvailable(action: String)
    case externalNavigationBlocked

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Music provider is not connected."
        case .capabilityNotAvailable(let action):
            return "\(action) is not available in locked mode."
        case .externalNavigationBlocked:
            return "This action would leave lockedIn and break focus. Use in-app controls only."
        }
    }
}
