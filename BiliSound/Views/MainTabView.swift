import SwiftUI

/// Main container view with bottom tab bar, docked mini player, and full-screen player presentation
@MainActor
public struct MainTabView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @ObservedObject private var accountManager = BiliAccountManager.shared
    @ObservedObject private var storageManager = PlaylistStorageManager.shared
    
    @State private var isFullScreenPresented: Bool = false
    @State private var showingLoginSheet: Bool = false
    @State private var showingImportSheet: Bool = false
    @State private var quickPlayInput: String = ""
    @State private var isQuickPlaying: Bool = false
    @State private var quickPlayError: String?
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                // Tab 1: Playlists
                PlaylistsView(playlists: $storageManager.playlists, playerManager: playerManager)
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                
                // Tab 2: Quick Bilibili Stream
                quickStreamTab
                    .tabItem {
                        Label("Quick Stream", systemImage: "magnifyingglass")
                    }
                
                // Tab 3: Session & Settings
                settingsTab
                    .tabItem {
                        Label("Account & Settings", systemImage: "person.crop.circle")
                    }
            }
            
            // Docked Mini Player
            if playerManager.currentSong != nil {
                NowPlayingMiniBar(playerManager: playerManager) {
                    isFullScreenPresented = true
                }
                .padding(.bottom, 50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            FullScreenPlayerView(playerManager: playerManager)
        }
        .sheet(isPresented: $showingLoginSheet) {
            BilibiliLoginSheet()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportBiliPlaylistSheet()
        }
    }
    
    // MARK: - Quick Stream Tab
    
    private var quickStreamTab: some View {
        NavigationStack {
            Form {
                Section(header: Text("Stream Any Bilibili Audio")) {
                    Text("Paste any Bilibili video URL or BV ID to instantly stream in pure audio mode without video overhead.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("https://www.bilibili.com/video/BV... or BV...", text: $quickPlayInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if let err = quickPlayError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: startQuickPlay) {
                        HStack {
                            if isQuickPlaying {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text("Play Audio Stream")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(quickPlayInput.isEmpty || isQuickPlaying)
                }
                
                Section(header: Text("Audio Engine Status")) {
                    HStack {
                        Image(systemName: "headphones")
                            .foregroundColor(.green)
                        Text("Music Mode (Audio-Only)")
                        Spacer()
                        Text("Active")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .safeAreaPadding(.bottom, playerManager.currentSong != nil ? 80 : 0)
            .navigationTitle("Quick Stream")
        }
    }
    
    // MARK: - Settings & Account Tab
    
    private var settingsTab: some View {
        NavigationStack {
            List {
                // Bilibili Account Section
                Section(header: Text("Bilibili Account (账号状态)")) {
                    if accountManager.isLoggedIn {
                        HStack(spacing: 12) {
                            if let faceUrl = accountManager.face, let url = URL(string: faceUrl) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Circle().fill(Color.pink.opacity(0.3))
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.pink)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(accountManager.uname)
                                    .font(.headline)
                                
                                HStack(spacing: 6) {
                                    Text(accountManager.vipLabel)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(accountManager.vipType > 0 ? Color.pink.opacity(0.15) : Color.gray.opacity(0.15))
                                        .foregroundColor(accountManager.vipType > 0 ? .pink : .secondary)
                                        .cornerRadius(4)
                                    
                                    if let mid = accountManager.mid {
                                        Text("UID: \(mid)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: {
                            showingImportSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.pink)
                                Text("Import Bilibili Favorites (导入收藏夹)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            accountManager.logout()
                        }) {
                            HStack {
                                Spacer()
                                Text("Log Out (退出登录)")
                                Spacer()
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                    .foregroundColor(.pink)
                                    .font(.title3)
                                Text("Log In to Bilibili")
                                    .font(.headline)
                            }
                            
                            Text("Logging in unlocks VIP high-bitrate audio (192k/320k) and eliminates guest WAF challenges.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showingLoginSheet = true
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "qrcode.viewfinder")
                                    Text("Log In via Web / QR Code")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .background(Color.pink)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Playback Engine")) {
                    Toggle("Default to Music Mode (Sound Only)", isOn: $playerManager.musicModeOnly)
                    
                    Toggle(isOn: $playerManager.isVolumeNormalizationEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Volume Normalization (Loudness Matching)")
                            Text("Equalizes volume across quiet and loud uploads to prevent sudden volume shocks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if playerManager.isVolumeNormalizationEnabled {
                        HStack {
                            Text("Loudness Leveling")
                            Spacer()
                            Text("Active (\(playerManager.currentGainDescription))")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.pink)
                        }
                    }
                    
                    HStack {
                        Text("Active Stream Quality")
                        Spacer()
                        Text(playerManager.activeAudioQuality)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Session Tracking")) {
                    HStack {
                        Text("Current Session Plays")
                        Spacer()
                        Text("\(playerManager.currentSession.playedSongIds.count) tracks")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Playlist Loops Completed")
                        Spacer()
                        Text("\(playerManager.currentSession.loopCycleCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive, action: {
                        playerManager.currentSession.reset()
                    }) {
                        Text("Reset Current Session History")
                    }
                }
                
                Section(header: Text("About BiliSound")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (iOS 26.2.1 / 18.x Ready)")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("BiliSound is built for pure audio listening with multi-version track mapping and fair session shuffle.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .safeAreaPadding(.bottom, playerManager.currentSong != nil ? 80 : 0)
            .navigationTitle("Account & Settings")
        }
    }
    
    private func startQuickPlay() {
        guard let parsed = BilibiliURLParser.parse(input: quickPlayInput) else {
            quickPlayError = "Invalid BV ID or URL."
            return
        }
        
        isQuickPlaying = true
        quickPlayError = nil
        
        Task {
            do {
                let details = try await BilibiliAPIService.shared.fetchVideoDetails(bvid: parsed.bvid, pageIndex: parsed.pageIndex)
                let version = SongVersion(
                    name: "Direct Stream",
                    bvid: details.bvid,
                    cid: details.cid,
                    uploader: details.uploader,
                    duration: details.duration,
                    audioQuality: "192kbps DASH",
                    picUrl: details.picUrl
                )
                let song = Song(
                    title: details.title,
                    artist: details.uploader,
                    artworkUrl: details.picUrl,
                    versions: [version]
                )
                let tempPlaylist = Playlist(name: "Direct Stream", songs: [song])
                
                await MainActor.run {
                    self.playerManager.play(song: song, specificVersion: version, in: tempPlaylist)
                    self.isQuickPlaying = false
                    self.isFullScreenPresented = true
                    self.quickPlayInput = ""
                }
            } catch {
                await MainActor.run {
                    self.isQuickPlaying = false
                    self.quickPlayError = error.localizedDescription
                }
            }
        }
    }
}
