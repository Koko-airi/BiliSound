import SwiftUI

/// Song row view in playlist lists with multi-version badge and version manager trigger
public struct SongRowView: View {
    let song: Song
    let isPlayingCurrent: Bool
    let activeVersionName: String?
    let onSelect: () -> Void
    let onManageVersions: () -> Void
    
    public init(
        song: Song,
        isPlayingCurrent: Bool,
        activeVersionName: String? = nil,
        onSelect: @escaping () -> Void,
        onManageVersions: @escaping () -> Void
    ) {
        self.song = song
        self.isPlayingCurrent = isPlayingCurrent
        self.activeVersionName = activeVersionName
        self.onSelect = onSelect
        self.onManageVersions = onManageVersions
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Artwork / Equalizer
            ZStack {
                if let artStr = song.artworkUrl, let url = URL(string: artStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            defaultThumbnail
                        }
                    }
                } else {
                    defaultThumbnail
                }
                
                if isPlayingCurrent {
                    Color.black.opacity(0.4)
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.pink)
                        .symbolEffect(.variableColor.iterative.reversing)
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            
            // Title & Artist
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(song.title)
                        .font(.body.weight(isPlayingCurrent ? .bold : .medium))
                        .foregroundColor(isPlayingCurrent ? .pink : .primary)
                        .lineLimit(1)
                    
                    if song.versions.count > 1 {
                        VersionBadge(count: song.versions.count, isSelected: isPlayingCurrent)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(song.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if isPlayingCurrent, let vName = activeVersionName {
                        Text("• [\(vName)]")
                            .font(.caption2.italic())
                            .foregroundColor(.pink.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Feature 4: Button to view/manage versions for this song
            Button(action: onManageVersions) {
                Image(systemName: "slider.horizontal.2.square")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var defaultThumbnail: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "music.note")
                .foregroundColor(.secondary)
        }
    }
}
