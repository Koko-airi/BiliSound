import SwiftUI
import AVKit

/// Feature 1, 2, 3, 4, 5: Complete immersive full-screen music player
@MainActor
public struct FullScreenPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerManager: AudioPlayerManager
    
    @State private var showingVersionSheet: Bool = false
    @State private var showingSessionSheet: Bool = false
    
    public init(playerManager: AudioPlayerManager = .shared) {
        self.playerManager = playerManager
    }
    
    public var body: some View {
        ZStack {
            // Background Dynamic Blurred Art
            backgroundBlur
            
            VStack(spacing: 0) {
                // Top Header Bar
                topBar
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 12)
                
                // Animated Centerpiece Artwork
                if let song = playerManager.currentSong {
                    AnimatedArtworkView(
                        imageUrlString: playerManager.currentVersion?.picUrl ?? song.artworkUrl,
                        isPlaying: playerManager.isPlaying,
                        size: min(UIScreen.main.bounds.width - 80, 300)
                    )
                    .padding(.vertical, 10)
                }
                
                Spacer(minLength: 12)
                
                // Track Info & Feature 4 Version Picker
                VStack(spacing: 8) {
                    trackInfoSection
                    versionSelectorBanner
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 16)
                
                // Feature 5 & Bug 4: Scrubber Bar with live "current min:sec / total min:sec" labels
                ScrubberBar(
                    currentTime: playerManager.currentTime,
                    duration: playerManager.duration,
                    onSeek: { newTime in
                        playerManager.seek(to: newTime)
                    }
                )
                .padding(.horizontal, 24)
                
                Spacer(minLength: 16)
                
                // Feature 5: Transport Controls (ff5, back 5, skip, play/pause)
                playbackControls
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 16)
                
                // Bottom Utility Bar (Audio Quality, Speed, Session Info)
                bottomUtilityBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingVersionSheet) {
            if let song = playerManager.currentSong, let playlist = playerManager.currentPlaylist {
                VersionManagerSheet(
                    song: Binding(
                        get: { playerManager.currentSong ?? song },
                        set: { newSong in
                            // Updates song in player
                        }
                    ),
                    playlist: playlist,
                    playerManager: playerManager
                )
            }
        }
        .sheet(isPresented: $showingSessionSheet) {
            SessionHistoryView(playerManager: playerManager)
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundBlur: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let artStr = playerManager.currentVersion?.picUrl ?? playerManager.currentSong?.artworkUrl,
               let url = URL(string: artStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .blur(radius: 50)
                            .opacity(0.45)
                    }
                }
                .ignoresSafeArea()
            }
            
            LinearGradient(
                colors: [.black.opacity(0.3), .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(playerManager.currentPlaylist?.name.uppercased() ?? "BILIBILI PLAYLIST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                
                // Feature 1: Pure Audio Indicator
                HStack(spacing: 4) {
                    Image(systemName: "headphones")
                        .font(.system(size: 10))
                    Text("Music Mode • Sound Only")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.green.opacity(0.9))
            }
            
            Spacer()
            
            Button(action: { showingSessionSheet = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    private var trackInfoSection: some View {
        VStack(spacing: 4) {
            Text(playerManager.currentSong?.title ?? "No Song Selected")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            Text(playerManager.currentSong?.artist ?? "")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
    
    // Bug 3: Formatted track time labels (current time / total duration)
    private var trackTimeLabels: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(formatTime(playerManager.currentTime))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                Text("/")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
                Text(formatTime(playerManager.duration))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            Spacer()
            
            let remaining = max(0, playerManager.duration - playerManager.currentTime)
            Text("-\(formatTime(remaining))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && time >= 0 else { return "00:00" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // Feature 4: Banner showing active version and quick re-roll button
    private var versionSelectorBanner: some View {
        Group {
            if let song = playerManager.currentSong, let version = playerManager.currentVersion {
                HStack(spacing: 8) {
                    Button(action: { showingVersionSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "dice.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.pink)
                            
                            Text("Version: \(version.name)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    
                    // Quick Re-roll button (Feature 4 random select)
                    if song.versions.count > 1 {
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            playerManager.rerollVersion()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.pink)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // Feature 5 & 2: Controls row
    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Playback Mode toggle (Sequential / Shuffle / RepeatOne) - Feature 2
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                playerManager.togglePlaybackMode()
            }) {
                Image(systemName: playerManager.playbackMode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(playerManager.playbackMode == .sequential ? .white.opacity(0.6) : .pink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Feature 5: Rewind 5s
            Button(action: { playerManager.rewind5() }) {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Feature 5: Previous Song
            Button(action: { playerManager.skipToPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Feature 5: Play / Pause Hero Button
            Button(action: { playerManager.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                    
                    if playerManager.isBuffering {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.black)
                            .offset(x: playerManager.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Feature 5: Next Song
            Button(action: { playerManager.skipToNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Feature 5: Fast Forward 5s
            Button(action: { playerManager.fastForward5() }) {
                Image(systemName: "goforward.5")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Version Drawer shortcut (Feature 4)
            Button(action: { showingVersionSheet = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var bottomUtilityBar: some View {
        HStack {
            // Quality Tag
            HStack(spacing: 4) {
                Image(systemName: "waveform.circle.fill")
                    .font(.caption)
                    .foregroundColor(.pink)
                Text(playerManager.activeAudioQuality)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Playback Speed Menu
            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button(action: {
                        playerManager.setPlaybackRate(Float(rate))
                    }) {
                        HStack {
                            Text(String(format: "%.2fx", rate))
                            if Float(rate) == playerManager.playbackRate {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(String(format: "%.2fx", playerManager.playbackRate))
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
            }
        }
    }
}
