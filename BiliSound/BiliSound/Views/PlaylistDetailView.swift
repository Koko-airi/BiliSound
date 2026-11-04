import SwiftUI

/// Detailed view of a playlist with sequential play, session shuffle, and multi-version management
@MainActor
public struct PlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var playlist: Playlist
    var playlists: Binding<[Playlist]>?
    @ObservedObject var playerManager: AudioPlayerManager
    @ObservedObject private var storageManager = PlaylistStorageManager.shared
    
    @State private var selectedSongForVersionManager: Song?
    @State private var showingAddSongSheet: Bool = false
    @State private var showingSessionHistory: Bool = false
    @State private var showingPlaylistSettings: Bool = false
    
    public init(
        playlist: Binding<Playlist>,
        playlists: Binding<[Playlist]>? = nil,
        playerManager: AudioPlayerManager = .shared
    ) {
        self._playlist = playlist
        self.playlists = playlists
        self.playerManager = playerManager
    }
    
    public var body: some View {
        List {
            // Header Section
            headerSection
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            // Feature 2 & 3: Playback Mode Action Bar
            actionButtonsSection
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            // Feature 3: Live Session Status Banner
            sessionStatusBanner
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            // Songs List
            Section(header: Text("Songs (\(playlist.songs.count))")) {
                if playlist.songs.isEmpty {
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
                } else {
                    ForEach(playlist.songs) { song in
                        let isCurrent = playerManager.currentSong?.id == song.id
                        SongRowView(
                            song: song,
                            isPlayingCurrent: isCurrent && playerManager.isPlaying,
                            activeVersionName: isCurrent ? playerManager.currentVersion?.name : nil,
                            onSelect: {
                                // Bug 1: Fresh session if switching playlists, then picks random version
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
                    .onDelete { indexSet in
                        playlist.songs.remove(atOffsets: indexSet)
                        // Trigger persistence for updated songs
                        if let index = storageManager.playlists.firstIndex(where: { $0.id == playlist.id }) {
                            storageManager.playlists[index] = playlist
                        }
                    }
                }
            }
            
            // Link to dedicated Playlist Settings page
            Section {
                NavigationLink(destination: PlaylistSettingsView(
                    playlist: $playlist,
                    onPlaylistDeleted: {
                        dismiss()
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.pink)
                        Text("Playlist Settings")
                            .font(.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        // Bug 2: Bottom safe area padding prevents mini bar from occluding the last list items
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
                Button(action: { showingSessionHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(item: $selectedSongForVersionManager) { song in
            if let songIndex = playlist.songs.firstIndex(where: { $0.id == song.id }) {
                VersionManagerSheet(
                    song: $playlist.songs[songIndex],
                    playlist: playlist,
                    playerManager: playerManager
                )
                .onDisappear {
                    if let index = storageManager.playlists.firstIndex(where: { $0.id == playlist.id }) {
                        storageManager.playlists[index] = playlist
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSongSheet) {
            AddSongSheet(playlist: $playlist)
                .onDisappear {
                    if let index = storageManager.playlists.firstIndex(where: { $0.id == playlist.id }) {
                        storageManager.playlists[index] = playlist
                    }
                }
        }
        .sheet(isPresented: $showingSessionHistory) {
            SessionHistoryView(playerManager: playerManager)
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
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
    
    // Feature 2: Play consecutive & Shuffle actions
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Feature 2 & Bug 1: Consecutive Normal Play with fresh, isolated session
            Button(action: {
                playerManager.startPlaylistConsecutive(playlist)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Play Consecutive")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Feature 2, 3 & Bug 1: Shuffle Autoplay with fresh, isolated session guarantee
            Button(action: {
                playerManager.startPlaylistShuffle(playlist)
            }) {
                HStack {
                    Image(systemName: "shuffle")
                    Text("Session Shuffle")
                        .fontWeight(.semibold)
                }
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
        }
        .padding(.vertical, 4)
    }
    
    // Feature 3 & Bug 1: Session progress badge
    private var sessionStatusBanner: some View {
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
