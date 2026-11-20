import SwiftUI

/// Detailed view of a playlist with sequential play, session shuffle, and multi-version management
@MainActor
public struct PlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let playlistId: UUID
    @ObservedObject var playerManager: AudioPlayerManager
    @ObservedObject private var storageManager = PlaylistStorageManager.shared
    
    @State private var selectedSongForVersionManager: Song?
    @State private var showingAddSongSheet: Bool = false
    @State private var showingSessionHistory: Bool = false
    @State private var showingSettings: Bool = false
    @State private var searchText: String = ""
    
    @State private var recommendedTracks: [RecommendedTrack] = []
    @State private var isLoadingRecommendations: Bool = false
    @State private var selectedTrackForVersionSheet: RecommendedTrack? = nil
    
    public init(
        playlistId: UUID,
        playerManager: AudioPlayerManager = .shared
    ) {
        self.playlistId = playlistId
        self.playerManager = playerManager
    }
    
    // Backwards-compatible init accepting Binding
    public init(
        playlist: Binding<Playlist>,
        playlists: Binding<[Playlist]>? = nil,
        playerManager: AudioPlayerManager = .shared
    ) {
        self.playlistId = playlist.wrappedValue.id
        self.playerManager = playerManager
    }
    
    private var playlist: Playlist? {
        storageManager.playlists.first(where: { $0.id == playlistId })
    }
    
    private var playlistBinding: Binding<Playlist>? {
        guard let index = storageManager.playlists.firstIndex(where: { $0.id == playlistId }) else {
            return nil
        }
        return $storageManager.playlists[index]
    }
    
    public var body: some View {
        Group {
            if let playlist = playlist, let boundPlaylist = playlistBinding {
                contentList(playlist: playlist, boundPlaylist: boundPlaylist)
            } else {
                Text("Playlist not found")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func contentList(playlist: Playlist, boundPlaylist: Binding<Playlist>) -> some View {
        List {
            headerSection(playlist)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            actionButtonsSection(playlist)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            sessionStatusBanner(playlist)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            songsSection(playlist: playlist)
            
            recommendationsSection(playlist: playlist)
        }
        .listStyle(.insetGrouped)
        .safeAreaPadding(.bottom, playerManager.currentSong != nil ? 80 : 0)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search songs, artists, or versions..."
        )
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSongSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    Button(action: { showingSessionHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .sheet(item: $selectedSongForVersionManager) { song in
            versionManagerSheet(for: song)
        }
        .sheet(item: $selectedTrackForVersionSheet) { track in
            AddAsVersionSheet(
                recommendedTrack: track,
                playlist: playlist,
                onDismiss: {
                    if BiliRecommendationService.shared.dismissedBvIds.contains(track.bvid) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            recommendedTracks.removeAll { $0.bvid == track.bvid }
                        }
                    }
                    selectedTrackForVersionSheet = nil
                }
            )
        }
        .sheet(isPresented: $showingAddSongSheet) {
            AddSongSheet(playlist: boundPlaylist)
        }
        .sheet(isPresented: $showingSessionHistory) {
            SessionHistoryView(playerManager: playerManager)
        }
        .task(id: playlistId) {
            await loadRecommendations(for: playlist)
        }
        .navigationDestination(isPresented: $showingSettings) {
            PlaylistSettingsView(
                playlistId: playlistId,
                playlistName: playlist.name,
                onDelete: {
                    storageManager.removePlaylist(id: playlistId)
                    dismiss()
                }
            )
        }
    }
    
    private func filteredSongs(in playlist: Playlist) -> [Song] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return playlist.songs }
        
        return playlist.songs.filter { song in
            if song.title.lowercased().contains(query) { return true }
            if song.artist.lowercased().contains(query) { return true }
            if let album = song.album, album.lowercased().contains(query) { return true }
            if song.versions.contains(where: {
                $0.name.lowercased().contains(query) ||
                $0.bvid.lowercased().contains(query) ||
                $0.uploader.lowercased().contains(query)
            }) {
                return true
            }
            return false
        }
    }
    
    private func effectivePlaylist(from playlist: Playlist) -> Playlist {
        let songs = filteredSongs(in: playlist)
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return playlist }
        return Playlist(
            id: playlist.id,
            name: "\(playlist.name) (Filtered)",
            description: playlist.description,
            coverUrl: playlist.coverUrl,
            songs: songs
        )
    }
    
    @ViewBuilder
    private func songsSection(playlist: Playlist) -> some View {
        let songs = filteredSongs(in: playlist)
        Section {
            if playlist.songs.isEmpty {
                emptySongsView
            } else if songs.isEmpty {
                emptySearchResultsView
            } else {
                ForEach(songs) { song in
                    songRow(song, in: playlist)
                }
                .onDelete { indexSet in
                    if let index = storageManager.playlists.firstIndex(where: { $0.id == playlistId }) {
                        let songsToDelete = indexSet.map { songs[$0] }
                        storageManager.playlists[index].songs.removeAll { s in
                            songsToDelete.contains(where: { $0.id == s.id })
                        }
                        PlaylistStorageManager.shared.savePlaylists()
                    }
                }
            }
        } header: {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Songs (\(playlist.songs.count))")
            } else {
                Text("Matching Songs (\(songs.count) of \(playlist.songs.count))")
            }
        }
    }
    
    @ViewBuilder
    private func recommendationsSection(playlist: Playlist) -> some View {
        Section {
            if isLoadingRecommendations && recommendedTracks.isEmpty {
                HStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding recommendations...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if recommendedTracks.isEmpty {
                HStack {
                    Spacer()
                    Text("No recommendations available.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(recommendedTracks) { track in
                    recommendationRow(track, in: playlist)
                }
            }
        } header: {
            recommendationsHeader(playlist: playlist)
        } footer: {
            playlistSettingsFooter(playlistName: playlist.name)
        }
    }
    
    private func recommendationsHeader(playlist: Playlist) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.pink)
                Text("Recommended for You")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .textCase(nil)
            
            Spacer()
            
            Button(action: {
                Task {
                    await loadRecommendations(for: playlist)
                }
            }) {
                HStack(spacing: 4) {
                    if isLoadingRecommendations {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Refresh")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.pink)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingRecommendations)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private func recommendationRow(_ track: RecommendedTrack, in playlist: Playlist) -> some View {
        HStack(spacing: 12) {
            CachedThumbnailView(urlString: track.coverUrl, targetSize: CGSize(width: 50, height: 50)) {
                ZStack {
                    Color.secondary.opacity(0.15)
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 5) {
                    Text(track.uploader)
                        .lineLimit(1)
                    Text("•")
                    Text(track.formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    addTrackToPlaylist(track, in: playlist)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.pink)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add to Playlist")
                
                Button(action: {
                    selectedTrackForVersionSheet = track
                }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add as Version")
            }
        }
        .padding(.vertical, 2)
    }
    
    private func addTrackToPlaylist(_ track: RecommendedTrack, in playlist: Playlist) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        _ = BiliRecommendationService.shared.addTrackAsNewSong(track: track, to: playlist.id)
        withAnimation(.easeInOut(duration: 0.25)) {
            recommendedTracks.removeAll { $0.bvid == track.bvid }
        }
    }
    
    private func loadRecommendations(for playlist: Playlist) async {
        guard !isLoadingRecommendations else { return }
        isLoadingRecommendations = true
        let tracks = await BiliRecommendationService.shared.fetchRecommendations(for: playlist)
        self.recommendedTracks = tracks
        self.isLoadingRecommendations = false
    }
    
    private var emptySearchResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No results for \"\(searchText)\"")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Try searching by song title, artist, version name, or BV ID.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Clear Search") {
                searchText = ""
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.pink)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }
    
    private var emptySongsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No songs in this playlist yet.")
                .foregroundColor(.secondary)
            Button("Add Song from Bilibili") {
                showingAddSongSheet = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private func songRow(_ song: Song, in playlist: Playlist) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id
        return SongRowView(
            song: song,
            isPlayingCurrent: isCurrent && playerManager.isPlaying,
            activeVersionName: isCurrent ? playerManager.currentVersion?.name : nil,
            onSelect: {
                if isCurrent {
                    if !playerManager.isPlaying {
                        playerManager.play()
                    }
                    playerManager.openFullScreenPlayer()
                } else {
                    playerManager.play(
                        song: song,
                        in: playlist,
                        resetSession: playerManager.currentPlaylist?.id != playlist.id
                    )
                }
            },
            onManageVersions: {
                selectedSongForVersionManager = song
            }
        )
    }
    
    private func playlistSettingsFooter(playlistName: String) -> some View {
        Button(action: {
            showingSettings = true
        }) {
            Text("playlist settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            showingSettings = true
        })
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
    
    @ViewBuilder
    private func versionManagerSheet(for song: Song) -> some View {
        if let pIndex = storageManager.playlists.firstIndex(where: { $0.id == playlistId }),
           let songIndex = storageManager.playlists[pIndex].songs.firstIndex(where: { $0.id == song.id }) {
            VersionManagerSheet(
                song: $storageManager.playlists[pIndex].songs[songIndex],
                playlist: storageManager.playlists[pIndex],
                playerManager: playerManager
            )
        }
    }
    
    // MARK: - Subviews
    
    private func headerSection(_ playlist: Playlist) -> some View {
        VStack(spacing: 12) {
            ZStack {
                CachedThumbnailView(urlString: playlist.coverUrl, targetSize: CGSize(width: 160, height: 160)) {
                    defaultCover
                }
            }
            .frame(width: 160, height: 160)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 4) {
                Text(playlist.name)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                
                if !playlist.description.isEmpty {
                    Text(playlist.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                HStack(spacing: 8) {
                    Text("\(playlist.songs.count) tracks")
                    Text("•")
                    Text(playlist.formattedDuration)
                    Text("•")
                    HStack(spacing: 3) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 9))
                        Text("\(playlist.totalVersionsCount) versions")
                    }
                    .foregroundColor(.pink)
                }
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private var defaultCover: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // Feature 2: Play consecutive & Shuffle actions with V1-Only Shuffle
    private func actionButtonsSection(_ playlist: Playlist) -> some View {
        let activePlaylist = effectivePlaylist(from: playlist)
        return HStack(spacing: 8) {
            // Consecutive Normal Play with fresh, isolated session
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                playerManager.startPlaylistConsecutive(activePlaylist)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Consecutive")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Session Shuffle (random versions) with fresh, isolated session guarantee
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                playerManager.playDefaultVersionOnly = false
                playerManager.startPlaylistShuffle(activePlaylist)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.12))
                .foregroundColor(.pink)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.pink.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Compact V1-Only Shuffle Button to the right of the 2 play buttons
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                playerManager.playDefaultVersionOnly = true
                playerManager.startPlaylistShuffle(activePlaylist)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13, weight: .bold))
                    Text("V1")
                        .font(.system(size: 12, weight: .heavy))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(playerManager.playDefaultVersionOnly ? Color.pink.opacity(0.25) : Color.white.opacity(0.12))
                .foregroundColor(.pink)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.pink.opacity(playerManager.playDefaultVersionOnly ? 0.8 : 0.4), lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shuffle playlist using Version 1 only")
        }
        .padding(.vertical, 4)
    }
    
    // Feature 3 & Bug 1: Session progress badge
    private func sessionStatusBanner(_ playlist: Playlist) -> some View {
        Button(action: { showingSessionHistory = true }) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkerboard")
                    .foregroundColor(.cyan)
                    .font(.subheadline)
                
                let isCurrentPlaylist = playerManager.currentPlaylist?.id == playlist.id
                let playedInSession = isCurrentPlaylist ? playerManager.currentSession.playedSongIds.count : 0
                
                if isCurrentPlaylist {
                    Text("Session: \(playedInSession)/\(playlist.songs.count) played • Non-repeating guarantee")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("Session: Ready • Start play or shuffle to create isolated session")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
