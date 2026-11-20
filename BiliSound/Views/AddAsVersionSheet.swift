import SwiftUI

/// Sheet allowing users to add a recommended Bilibili video as an alternate version of an existing song in the playlist.
@MainActor
public struct AddAsVersionSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let recommendedTrack: RecommendedTrack
    public let playlist: Playlist
    public var onDismiss: () -> Void
    
    @State private var searchText: String = ""
    
    public init(
        recommendedTrack: RecommendedTrack,
        playlist: Playlist,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.recommendedTrack = recommendedTrack
        self.playlist = playlist
        self.onDismiss = onDismiss
    }
    
    private var currentPlaylistSongs: [Song] {
        PlaylistStorageManager.shared.playlists.first(where: { $0.id == playlist.id })?.songs ?? playlist.songs
    }
    
    private var filteredSongs: [Song] {
        let songs = currentPlaylistSongs
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return songs }
        return songs.filter { song in
            song.title.lowercased().contains(query) || song.artist.lowercased().contains(query)
        }
    }
    
    public var body: some View {
        NavigationStack {
            List {
                trackPreviewSection
                
                songsListSection
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by title or artist..."
            )
            .navigationTitle("Add as Version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var trackPreviewSection: some View {
        Section {
            HStack(spacing: 12) {
                CachedThumbnailView(urlString: recommendedTrack.coverUrl, targetSize: CGSize(width: 52, height: 52)) {
                    defaultSongCover
                }
                .frame(width: 52, height: 52)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendedTrack.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text(recommendedTrack.uploader)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(recommendedTrack.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Recommendation to Add")
        } footer: {
            Text("Select an existing song below to map this video as an alternative audio version.")
        }
    }
    
    private var songsListSection: some View {
        Section(header: Text("Songs in \(playlist.name) (\(filteredSongs.count))")) {
            if currentPlaylistSongs.isEmpty {
                VStack(spacing: 6) {
                    Text("This playlist has no songs yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else if filteredSongs.isEmpty {
                VStack(spacing: 6) {
                    Text("No songs match \"\(searchText)\".")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                ForEach(filteredSongs) { song in
                    songSelectionRow(for: song)
                }
            }
        }
    }
    
    private func songSelectionRow(for song: Song) -> some View {
        Button(action: {
            addTrackAsVersion(to: song)
        }) {
            HStack(spacing: 12) {
                CachedThumbnailView(
                    urlString: song.artworkUrl ?? song.versions.first?.picUrl,
                    targetSize: CGSize(width: 46, height: 46)
                ) {
                    defaultSongCover
                }
                .frame(width: 46, height: 46)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 10))
                        Text("\(song.versions.count) version\(song.versions.count == 1 ? "" : "s")")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(.pink)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .foregroundColor(.pink)
                    .font(.system(size: 20))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func addTrackAsVersion(to targetSong: Song) {
        // Direct addition & persistence
        if let playlistIndex = PlaylistStorageManager.shared.playlists.firstIndex(where: { $0.id == playlist.id }),
           let songIndex = PlaylistStorageManager.shared.playlists[playlistIndex].songs.firstIndex(where: { $0.id == targetSong.id }) {
            let newVersion = SongVersion(
                name: recommendedTrack.title,
                bvid: recommendedTrack.bvid,
                uploader: recommendedTrack.uploader,
                duration: recommendedTrack.duration,
                audioQuality: "192kbps DASH",
                picUrl: recommendedTrack.coverUrl,
                isEnabled: true,
                weight: 1.0
            )
            PlaylistStorageManager.shared.playlists[playlistIndex].songs[songIndex].addVersion(newVersion)
            PlaylistStorageManager.shared.playlists[playlistIndex].updatedAt = Date()
            PlaylistStorageManager.shared.savePlaylists()
        }
        
        // Also ensure service knows this track is used/dismissed
        BiliRecommendationService.shared.dismissTrack(bvid: recommendedTrack.bvid)
        
        // Success haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Dismiss sheet
        onDismiss()
        dismiss()
    }
    
    private var defaultSongCover: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.6), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
