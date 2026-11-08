import SwiftUI

/// Floating mini-player bar docked above the tab bar with quick controls (ff5, play/pause, skip)
@MainActor
public struct NowPlayingMiniBar: View {
    @ObservedObject var playerManager: AudioPlayerManager
    let onTap: () -> Void
    
    public init(playerManager: AudioPlayerManager = .shared, onTap: @escaping () -> Void) {
        self.playerManager = playerManager
        self.onTap = onTap
    }
    
    public var body: some View {
        Group {
            if let song = playerManager.currentSong {
                HStack(spacing: 12) {
                    // Artwork Thumbnail
                    ZStack {
                        if let artStr = playerManager.currentVersion?.picUrl ?? song.artworkUrl,
                           let url = URL(string: artStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color.pink.opacity(0.3)
                                }
                            }
                        } else {
                            Color.pink.opacity(0.3)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(8)
                    
                    // Track Title & Version Tag
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            if let version = playerManager.currentVersion {
                                Text("[\(version.name)]")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.pink)
                                    .lineLimit(1)
                            } else {
                                Text(song.artist)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Feature 5: Rewind 5s
                    Button(action: { playerManager.rewind5() }) {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    
                    // Feature 5: Play / Pause
                    Button(action: { playerManager.togglePlayPause() }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    
                    // Feature 5: Fast Forward 5s
                    Button(action: { playerManager.fastForward5() }) {
                        Image(systemName: "goforward.5")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    
                    // Feature 5: Skip Next
                    Button(action: { playerManager.skipToNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.15).opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        // Subtle top progress line with strictly clamped width
                        VStack {
                            GeometryReader { geo in
                                let progress = min(max(playerManager.duration > 0 ? (playerManager.currentTime / playerManager.duration) : 0.0, 0.0), 1.0)
                                let lineWidth = min(max(geo.size.width * CGFloat(progress), 0), geo.size.width)
                                Rectangle()
                                    .fill(LinearGradient(colors: [.pink, .cyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: lineWidth, height: 2)
                            }
                            .frame(height: 2)
                            Spacer()
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
    }
}
