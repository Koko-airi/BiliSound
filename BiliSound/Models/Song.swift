import Foundation

/// Represents a Song entity in a playlist (Feature 4).
/// A single Song can contain multiple Bilibili video versions (e.g. Studio, Live, Acoustic, Remix).
/// When selected, the player will randomly choose one of these versions.
public struct Song: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    /// Title of the song (e.g., "夜曲", "Lemon", "群青")
    public var title: String
    /// Primary artist (e.g., "Jay Chou", "YOASOBI")
    public var artist: String
    /// Optional album name
    public var album: String?
    /// Default artwork URL (falls back to selected version's artwork if nil)
    public var artworkUrl: String?
    /// List of available Bilibili versions for this song
    public var versions: [SongVersion]
    /// Optional explicitly preferred version ID; if nil or in random mode, random selection is used
    public var preferredVersionId: UUID?
    /// Date added to playlist
    public var addedAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String? = nil,
        artworkUrl: String? = nil,
        versions: [SongVersion] = [],
        preferredVersionId: UUID? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkUrl = artworkUrl
        self.versions = versions
        self.preferredVersionId = preferredVersionId
        self.addedAt = addedAt
    }
    
    // MARK: - Feature 4: Version Selection Logic
    
    /// Randomly selects one of the available, enabled versions based on relative weights.
    /// Returns nil only if no versions exist.
    public func selectRandomVersion() -> SongVersion? {
        let enabledVersions = versions.filter { $0.isEnabled }
        guard !enabledVersions.isEmpty else {
            // Fallback to any version if all are toggled off
            return versions.first
        }
        
        // Weighted random selection
        let totalWeight = enabledVersions.reduce(0.0) { $0 + max(0.01, $1.weight) }
        guard totalWeight > 0 else {
            return enabledVersions.randomElement()
        }
        
        let randomThreshold = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for version in enabledVersions {
            cumulative += max(0.01, version.weight)
            if randomThreshold < cumulative {
                return version
            }
        }
        
        return enabledVersions.first
    }
    
    /// Finds a version by its ID
    public func version(withId id: UUID) -> SongVersion? {
        versions.first { $0.id == id }
    }
    
    /// Count of enabled versions
    public var activeVersionCount: Int {
        versions.filter { $0.isEnabled }.count
    }
    
    /// Helper to add a new version to this song
    public mutating func addVersion(_ version: SongVersion) {
        versions.append(version)
    }
    
    /// Helper to remove a version
    public mutating func removeVersion(withId id: UUID) {
        versions.removeAll { $0.id == id }
    }
}
