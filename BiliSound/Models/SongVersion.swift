import Foundation

/// Represents a distinct Bilibili video version for a Song (Feature 4: Multi-Version Track Mapping).
/// A song can have multiple versions (e.g., Original Studio MV, Concert Live, Acoustic Cover, Piano Solo).
public struct SongVersion: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    /// Display name of this version (e.g., "Original Studio MV", "2024 World Tour Live", "Acoustic Unplugged")
    public var name: String
    /// Bilibili Video ID (BV number, e.g., "BV1GJ411x7h7")
    public var bvid: String
    /// Cached Content ID (CID) for audio extraction; resolved automatically if nil
    public var cid: Int?
    /// Uploader / UP Master handle
    public var uploader: String
    /// Duration in seconds
    public var duration: TimeInterval
    /// Audio stream quality descriptor (e.g. "192kbps DASH", "HQ Audio", "Lossless / FLAC")
    public var audioQuality: String
    /// Thumbnail / artwork URL specific to this version
    public var picUrl: String?
    /// Whether this version is active for random selection
    public var isEnabled: Bool
    /// Selection weight (default 1.0; higher weights mean higher chance to be chosen)
    public var weight: Double
    /// Number of times this version has been selected
    public var playCount: Int
    /// Timestamp of last playback
    public var lastPlayedAt: Date?
    
    public init(
        id: UUID = UUID(),
        name: String,
        bvid: String,
        cid: Int? = nil,
        uploader: String = "Bilibili Artist",
        duration: TimeInterval = 0,
        audioQuality: String = "192kbps DASH",
        picUrl: String? = nil,
        isEnabled: Bool = true,
        weight: Double = 1.0,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.bvid = bvid
        self.cid = cid
        self.uploader = uploader
        self.duration = duration
        self.audioQuality = audioQuality
        self.picUrl = picUrl
        self.isEnabled = isEnabled
        self.weight = weight
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
    
    /// Web link to this Bilibili video
    public var webUrl: URL? {
        URL(string: "https://www.bilibili.com/video/\(bvid)")
    }
    
    /// Formatted duration string (mm:ss)
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
