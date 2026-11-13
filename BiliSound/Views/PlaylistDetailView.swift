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
        }
        .listStyle(.insetGrouped)
        .safeAreaPadding(.bottom, playerManager.currentSong != nil ? 80 : 0)
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
        .sheet(isPresented: $showingAddSongSheet) {
            AddSongSheet(playlist: boundPlaylist)
        }
        .sheet(isPresented: $showingSessionHistory) {
            SessionHistoryView(playerManager: playerManager)
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
    
    @ViewBuilder
    private func songsSection(playlist: Playlist) -> some View {
        Section {
            if playlist.songs.isEmpty {
                emptySongsView
            } else {
                ForEach(playlist.songs) { song in
                    songRow(song, in: playlist)
                }
                .onDelete { indexSet in
                    if let index = storageManager.playlists.firstIndex(where: { $0.id == playlistId }) {
                        storageManager.playlists[index].songs.remove(atOffsets: indexSet)
                    }
                }
            }
        } header: {
            Text("Songs (\(playlist.songs.count))")
        } footer: {
            playlistSettingsFooter(playlistName: playlist.name)
        }
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
                playerManager.play(
                    song: song,
                    in: playlist,
                    resetSession: playerManager.currentPlaylist?.id != playlist.id
                )
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
                if let coverStr = playlist.coverUrl, let url = URL(string: coverStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            defaultCover
                        }
                    }
                } else {
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
        HStack(spacing: 8) {
            // Consecutive Normal Play with fresh, isolated session
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                playerManager.startPlaylistConsecutive(playlist)
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
                playerManager.startPlaylistShuffle(playlist)
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
                playerManager.startPlaylistShuffle(playlist)
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
