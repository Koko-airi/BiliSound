import SwiftUI

/// Sheet displaying the user's Bilibili favorite folders (both created and collected),
/// allowing the user to select and import them directly into their BiliSound library.
@MainActor
public struct ImportBiliPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountManager = BiliAccountManager.shared
    
    @Binding var playlists: [Playlist]
    
    @State private var createdFolders: [BiliFavFolder] = []
    @State private var collectedFolders: [BiliFavFolder] = []
    @State private var selectedTab: Int = 0 // 0: Created, 1: Collected
    
    @State private var isLoadingFolders: Bool = false
    @State private var errorMessage: String? = nil
    
    // Import progress state
    @State private var importingFolderId: Int? = nil
    @State private var importProgressText: String = ""
    @State private var successfullyImportedTitles: Set<String> = []
    
    public init(playlists: Binding<[Playlist]>) {
        self._playlists = playlists
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !accountManager.isLoggedIn {
                    notLoggedInState
                } else {
                    folderTypePicker
                    
                    if isLoadingFolders && createdFolders.isEmpty && collectedFolders.isEmpty {
                        loadingState
                    } else if let error = errorMessage, createdFolders.isEmpty && collectedFolders.isEmpty {
                        errorState(error)
                    } else {
                        foldersList
                    }
                }
            }
            .navigationTitle("Import from Bilibili")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if accountManager.isLoggedIn {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            Task {
                                await loadAllFolders()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoadingFolders)
                    }
                }
            }
            .task {
                if accountManager.isLoggedIn {
                    await loadAllFolders()
                }
            }
        }
    }
    
    // MARK: - Picker
    
    private var folderTypePicker: some View {
        Picker("Folder Category", selection: $selectedTab) {
            Text("My Favorites (\(createdFolders.count))").tag(0)
            Text("Subscribed (\(collectedFolders.count))").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Lists
    
    private var activeFolders: [BiliFavFolder] {
        selectedTab == 0 ? createdFolders : collectedFolders
    }
    
    private var foldersList: some View {
        List {
            if activeFolders.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: selectedTab == 0 ? "folder.badge.minus" : "star.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text(selectedTab == 0 ? "No created favorite folders found." : "No subscribed folders found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
                }
            } else {
                Section(header: Text(selectedTab == 0 ? "Created Folders (我的收藏)" : "Subscribed Folders (订阅的收藏)")) {
                    ForEach(activeFolders) { folder in
                        folderRow(folder)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func folderRow(_ folder: BiliFavFolder) -> some View {
        HStack(spacing: 12) {
            // Folder Cover
            ZStack {
                if let coverStr = folder.coverUrl, let url = URL(string: coverStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Color.pink.opacity(0.15)
                        }
                    }
                } else {
                    Color.pink.opacity(0.15)
                }
                
                Image(systemName: "music.note.list")
                    .foregroundColor(.pink.opacity(0.6))
                    .font(.caption)
            }
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(folder.mediaCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let intro = folder.intro, !intro.isEmpty {
                        Text("• \(intro)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Import Button / Status
            if successfullyImportedTitles.contains(folder.title) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Imported")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                }
            } else if importingFolderId == folder.id {
                VStack(spacing: 2) {
                    ProgressView()
                        .scaleEffect(0.8)
                    if !importProgressText.isEmpty {
                        Text(importProgressText)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Button(action: {
                    Task {
                        await importFolder(folder)
                    }
                }) {
                    Text("Import")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .disabled(importingFolderId != nil)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Loading / Error / Not Logged In States
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Loading your Bilibili playlists...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await loadAllFolders()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notLoggedInState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.pink)
            
            Text("Login Required")
                .font(.title3.weight(.bold))
            
            Text("Please log in to your Bilibili account in the Account & Settings tab to view and import your personal favorites.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadAllFolders() async {
        guard let mid = accountManager.mid else {
            errorMessage = "No Bilibili user ID found. Please log in first."
            return
        }
        
        isLoadingFolders = true
        errorMessage = nil
        
        do {
            async let createdTask = BilibiliAPIService.shared.fetchCreatedFavoriteFolders(mid: mid)
            async let collectedTask = BilibiliAPIService.shared.fetchCollectedFavoriteFolders(mid: mid)
            
            let (created, collected) = try await (createdTask, collectedTask)
            self.createdFolders = created
            self.collectedFolders = collected
            self.isLoadingFolders = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoadingFolders = false
        }
    }
    
    private func importFolder(_ folder: BiliFavFolder) async {
        importingFolderId = folder.id
        importProgressText = "Fetching..."
        
        do {
            let playlist = try await BilibiliAPIService.shared.importFolderAsPlaylist(
                folder: folder,
                maxItems: 100,
                progressHandler: { loaded, total in
                    Task { @MainActor in
                        self.importProgressText = "\(loaded)/\(total)"
                    }
                }
            )
            
            // Append to playlists
            playlists.append(playlist)
            successfullyImportedTitles.insert(folder.title)
            importingFolderId = nil
            importProgressText = ""
        } catch {
            importingFolderId = nil
            importProgressText = ""
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
