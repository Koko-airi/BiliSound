import SwiftUI

/// Sheet for importing songs or adding video versions by pasting Bilibili URLs or BV IDs
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
                            TextField("Song Title", text: $songTitle)
                            TextField("Artist", text: $artistName)
                        } else {
                            Text("Adding version to: \(targetSongForVersion?.title ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.pink)
                        }
                        
                        TextField("Version Label (e.g. Studio MV, Live 2024)", text: $versionName)
                    }
                }
                
                Section {
                    Button(action: saveSongOrVersion) {
                        HStack {
                            Spacer()
                            Text(targetSongForVersion == nil ? "Add Song to Playlist" : "Attach Version")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(!didFetchSuccess)
                }
            }
            .navigationTitle(targetSongForVersion == nil ? "Add Bilibili Song" : "Add Song Version")
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
    
    private func saveSongOrVersion() {
        guard let parsed = BilibiliURLParser.parse(input: inputUrlOrBvid) else { return }
        
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
        
        dismiss()
    }
}
