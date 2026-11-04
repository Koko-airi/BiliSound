import SwiftUI

/// Clean and robust page for Playlist Settings pushed onto NavigationStack.
/// Contains playlist settings and a delete button.
@MainActor
public struct PlaylistSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    let playlistName: String
    let onDelete: () -> Void
    
    @State private var showingConfirmation: Bool = false
    
    public init(playlistName: String, onDelete: @escaping () -> Void) {
        self.playlistName = playlistName
        self.onDelete = onDelete
    }
    
    public var body: some View {
        List {
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
    }
}
