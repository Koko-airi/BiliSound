import Foundation

/// Manages local persistence of user playlists (JSON storage in App Documents directory).
/// Automatically seeds with SampleData on first launch, and saves whenever playlists change.
@MainActor
public final class PlaylistStorageManager: ObservableObject {
    public static let shared = PlaylistStorageManager()
    
    @Published public var playlists: [Playlist] = [] {
        didSet {
            savePlaylists()
        }
    }
    
    private let fileName = "user_playlists.json"
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    private init() {
        loadPlaylists()
    }
    
    /// Loads playlists from disk; if no saved file exists, populates default sample playlists
    public func loadPlaylists() {
        let url = fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Playlist].self, from: data)
                self.playlists = decoded
                return
            } catch {
                print("Error loading playlists from \(url): \(error). Falling back to sample data.")
            }
        }
        
        // Seed default sample playlists on first launch
        self.playlists = SampleData.defaultPlaylists
        savePlaylists()
    }
    
    /// Persists playlists to disk
    public func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            print("Error saving playlists to \(fileURL): \(error)")
        }
    }
    
    /// Appends a new playlist or updates existing
    public func addPlaylist(_ playlist: Playlist) {
        playlists.append(playlist)
    }
    
    /// Removes a playlist by ID
    public func removePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
    }
    
    /// Imports songs into a target playlist, skipping any songs whose versions or BVIDs already exist
    @discardableResult
    public func importSongs(from importedPlaylist: Playlist, into targetPlaylistId: UUID) -> (addedCount: Int, skippedCount: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == targetPlaylistId }) else {
            return (0, 0)
        }
        
        var target = playlists[index]
        
        // Collect existing BVIDs and song titles (case-insensitive & trimmed)
        var existingBvids = Set<String>()
        var existingTitles = Set<String>()
        for song in target.songs {
            existingTitles.insert(song.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            for version in song.versions {
                existingBvids.insert(version.bvid)
            }
        }
        
        var addedCount = 0
        var skippedCount = 0
        
        for song in importedPlaylist.songs {
            // Check if song already exists either by title or by its version's BVID
            let songTitleNormalized = song.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let bvidMatch = song.versions.contains { existingBvids.contains($0.bvid) }
            let titleMatch = existingTitles.contains(songTitleNormalized)
            
            if bvidMatch || titleMatch {
                skippedCount += 1
            } else {
                target.songs.append(song)
                existingTitles.insert(songTitleNormalized)
                for version in song.versions {
                    existingBvids.insert(version.bvid)
                }
                addedCount += 1
            }
        }
        
        target.updatedAt = Date()
        playlists[index] = target
        return (addedCount, skippedCount)
    }
}
