import Foundation

/// Playback modes supported by the music player (Feature 2)
public enum PlaybackMode: String, CaseIterable, Identifiable, Codable {
    /// Plays songs in sequential order: 1 -> 2 -> 3 -> ...
    case sequential = "Sequential"
    /// Randomly autoplays a song from the playlist without repeating in the current session
    case shuffle = "Shuffle"
    /// Loops the currently playing song/version
    case repeatOne = "Repeat One"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .sequential:
            return "repeat"
        case .shuffle:
            return "shuffle"
        case .repeatOne:
            return "repeat.1"
        }
    }
    
    public var displayName: String {
        switch self {
        case .sequential:
            return "Consecutive Order"
        case .shuffle:
            return "Session Shuffle"
        case .repeatOne:
            return "Repeat Current"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .sequential:
            return "Plays tracks 1-by-1 in playlist order"
        case .shuffle:
            return "Random autoplay without repeating in session"
        case .repeatOne:
            return "Loop current track continuously"
        }
    }
}
