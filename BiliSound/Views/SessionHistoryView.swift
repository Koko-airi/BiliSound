import SwiftUI

/// Feature 3: Sheet to inspect the listening session and verify non-repeating shuffle behavior
@MainActor
public struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerManager: AudioPlayerManager
    
    public init(playerManager: AudioPlayerManager = .shared) {
        self.playerManager = playerManager
    }
    
    private var playlistSongsCount: Int {
        playerManager.currentPlaylist?.songs.count ?? 0
    }
    
    private var playedCount: Int {
        playerManager.currentSession.playedSongIds.count
    }
    
    private var sessionProgress: Double {
        guard playlistSongsCount > 0 else { return 0 }
        return min(1.0, Double(playedCount) / Double(playlistSongsCount))
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Feature 3 Rule Summary Card
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "shield.checkerboard")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            Text("Single-Session Guarantee")
                                .font(.headline)
                        }
                        
                        Text("Within this active playback session, shuffle mode will never select a song that has already been played until every song in the playlist has been played.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Progress bar
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(playedCount) of \(playlistSongsCount) songs played")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(String(format: "%.0f%%", sessionProgress * 100))
                                    .font(.caption.monospacedDigit())
                            }
                            ProgressView(value: sessionProgress)
                                .tint(.pink)
                        }
                        .padding(.top, 4)
                        
                        if playerManager.currentSession.loopCycleCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.orange)
                                Text("Completed \(playerManager.currentSession.loopCycleCount) full playlist cycle(s)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                // Played History in this Session
                Section(header: Text("Played in Current Session (\(playerManager.currentSession.history.count))")) {
                    if playerManager.currentSession.history.isEmpty {
                        Text("No songs played in this session yet.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(playerManager.currentSession.history.enumerated().reversed()), id: \.element.id) { index, record in
                            HStack(spacing: 12) {
                                Text("#\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.songTitle)
                                        .font(.subheadline.weight(.medium))
                                    
                                    HStack(spacing: 4) {
                                        Text("🎲 Version:")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(record.versionName)
                                            .font(.caption2.italic())
                                            .foregroundColor(.pink)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(record.playedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Remaining Unplayed Pool for Next Shuffle
                if let playlist = playerManager.currentPlaylist {
                    let unplayed = playerManager.currentSession.unplayedSongs(from: playlist)
                    Section(header: Text("Remaining Eligible Pool for Next Shuffle (\(unplayed.count))")) {
                        if unplayed.isEmpty {
                            Text("All songs have been played! The next shuffle will restart a fresh cycle.")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            ForEach(unplayed) { song in
                                HStack {
                                    Text(song.title)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(song.versions.count) v")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Session Reset Action
                Section {
                    Button(role: .destructive, action: {
                        playerManager.currentSession.reset()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Session History")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Session Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
