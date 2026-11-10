import SwiftUI

/// Sheet for importing songs or adding video versions by pasting Bilibili URLs or BV IDs.
/// Supports both single-part and multi-part (P1, P2, P3...) albums and compilations.
@MainActor
public struct AddSongSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var playlist: Playlist
    var targetSongForVersion: Song?
    
    @State private var inputUrlOrBvid: String = ""
    @State private var songTitle: String = ""
    @State private var artistName: String = ""
    @State private var versionName: String = "Original MV"
    @State private var fetchedCoverUrl: String = ""
    @State private var fetchedDuration: TimeInterval = 0
    @State private var fetchedCid: Int = 0
    
    // MARK: - Multi-Part Video State (Feature: P1, P2, P3... Import)
    @State private var detectedPages: [BiliPage] = []
    @State private var selectedPageCids: Set<Int> = []
    @State private var multiPartImportMode: MultiPartImportMode = .separateSongs
    
    public enum MultiPartImportMode: String, CaseIterable, Identifiable {
        case separateSongs = "Separate Songs"
        case multipleVersions = "Versions of 1 Song"
        
        public var id: String { rawValue }
    }
    
    @State private var isFetchingInfo: Bool = false
    @State private var errorMessage: String?
    @State private var didFetchSuccess: Bool = false
    
    public init(playlist: Binding<Playlist>, targetSongForVersion: Song? = nil) {
        self._playlist = playlist
        self.targetSongForVersion = targetSongForVersion
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Bilibili Source")) {
                    HStack {
                        TextField("Enter BV ID or Video URL", text: $inputUrlOrBvid)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: fetchMetadata) {
                            if isFetchingInfo {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Parse")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(inputUrlOrBvid.isEmpty || isFetchingInfo)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if didFetchSuccess {
                    // MARK: - Multi-Part Video Section
                    if detectedPages.count > 1 {
                        Section(header: HStack {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundColor(.pink)
                            Text("Multi-Part Video (P1–P\(detectedPages.count))")
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("This video contains \(detectedPages.count) parts (e.g. album tracks or compilation segments).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if targetSongForVersion == nil {
                                    Picker("Import Mode", selection: $multiPartImportMode) {
                                        Text("Separate Songs").tag(MultiPartImportMode.separateSongs)
                                        Text("Multiple Versions").tag(MultiPartImportMode.multipleVersions)
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.vertical, 4)
                                }
                                
                                HStack {
                                    Button("Select All") {
                                        selectedPageCids = Set(detectedPages.map(\.cid))
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption.weight(.semibold))
                                    
                                    Spacer()
                                    
                                    Text("\(selectedPageCids.count) of \(detectedPages.count) selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Deselect All") {
                                        selectedPageCids.removeAll()
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption.weight(.semibold))
                                }
                                .padding(.top, 2)
                            }
                            
                            ForEach(detectedPages) { page in
                                Button(action: {
                                    if selectedPageCids.contains(page.cid) {
                                        selectedPageCids.remove(page.cid)
                                    } else {
                                        selectedPageCids.insert(page.cid)
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedPageCids.contains(page.cid) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedPageCids.contains(page.cid) ? .pink : .secondary)
                                            .font(.title3)
                                        
                                        Text("P\(page.page)")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.pink.opacity(0.12))
                                            .foregroundColor(.pink)
                                            .cornerRadius(4)
                                        
                                        Text(page.part.isEmpty ? "Part \(page.page)" : page.part)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text(formatDuration(page.duration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // MARK: - Preview & Details Section
                    Section(header: Text("Preview & Details")) {
                        if !fetchedCoverUrl.isEmpty, let url = URL(string: fetchedCoverUrl) {
                            HStack {
                                Spacer()
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 140, height: 90)
                                .cornerRadius(8)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if targetSongForVersion == nil {
                            if detectedPages.count > 1 && multiPartImportMode == .separateSongs {
                                TextField("Album / Collection Name", text: $songTitle)
                                TextField("Artist", text: $artistName)
                                Text("Each selected part will be created as a separate track titled with its part name.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                TextField("Song Title", text: $songTitle)
                                TextField("Artist", text: $artistName)
                            }
                        } else {
                            Text("Adding version to: \(targetSongForVersion?.title ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.pink)
                        }
                        
                        if detectedPages.count <= 1 || (targetSongForVersion != nil && detectedPages.count <= 1) {
                            TextField("Version Label (e.g. Studio MV, Live 2024)", text: $versionName)
                        }
                    }
                }
                
                Section {
                    Button(action: saveSongOrVersion) {
                        HStack {
                            Spacer()
                            Text(saveButtonTitle)
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSave: Bool {
        guard didFetchSuccess else { return false }
        if detectedPages.count > 1 {
            return !selectedPageCids.isEmpty
        }
        return true
    }
    
    private var saveButtonTitle: String {
        if detectedPages.count > 1 {
            let count = selectedPageCids.count
            if targetSongForVersion != nil {
                return count == 1 ? "Attach 1 Version" : "Attach \(count) Versions"
            } else if multiPartImportMode == .separateSongs {
                return count == 1 ? "Add 1 Song to Playlist" : "Add \(count) Songs to Playlist"
            } else {
                return count == 1 ? "Add Song with 1 Version" : "Add Song with \(count) Versions"
            }
        } else {
            return targetSongForVersion == nil ? "Add Song to Playlist" : "Attach Version"
        }
    }
    
    private var navigationTitleText: String {
        if targetSongForVersion != nil {
            return "Add Song Version"
        } else if detectedPages.count > 1 {
            return "Import Multi-Part Video"
        } else {
            return "Add Bilibili Song"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Metadata Fetching
    
    private func fetchMetadata() {
        guard let parsed = BilibiliURLParser.parse(input: inputUrlOrBvid) else {
            errorMessage = "Please enter a valid Bilibili video URL or BV ID."
            return
        }
        
        isFetchingInfo = true
        errorMessage = nil
        
        Task {
            do {
                let details = try await BilibiliAPIService.shared.fetchVideoDetails(bvid: parsed.bvid, pageIndex: parsed.pageIndex)
                
                await MainActor.run {
                    self.songTitle = details.title
                    self.artistName = details.uploader
                    self.versionName = "Original MV"
                    self.fetchedCoverUrl = details.picUrl
                    self.fetchedDuration = details.duration
                    self.fetchedCid = details.cid
                    self.detectedPages = details.pages
                    // Select all detected parts by default
                    self.selectedPageCids = Set(details.pages.map(\.cid))
                    self.didFetchSuccess = true
                    self.isFetchingInfo = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingInfo = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Saving
    
    private func saveSongOrVersion() {
        guard let parsed = BilibiliURLParser.parse(input: inputUrlOrBvid) else { return }
        
        // Multi-Part Import Handling
        if detectedPages.count > 1 {
            let selectedPages = detectedPages
                .filter { selectedPageCids.contains($0.cid) }
                .sorted { $0.page < $1.page }
            
            if let targetSong = targetSongForVersion, let songIndex = playlist.songs.firstIndex(where: { $0.id == targetSong.id }) {
                // Attach each selected part as a version to the target song
                for page in selectedPages {
                    let partLabel = page.part.isEmpty ? "Part \(page.page)" : page.part
                    let newVersion = SongVersion(
                        name: partLabel,
                        bvid: parsed.bvid,
                        cid: page.cid,
                        uploader: artistName,
                        duration: page.duration > 0 ? page.duration : fetchedDuration,
                        audioQuality: "192kbps DASH",
                        picUrl: fetchedCoverUrl
                    )
                    playlist.songs[songIndex].versions.append(newVersion)
                }
            } else if multiPartImportMode == .separateSongs {
                // Import each selected part as a distinct standalone song in the playlist
                for page in selectedPages {
                    let partTitle = page.part.trimmingCharacters(in: .whitespacesAndNewlines)
                    let effectiveTitle: String
                    if partTitle.isEmpty {
                        effectiveTitle = "\(songTitle) (P\(page.page))"
                    } else if songTitle.isEmpty || partTitle == songTitle {
                        effectiveTitle = partTitle
                    } else {
                        effectiveTitle = "\(songTitle) - \(partTitle)"
                    }
                    
                    let version = SongVersion(
                        name: partTitle.isEmpty ? "P\(page.page)" : partTitle,
                        bvid: parsed.bvid,
                        cid: page.cid,
                        uploader: artistName,
                        duration: page.duration > 0 ? page.duration : fetchedDuration,
                        audioQuality: "192kbps DASH",
                        picUrl: fetchedCoverUrl
                    )
                    
                    let newSong = Song(
                        title: effectiveTitle,
                        artist: artistName.isEmpty ? "Bilibili Artist" : artistName,
                        artworkUrl: fetchedCoverUrl,
                        versions: [version]
                    )
                    playlist.songs.append(newSong)
                }
            } else {
                // Import as a single song with multiple selectable versions
                var versions: [SongVersion] = []
                for page in selectedPages {
                    let partTitle = page.part.trimmingCharacters(in: .whitespacesAndNewlines)
                    let label = partTitle.isEmpty ? "Part \(page.page)" : partTitle
                    versions.append(SongVersion(
                        name: label,
                        bvid: parsed.bvid,
                        cid: page.cid,
                        uploader: artistName,
                        duration: page.duration > 0 ? page.duration : fetchedDuration,
                        audioQuality: "192kbps DASH",
                        picUrl: fetchedCoverUrl
                    ))
                }
                
                let newSong = Song(
                    title: songTitle.isEmpty ? "Untitled Song" : songTitle,
                    artist: artistName.isEmpty ? "Bilibili Artist" : artistName,
                    artworkUrl: fetchedCoverUrl,
                    versions: versions
                )
                playlist.songs.append(newSong)
            }
            
            PlaylistStorageManager.shared.savePlaylists()
            dismiss()
            return
        }
        
        // Single Part Import Handling
        let newVersion = SongVersion(
            name: versionName.isEmpty ? "Original MV" : versionName,
            bvid: parsed.bvid,
            cid: fetchedCid,
            uploader: artistName,
            duration: fetchedDuration,
            audioQuality: "192kbps DASH",
            picUrl: fetchedCoverUrl
        )
        
        if let targetSong = targetSongForVersion, let songIndex = playlist.songs.firstIndex(where: { $0.id == targetSong.id }) {
            playlist.songs[songIndex].versions.append(newVersion)
        } else {
            let newSong = Song(
                title: songTitle.isEmpty ? "Untitled Song" : songTitle,
                artist: artistName.isEmpty ? "Bilibili UP" : artistName,
                artworkUrl: fetchedCoverUrl,
                versions: [newVersion]
            )
            playlist.songs.append(newSong)
        }
        
        PlaylistStorageManager.shared.savePlaylists()
        dismiss()
    }
}
