import SwiftUI

/// Playlists collection screen displaying user libraries and curated Bilibili collections
@MainActor
public struct PlaylistsView: View {
    @Binding var playlists: [Playlist]
    @ObservedObject var playerManager: AudioPlayerManager
    @ObservedObject private var accountManager = BiliAccountManager.shared
    
    @State private var showingCreatePlaylist: Bool = false
    @State private var showingImportSheet: Bool = false
    @State private var showingLoginSheet: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var newPlaylistDesc: String = ""
    
    public init(playlists: Binding<[Playlist]>, playerManager: AudioPlayerManager = .shared) {
        self._playlists = playlists
        self.playerManager = playerManager
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Playlists")) {
                    ForEach($playlists) { $playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: $playlist, playerManager: playerManager)) {
                            playlistRow(playlist)
                        }
                    }
                    .onDelete { indexSet in
                        playlists.remove(atOffsets: indexSet)
                    }
                }
            }
            .listStyle(.insetGrouped)
            // Bug 2: Bottom padding prevents mini bar from occluding bottom playlist rows
            .safeAreaPadding(.bottom, playerManager.currentSong != nil ? 80 : 0)
            .navigationTitle("BiliSound")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if accountManager.isLoggedIn {
                            showingImportSheet = true
                        } else {
                            showingLoginSheet = true
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.pink)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreatePlaylist = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportBiliPlaylistSheet(playlists: $playlists)
            }
            .sheet(isPresented: $showingLoginSheet) {
                BilibiliLoginSheet()
            }
            .alert("Create New Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                TextField("Description (Optional)", text: $newPlaylistDesc)
                Button("Create", action: createPlaylist)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                    newPlaylistDesc = ""
                }
            }
        }
    }
    
    private func playlistRow(_ playlist: Playlist) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if let coverStr = playlist.coverUrl, let url = URL(string: coverStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.purple.opacity(0.3)
                        }
                    }
                } else {
                    Color.purple.opacity(0.3)
                }
            }
            .frame(width: 54, height: 54)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                
                Text("\(playlist.songs.count) songs • \(playlist.totalVersionsCount) versions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !playlist.description.isEmpty {
                    Text(playlist.description)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func createPlaylist() {
        guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newPlaylist = Playlist(
            name: newPlaylistName,
            description: newPlaylistDesc,
            coverUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80",
            songs: []
        )
        playlists.append(newPlaylist)
        newPlaylistName = ""
        newPlaylistDesc = ""
    }
}
