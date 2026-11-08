import Foundation

/// Represents a collection of songs organized into a playlist
public struct Playlist: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String
    public var coverUrl: String?
    public var songs: [Song]
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        coverUrl: String? = nil,
        songs: [Song] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverUrl = coverUrl
        self.songs = songs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Total duration of all songs using their primary/average version
    public var totalEstimatedDuration: TimeInterval {
        songs.reduce(0) { total, song in
            let versionDuration = song.versions.first?.duration ?? 240
            return total + versionDuration
        }
    }
    
    /// Formatted total duration (e.g. "1 hr 15 min" or "45 min")
    public var formattedDuration: String {
        let hours = Int(totalEstimatedDuration) / 3600
        let minutes = (Int(totalEstimatedDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
    
    /// Total count of all video versions across all songs
    public var totalVersionsCount: Int {
        songs.reduce(0) { $0 + $1.versions.count }
    }
    
    /// Finds the index of a song by its ID
    public func index(ofSongId id: UUID) -> Int? {
        songs.firstIndex { $0.id == id }
    }
    
    /// Finds a song by ID
    public func song(withId id: UUID) -> Song? {
        songs.first { $0.id == id }
    }
}
