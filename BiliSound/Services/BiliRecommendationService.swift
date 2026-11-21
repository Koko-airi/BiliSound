import Foundation
import Combine

/// Model representing a track recommended from Bilibili related videos.
public struct RecommendedTrack: Identifiable, Sendable, Codable, Hashable, Equatable {
    public let id: UUID
    public let bvid: String
    public let title: String
    public let uploader: String
    public let coverUrl: String
    public let duration: TimeInterval
    public let seedBvId: String
    public let seedTitle: String?
    
    public init(
        id: UUID = UUID(),
        bvid: String,
        title: String,
        uploader: String,
        coverUrl: String,
        duration: TimeInterval,
        seedBvId: String,
        seedTitle: String? = nil
    ) {
        self.id = id
        self.bvid = bvid
        self.title = title
        self.uploader = uploader
        self.coverUrl = coverUrl
        self.duration = duration
        self.seedBvId = seedBvId
        self.seedTitle = seedTitle
    }
    
    /// Formatted duration in mm:ss format
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Web URL for the video
    public var webUrl: URL? {
        URL(string: "https://www.bilibili.com/video/\(bvid)")
    }
    
    /// Converts this recommendation into a playable Song model for immediate preview or playback
    public func toSong() -> Song {
        let version = SongVersion(
            name: title,
            bvid: bvid,
            uploader: uploader,
            duration: duration,
            audioQuality: "192kbps DASH",
            picUrl: coverUrl,
            isEnabled: true,
            weight: 1.0
        )
        return Song(
            title: title,
            artist: uploader,
            artworkUrl: coverUrl,
            versions: [version]
        )
    }
}

/// Service that generates music-focused playlist recommendations by querying Bilibili's related videos API.
@MainActor
public final class BiliRecommendationService: ObservableObject {
    public static let shared = BiliRecommendationService()
    
    @Published public var recommendations: [RecommendedTrack] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    // MARK: - 21-Day Dismissal Management (Ultra-low memory: ~10 KB)
    private let dismissedStorageKey = "bili_recommendations_dismissed_timestamps"
    public static let dismissalRetentionPeriod: TimeInterval = 21 * 24 * 60 * 60 // 21 days in seconds
    
    /// Map of dismissed BV ID -> timestamp of dismissal
    private var dismissedTimestamps: [String: TimeInterval] = [:]
    
    /// Active (non-expired) dismissed BV IDs
    public var dismissedBvIds: Set<String> {
        get {
            let cutoff = Date().timeIntervalSince1970 - Self.dismissalRetentionPeriod
            return Set(dismissedTimestamps.filter { $0.value > cutoff }.keys)
        }
        set {
            let now = Date().timeIntervalSince1970
            for bvid in newValue {
                dismissedTimestamps[bvid] = now
            }
            saveDismissedTimestamps()
        }
    }
    
    private let session: URLSession
    
    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            // Recommendation queries must be uninfluenced by user browsing history and cookies
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil
            config.httpCookieAcceptPolicy = .never
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 10
            self.session = URLSession(configuration: config)
        }
        
        // Load persisted dismissed timestamps and purge any older than 21 days
        if let saved = UserDefaults.standard.dictionary(forKey: dismissedStorageKey) as? [String: TimeInterval] {
            self.dismissedTimestamps = saved
            purgeExpiredDismissals()
        }
    }
    
    private func purgeExpiredDismissals() {
        let cutoff = Date().timeIntervalSince1970 - Self.dismissalRetentionPeriod
        let countBefore = dismissedTimestamps.count
        dismissedTimestamps = dismissedTimestamps.filter { $0.value > cutoff }
        if dismissedTimestamps.count != countBefore {
            saveDismissedTimestamps()
        }
    }
    
    private func saveDismissedTimestamps() {
        UserDefaults.standard.set(dismissedTimestamps, forKey: dismissedStorageKey)
    }
    
    /// Checks whether a track was dismissed within the active 21-day retention window
    public func isDismissed(bvid: String) -> Bool {
        guard let timestamp = dismissedTimestamps[bvid] else { return false }
        let now = Date().timeIntervalSince1970
        if (now - timestamp) < Self.dismissalRetentionPeriod {
            return true
        } else {
            // Expired after 21 days: silently prune and allow track to reappear in recommendations
            dismissedTimestamps.removeValue(forKey: bvid)
            saveDismissedTimestamps()
            return false
        }
    }
    
    // MARK: - HTML Tag Cleaning
    
    /// Strips HTML tags (e.g., <em class="keyword">, </em>) and decodes standard HTML entities
    nonisolated public static func cleanHTMLTags(from text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&apos;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Recommendation Generation
    
    private struct SeedCandidate: Sendable {
        let bvid: String
        let songTitle: String
    }
    
    /// Generates recommended tracks based on active versions across all songs in the playlist.
    @discardableResult
    public func fetchRecommendations(for playlist: Playlist, limit: Int = 12) async -> [RecommendedTrack] {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        // 1. Extract all active versions across all songs in the playlist
        var activeCandidates: [SeedCandidate] = []
        for song in playlist.songs {
            let enabledVersions = song.versions.filter { $0.isEnabled }
            let versionsToUse = enabledVersions.isEmpty ? song.versions : enabledVersions
            for version in versionsToUse {
                activeCandidates.append(SeedCandidate(bvid: version.bvid, songTitle: song.title))
            }
        }
        
        guard !activeCandidates.isEmpty else {
            self.recommendations = []
            return []
        }
        
        // 2. Sample 2-3 random versions as seeds. If fewer than 2 exist, use whatever is available.
        let seedCount = min(activeCandidates.count, activeCandidates.count < 2 ? activeCandidates.count : Int.random(in: 2...3))
        let sampledSeeds = Array(activeCandidates.shuffled().prefix(seedCount))
        
        // 3 & 4. Parallel fetching: Query the seeds concurrently using async/await TaskGroup
        let session = self.session
        let resultsBySeed: [[RecommendedTrack]] = await withTaskGroup(of: [RecommendedTrack].self) { group in
            for seed in sampledSeeds {
                group.addTask {
                    await Self.fetchRelatedVideos(seed: seed, session: session)
                }
            }
            
            var collected: [[RecommendedTrack]] = []
            for await tracks in group {
                if !tracks.isEmpty {
                    collected.append(tracks)
                }
            }
            return collected
        }
        
        // 5. Pooling & Filtering:
        // - Interleave results round-robin from each seed query
        var interleaved: [RecommendedTrack] = []
        var maxCount = 0
        for list in resultsBySeed {
            if list.count > maxCount { maxCount = list.count }
        }
        for i in 0..<maxCount {
            for list in resultsBySeed {
                if i < list.count {
                    interleaved.append(list[i])
                }
            }
        }
        
        // Collect all existing BV IDs in the playlist
        var existingPlaylistBvIds = Set<String>()
        for song in playlist.songs {
            for version in song.versions {
                existingPlaylistBvIds.insert(version.bvid)
            }
        }
        
        // - Deduplicate across queries
        // - Filter out any BV ID that already exists in any version of any song in the playlist
        // - Maintain an in-memory dismissed set so dismissed or already-added songs are filtered out
        var seenBvIds = Set<String>()
        var finalTracks: [RecommendedTrack] = []
        
        for track in interleaved {
            let bvid = track.bvid
            if seenBvIds.contains(bvid) { continue }
            if existingPlaylistBvIds.contains(bvid) { continue }
            if isDismissed(bvid: bvid) { continue }
            
            seenBvIds.insert(bvid)
            finalTracks.append(track)
            
            if finalTracks.count >= limit {
                break
            }
        }
        
        self.recommendations = finalTracks
        return finalTracks
    }
    
    // MARK: - Bilibili Related Videos API Fetcher
    
    private nonisolated static func fetchRelatedVideos(
        seed: SeedCandidate,
        session: URLSession
    ) async -> [RecommendedTrack] {
        guard let url = URL(string: "https://api.bilibili.com/x/web-interface/archive/related?bvid=\(seed.bvid)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        // NOTE: Strictly no Cookie header is set to keep recommendations cookie-free
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let code = json["code"] as? Int, code == 0,
                  let list = json["data"] as? [[String: Any]] else {
                return []
            }
            
            var tracks: [RecommendedTrack] = []
            for item in list {
                guard let bvid = item["bvid"] as? String, !bvid.isEmpty else {
                    continue
                }
                
                let rawTitle = item["title"] as? String ?? ""
                let cleanTitle = cleanHTMLTags(from: rawTitle)
                guard !cleanTitle.isEmpty else { continue }
                
                var pic = item["pic"] as? String ?? ""
                if pic.hasPrefix("http://") {
                    pic = pic.replacingOccurrences(of: "http://", with: "https://")
                }
                
                let duration: TimeInterval
                if let dur = item["duration"] as? TimeInterval {
                    duration = dur
                } else if let durInt = item["duration"] as? Int {
                    duration = TimeInterval(durInt)
                } else {
                    duration = 0
                }
                
                var uploaderName = "Bilibili Artist"
                if let owner = item["owner"] as? [String: Any],
                   let name = owner["name"] as? String, !name.isEmpty {
                    uploaderName = name
                }
                
                let track = RecommendedTrack(
                    bvid: bvid,
                    title: cleanTitle,
                    uploader: uploaderName,
                    coverUrl: pic,
                    duration: duration,
                    seedBvId: seed.bvid,
                    seedTitle: seed.songTitle
                )
                tracks.append(track)
            }
            
            return tracks
        } catch {
            return []
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Dismisses a track so it is no longer recommended for the 21-day window
    public func dismissTrack(bvid: String) {
        dismissedTimestamps[bvid] = Date().timeIntervalSince1970
        saveDismissedTimestamps()
        recommendations.removeAll { $0.bvid == bvid }
    }
    
    /// Dismisses a recommended track object
    public func dismissTrack(_ track: RecommendedTrack) {
        dismissTrack(bvid: track.bvid)
    }
    
    /// Clears all dismissed records
    public func clearDismissed() {
        dismissedTimestamps.removeAll()
        saveDismissedTimestamps()
    }
    
    /// Convenience method: Adds a recommended track as a brand new Song in the designated playlist
    @discardableResult
    public func addTrackAsNewSong(track: RecommendedTrack, to playlistId: UUID) -> Bool {
        guard let index = PlaylistStorageManager.shared.playlists.firstIndex(where: { $0.id == playlistId }) else {
            return false
        }
        
        var playlist = PlaylistStorageManager.shared.playlists[index]
        
        let version = SongVersion(
            name: track.title,
            bvid: track.bvid,
            uploader: track.uploader,
            duration: track.duration,
            audioQuality: "192kbps DASH",
            picUrl: track.coverUrl
        )
        
        let newSong = Song(
            title: track.title,
            artist: track.uploader,
            artworkUrl: track.coverUrl,
            versions: [version]
        )
        
        playlist.songs.append(newSong)
        playlist.updatedAt = Date()
        PlaylistStorageManager.shared.playlists[index] = playlist
        
        dismissTrack(bvid: track.bvid)
        return true
    }
    
    /// Convenience method: Adds a recommended track as an alternative version to an existing Song
    @discardableResult
    public func addTrackAsVersion(track: RecommendedTrack, to songId: UUID, in playlistId: UUID) -> Bool {
        guard let playlistIndex = PlaylistStorageManager.shared.playlists.firstIndex(where: { $0.id == playlistId }) else {
            return false
        }
        
        var playlist = PlaylistStorageManager.shared.playlists[playlistIndex]
        guard let songIndex = playlist.songs.firstIndex(where: { $0.id == songId }) else {
            return false
        }
        
        var song = playlist.songs[songIndex]
        let version = SongVersion(
            name: track.title,
            bvid: track.bvid,
            uploader: track.uploader,
            duration: track.duration,
            audioQuality: "192kbps DASH",
            picUrl: track.coverUrl,
            isEnabled: true,
            weight: 1.0
        )
        
        song.addVersion(version)
        playlist.songs[songIndex] = song
        playlist.updatedAt = Date()
        PlaylistStorageManager.shared.playlists[playlistIndex] = playlist
        
        dismissTrack(bvid: track.bvid)
        return true
    }
}
