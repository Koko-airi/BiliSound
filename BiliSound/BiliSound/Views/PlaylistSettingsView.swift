import SwiftUI

/// Clean and robust page for Playlist Settings pushed onto NavigationStack.
/// Contains import functionality (merging non-duplicate songs) and safe deletion.
@MainActor
public struct PlaylistSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accountManager = BiliAccountManager.shared
    
    let playlistId: UUID
    let playlistName: String
    let onDelete: () -> Void
    
    @State private var showingConfirmation: Bool = false
    @State private var showingImportSheet: Bool = false
    @State private var showingLoginSheet: Bool = false
    @State private var importAlertMessage: String? = nil
    
    public init(
        playlistId: UUID,
        playlistName: String,
        onDelete: @escaping () -> Void
    ) {
        self.playlistId = playlistId
        self.playlistName = playlistName
        self.onDelete = onDelete
    }
    
    // Backwards-compatible init
    public init(playlistName: String, onDelete: @escaping () -> Void) {
        self.playlistId = UUID()
        self.playlistName = playlistName
        self.onDelete = onDelete
    }
    
    public var body: some View {
        List {
            // Import section: adds songs to this playlist that are not already present
            Section(
                header: Text("Import"),
                footer: Text("Import songs from your Bilibili favorites into \"\(playlistName)\". Songs that already exist in this playlist will be skipped automatically.")
            ) {
                Button(action: {
                    if accountManager.isLoggedIn {
                        showingImportSheet = true
                    } else {
                        showingLoginSheet = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.pink)
                            .font(.body)
                        
                        Text("Import from Bilibili")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Delete playlist section
            Section {
                Button(role: .destructive, action: {
                    showingConfirmation = true
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
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \"\(playlistName)\"", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this playlist? This action cannot be undone.")
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportBiliPlaylistSheet(targetPlaylistId: playlistId) { added, skipped in
                if added > 0 || skipped > 0 {
                    importAlertMessage = "Import finished: \(added) added, \(skipped) already existed (skipped)."
                }
            }
        }
        .sheet(isPresented: $showingLoginSheet) {
            BilibiliLoginSheet()
        }
        .alert(
            "Import Result",
            isPresented: Binding(
                get: { importAlertMessage != nil },
                set: { if !$0 { importAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                importAlertMessage = nil
            }
        } message: {
            Text(importAlertMessage ?? "")
        }
    }
}
