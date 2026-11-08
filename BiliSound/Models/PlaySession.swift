import Foundation

/// Audit log record for each track played in a session
public struct SessionPlayRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let songId: UUID
    public let songTitle: String
    public let versionId: UUID
    public let versionName: String
    public let playedAt: Date
    
    public init(
        id: UUID = UUID(),
        songId: UUID,
        songTitle: String,
        versionId: UUID,
        versionName: String,
        playedAt: Date = Date()
    ) {
        self.id = id
        self.songId = songId
        self.songTitle = songTitle
        self.versionId = versionId
        self.versionName = versionName
        self.playedAt = playedAt
    }
}

/// Tracks playback within a single listening session (Feature 3).
/// Guarantees that in 1 session, shuffle/random autoplay will not select a song
/// that has already been played in that session until all songs have been played.
public final class PlaySession: ObservableObject, Codable {
    public let id: UUID
    public let startedAt: Date
    
    /// Set of Song IDs that have already been played during this session
    @Published public private(set) var playedSongIds: Set<UUID> = []
    
    /// Chronological list of play events with specific versions
    @Published public private(set) var history: [SessionPlayRecord] = []
    
    /// How many times the session has looped after exhausting all tracks
    @Published public private(set) var loopCycleCount: Int = 0
    
    public init(id: UUID = UUID(), startedAt: Date = Date()) {
        self.id = id
        self.startedAt = startedAt
    }
    
    // MARK: - Codable Conformance
    enum CodingKeys: CodingKey {
        case id, startedAt, playedSongIds, history, loopCycleCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.playedSongIds = try container.decode(Set<UUID>.self, forKey: .playedSongIds)
        self.history = try container.decode([SessionPlayRecord].self, forKey: .history)
        self.loopCycleCount = try container.decode(Int.self, forKey: .loopCycleCount)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(playedSongIds, forKey: .playedSongIds)
        try container.encode(history, forKey: .history)
        try container.encode(loopCycleCount, forKey: .loopCycleCount)
    }
    
    // MARK: - Session Management
    
    /// Records a song and version play in the current session
    public func recordPlay(song: Song, version: SongVersion) {
        playedSongIds.insert(song.id)
        let record = SessionPlayRecord(
            songId: song.id,
            songTitle: song.title,
            versionId: version.id,
            versionName: version.name,
            playedAt: Date()
        )
        history.append(record)
    }
    
    /// Checks if a song has already been played in this session
    public func hasPlayed(songId: UUID) -> Bool {
        playedSongIds.contains(songId)
    }
    
    /// Returns songs from the given playlist that have NOT been played yet in this session
    public func unplayedSongs(from playlist: Playlist) -> [Song] {
        playlist.songs.filter { !playedSongIds.contains($0.id) }
    }
    
    /// Feature 3 & 2: Picks the next unplayed song randomly for shuffle mode.
    /// If all songs have been played, automatically completes the cycle, resets the played set,
    /// and picks from the full playlist to keep continuous music flowing without dead ends.
    public func pickNextShuffleSong(from playlist: Playlist, excludingSongId: UUID? = nil) -> Song? {
        guard !playlist.songs.isEmpty else { return nil }
        
        var candidates = unplayedSongs(from: playlist)
        
        // If all songs have already been played in this session, start a new loop cycle!
        if candidates.isEmpty {
            loopCycleCount += 1
            playedSongIds.removeAll()
            // Reset candidates to full playlist
            candidates = playlist.songs
            // If more than 1 song exists, avoid repeating the immediately previous song right at cycle restart
            if let excluding = excludingSongId, candidates.count > 1 {
                candidates.removeAll { $0.id == excluding }
            }
        }
        
        return candidates.randomElement()
    }
    
    /// Manually clears session history to start a fresh non-repeating cycle
    public func reset() {
        playedSongIds.removeAll()
        history.removeAll()
        loopCycleCount = 0
    }
}
