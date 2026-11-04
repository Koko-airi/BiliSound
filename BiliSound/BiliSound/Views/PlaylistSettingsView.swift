import SwiftUI

/// Dedicated page for managing a specific playlist's settings,
/// including metadata review, importing songs from Bilibili favorites, and safe deletion.
@MainActor
public struct PlaylistSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storageManager = PlaylistStorageManager.shared
    @ObservedObject private var accountManager = BiliAccountManager.shared
    
    @Binding var playlist: Playlist
    var onPlaylistDeleted: (() -> Void)? = nil
    
    @State private var showingImportSheet: Bool = false
    @State private var showingLoginSheet: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var importResultAlertMessage: String? = nil
    
    public init(
        playlist: Binding<Playlist>,
        onPlaylistDeleted: (() -> Void)? = nil
    ) {
        self._playlist = playlist
        self.onPlaylistDeleted = onPlaylistDeleted
    }
    
    public var body: some View {
        List {
            // Section 1: Overview
            Section(header: Text("Playlist Information")) {
                HStack {
                    Text("Title")
                    Spacer()
                    Text(playlist.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Tracks")
                    Spacer()
                    Text("\(playlist.songs.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Multi-Versions")
                    Spacer()
                    Text("\(playlist.totalVersionsCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Estimated Duration")
                    Spacer()
                    Text(playlist.formattedDuration)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Created")
                    Spacer()
                    Text(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
            }
            
            // Section 2: Import Songs
            Section(
                header: Text("Import"),
                footer: Text("Importing will fetch songs from your selected Bilibili favorite folder into \"\(playlist.name)\". Any songs or versions already in this playlist will be skipped.")
            ) {
                Button(action: {
                    if accountManager.isLoggedIn {
                        showingImportSheet = true
                    } else {
                        showingLoginSheet = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .foregroundColor(.pink)
                            .font(.body)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from Bilibili (导入到此歌单)")
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            Text("Merge songs from your Bilibili account")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Section 3: Safe Deletion
            Section(
                header: Text("Danger Zone"),
                footer: Text("Deleting a playlist will remove its local saved copy and multi-version configurations. This cannot be undone.")
            ) {
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Delete Playlist")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Playlist Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Playlist",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \"\(playlist.name)\"", role: .destructive) {
                deletePlaylist()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(playlist.name)\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportBiliPlaylistSheet(targetPlaylistId: playlist.id) { added, skipped in
                // Reload binding from updated storage
                if let updated = storageManager.playlists.first(where: { $0.id == playlist.id }) {
                    playlist = updated
                }
                if added > 0 || skipped > 0 {
                    importResultAlertMessage = "Import finished: \(added) added, \(skipped) already existed (skipped)."
                }
            }
        }
        .sheet(isPresented: $showingLoginSheet) {
            BilibiliLoginSheet()
        }
        .alert(
            "Import Result",
            isPresented: Binding(
                get: { importResultAlertMessage != nil },
                set: { if !$0 { importResultAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                importResultAlertMessage = nil
            }
        } message: {
            if let msg = importResultAlertMessage {
                Text(msg)
            }
        }
    }
    
    private func deletePlaylist() {
        storageManager.removePlaylist(id: playlist.id)
        onPlaylistDeleted?()
        dismiss()
    }
}
