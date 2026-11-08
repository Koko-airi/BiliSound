import SwiftUI

/// Feature 4: Sheet to inspect, test, toggle, and add video versions for a song
@MainActor
public struct VersionManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerManager: AudioPlayerManager
    
    @Binding var song: Song
    let playlist: Playlist
    
    @State private var showingAddVersion: Bool = false
    @State private var newVersionBvid: String = ""
    @State private var newVersionName: String = ""
    @State private var isLoadingInfo: Bool = false
    @State private var errorMessage: String?
    
    public init(song: Binding<Song>, playlist: Playlist, playerManager: AudioPlayerManager = .shared) {
        self._song = song
        self.playlist = playlist
        self.playerManager = playerManager
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Info Banner
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "dice.fill")
                                .font(.title3)
                                .foregroundColor(.pink)
                            Text("Multi-Version Engine")
                                .font(.headline)
                        }
                        Text("When this song is selected, BiliSound will randomly choose one of the enabled versions below to stream in pure audio mode.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Versions List
                Section(header: Text("Available Versions (\(song.versions.count))")) {
                    ForEach($song.versions) { $version in
                        versionRow(for: $version)
                    }
                    .onDelete { indexSet in
                        song.versions.remove(atOffsets: indexSet)
                    }
                }
                
                // Add Version Form
                Section(header: Text("Add Another Bilibili Version")) {
                    TextField("Bilibili URL or BV ID (e.g. BV1...)", text: $newVersionBvid)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Version Label (e.g. Live Concert, Acoustic)", text: $newVersionName)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: addVersionFromBili) {
                        HStack {
                            if isLoadingInfo {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Fetch & Add Version")
                        }
                    }
                    .disabled(newVersionBvid.isEmpty || isLoadingInfo)
                }
                
                // Quick Test Action
                Section {
                    Button(action: {
                        if let randomV = song.selectRandomVersion() {
                            playerManager.play(song: song, specificVersion: randomV, in: playlist)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "dice")
                            Text("Roll & Play Random Version Now")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.pink)
                }
            }
            .navigationTitle(song.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func versionRow(for versionBinding: Binding<SongVersion>) -> some View {
        let version = versionBinding.wrappedValue
        let isCurrentlyPlaying = playerManager.currentSong?.id == song.id && playerManager.currentVersion?.id == version.id
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(version.name)
                            .font(.body.weight(isCurrentlyPlaying ? .bold : .medium))
                            .foregroundColor(isCurrentlyPlaying ? .pink : .primary)
                        
                        if isCurrentlyPlaying {
                            Text("NOW PLAYING")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.15))
                                .foregroundColor(.pink)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("BV: \(version.bvid) • UP: \(version.uploader)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(version.audioQuality)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(3)
                        
                        if version.duration > 0 {
                            Text(version.formattedDuration)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Direct Play Button
                Button(action: {
                    playerManager.play(song: song, specificVersion: version, in: playlist)
                    dismiss()
                }) {
                    Image(systemName: isCurrentlyPlaying && playerManager.isPlaying ? "speaker.wave.3.fill" : "play.circle")
                        .font(.title3)
                        .foregroundColor(.pink)
                }
                .buttonStyle(.plain)
                
                // Enable / Disable toggle
                Toggle("", isOn: versionBinding.isEnabled)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func addVersionFromBili() {
        guard let parsed = BilibiliURLParser.parse(input: newVersionBvid) else {
            errorMessage = "Invalid BV ID or URL format."
            return
        }
        
        isLoadingInfo = true
        errorMessage = nil
        
        Task {
            do {
                let details = try await BilibiliAPIService.shared.fetchVideoDetails(bvid: parsed.bvid, pageIndex: parsed.pageIndex)
                let label = newVersionName.isEmpty ? details.title : newVersionName
                
                let newVersion = SongVersion(
                    name: label,
                    bvid: details.bvid,
                    cid: details.cid,
                    uploader: details.uploader,
                    duration: details.duration,
                    audioQuality: "192kbps DASH",
                    picUrl: details.picUrl
                )
                
                await MainActor.run {
                    song.versions.append(newVersion)
                    newVersionBvid = ""
                    newVersionName = ""
                    isLoadingInfo = false
                }
            } catch {
                await MainActor.run {
                    isLoadingInfo = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
