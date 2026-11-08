import Foundation
import MediaPlayer
import UIKit

/// Manages Lock Screen, Control Center, and Remote Command Center controls (Feature 5).
public final class NowPlayingManager {
    public static let shared = NowPlayingManager()
    
    public weak var playerManager: AudioPlayerManager?
    
    private init() {}
    
    // MARK: - Setup Remote Commands
    
    public func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play / Pause
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.play()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.pause()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.togglePlayPause()
            }
            return .success
        }
        
        // Skip Next / Previous
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.skipToNext()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.skipToPrevious()
            }
            return .success
        }
        
        // Feature 5: Fast-forward 5s and Rewind 5s
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [5.0]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.fastForward5()
            }
            return .success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [5.0]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playerManager?.rewind5()
            }
            return .success
        }
        
        // Scrubber / Position change
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.playerManager?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }
    
    // MARK: - Update Now Playing Metadata
    
    public func updateNowPlayingInfo(
        song: Song?,
        version: SongVersion?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        playbackRate: Float
    ) {
        guard let song = song, let version = version else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        // Show current version info in the album/version field
        let albumTitle = song.album ?? "Bilibili Music Mode"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "\(albumTitle) • [\(version.name)]"
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = max(0, duration)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, currentTime)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackRate) : 0.0
        
        // Asynchronously load artwork if URL is available
        if let artString = version.picUrl ?? song.artworkUrl, let artUrl = URL(string: artString) {
            URLSession.shared.dataTask(with: artUrl) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    DispatchQueue.main.async {
                        var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? nowPlayingInfo
                        updated[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                    }
                }
            }.resume()
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
