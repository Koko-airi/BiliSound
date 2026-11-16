import SwiftUI
import AVKit

/// Feature 1, 2, 3, 4, 5: Complete immersive full-screen music player
@MainActor
public struct FullScreenPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playerManager: AudioPlayerManager
    
    @State private var showingVersionSheet: Bool = false
    @State private var showingSessionSheet: Bool = false
    
    // Interactive slide-to-dismiss gesture state
    @State private var dismissOffset: CGFloat = 0
    @State private var isDraggingDismiss: Bool = false
    
    public init(playerManager: AudioPlayerManager = .shared) {
        self.playerManager = playerManager
    }
    
    public var body: some View {
        GeometryReader { outerGeo in
            let screenHeight = outerGeo.size.height
            let screenWidth = outerGeo.size.width
            let safeTop = outerGeo.safeAreaInsets.top
            let safeBottom = outerGeo.safeAreaInsets.bottom
            
            // Standard comfortable horizontal width anchored to device width (32pt margin on each side)
            let contentWidth = max(200, screenWidth - 64)
            
            // Adaptively scale rotating disk so all player elements (timestamps, scrubber, controls)
            // fit comfortably without clipping on vertical/portrait screens of any device size.
            let diskSize: CGFloat = min(screenWidth - 100, screenHeight > 750 ? 230 : 170)
            
            ZStack {
                // Background Dynamic Blurred Art spanning the full window including under notch/corners
                backgroundBlur(screenWidth: screenWidth, screenHeight: screenHeight)
                
                VStack(spacing: 0) {
                    // Top Header Bar: comfortably under notch with dismiss and history buttons moved closer to center
                    topBar(width: contentWidth, safeTop: safeTop, screenHeight: screenHeight)
                    
                    Spacer(minLength: 6)
                    
                    // Animated Centerpiece Artwork (The Spinning Disk) centered
                    if let song = playerManager.currentSong {
                        AnimatedArtworkView(
                            imageUrlString: playerManager.currentVersion?.picUrl ?? song.artworkUrl,
                            isPlaying: playerManager.isPlaying,
                            size: diskSize
                        )
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                    }
                    
                    Spacer(minLength: 6)
                    
                    // Track Info & Feature 4 Version Picker (Responsive to Phone Screen Width)
                    VStack(spacing: 6) {
                        trackInfoSection(screenWidth: screenWidth)
                        versionSelectorBanner(screenWidth: screenWidth)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Spacer(minLength: 8)
                    
                    // Prominent Timestamp Badge directly under spinning disk and track info
                    prominentTimestampBadge
                        .frame(maxWidth: .infinity)
                    
                    Spacer(minLength: 12)
                    
                    // Feature 5: Scrubber Bar - explicitly sized to contentWidth to prevent timestamps clipping the screen edge
                    ScrubberBar(
                        currentTime: playerManager.currentTime,
                        duration: playerManager.duration,
                        barWidth: contentWidth,
                        onSeek: { newTime in
                            playerManager.seek(to: newTime)
                        }
                    )
                    .frame(width: contentWidth)
                    
                    Spacer(minLength: 14)
                    
                    // Feature 5: Transport Controls (ff5, back 5, skip, play/pause)
                    playbackControls(width: contentWidth)
                    
                    Spacer(minLength: 10)
                    
                    // Bottom Utility Bar: safely inset from rounded corners and home indicator
                    bottomUtilityBar(width: contentWidth, safeBottom: safeBottom)
                }
                .frame(width: screenWidth, height: screenHeight)
            }
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
            .cornerRadius(dismissOffset > 0 ? min(36, dismissOffset / 6) : 0)
            .offset(y: dismissOffset)
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .global)
                    .onChanged { value in
                        // Activate if drag starts on the left side (left 45%) or near top of screen
                        guard isDraggingDismiss || value.startLocation.x < screenWidth * 0.45 || value.startLocation.y < 220 else { return }
                        
                        let horizontalTravel = value.translation.width
                        let verticalTravel = value.translation.height
                        
                        // User is sliding right from the left, or pulling down
                        if horizontalTravel > 0 || verticalTravel > 0 {
                            isDraggingDismiss = true
                            // Direct mapping: horizontal slide from left or vertical pull drops screen down
                            let rawDrop = max(verticalTravel, horizontalTravel * 0.95)
                            dismissOffset = max(0, rawDrop)
                        }
                    }
                    .onEnded { value in
                        guard isDraggingDismiss else { return }
                        isDraggingDismiss = false
                        
                        let horizontalTravel = value.translation.width
                        let verticalTravel = value.translation.height
                        let predictedX = value.predictedEndTranslation.width
                        let predictedY = value.predictedEndTranslation.height
                        
                        // Threshold: dragged > 60 points or fast flick (predicted > 120 points)
                        let shouldDismiss = horizontalTravel > 60 || verticalTravel > 60 || predictedX > 120 || predictedY > 120
                        
                        if shouldDismiss {
                            performDismissWithDropAnimation(screenHeight: screenHeight)
                        } else {
                            // Cancelled: smoothly spring back up into place
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dismissOffset = 0
                            }
                        }
                    }
            )
            .onAppear {
                dismissOffset = 0
                isDraggingDismiss = false
            }
        }
        .ignoresSafeArea()
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
    
    private func backgroundBlur(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack {
            Color.black
            
            if let artStr = playerManager.currentVersion?.picUrl ?? playerManager.currentSong?.artworkUrl {
                CachedThumbnailView(
                    urlString: artStr,
                    targetSize: CGSize(width: 120, height: 120),
                    placeholder: {
                        Color.clear
                    }
                )
                .scaledToFill()
                .frame(width: screenWidth, height: screenHeight)
                .clipped()
                .blur(radius: 35)
                .opacity(0.45)
            }
            
            LinearGradient(
                colors: [.black.opacity(0.3), .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: screenWidth, height: screenHeight)
        .clipped()
    }
    
    private func performDismissWithDropAnimation(screenHeight: CGFloat) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        withAnimation(.easeOut(duration: 0.22)) {
            dismissOffset = screenHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dismiss()
        }
    }
    
    private func topBar(width: CGFloat, safeTop: CGFloat, screenHeight: CGFloat) -> some View {
        HStack {
            Button(action: { performDismissWithDropAnimation(screenHeight: screenHeight) }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(playerManager.currentPlaylist?.name.uppercased() ?? "BILIBILI PLAYLIST")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.65))
                .tracking(1.2)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: { showingSessionSheet = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .frame(width: width)
        .padding(.top, max(safeTop, 47) + 4)
    }
    
    private func trackInfoSection(screenWidth: CGFloat) -> some View {
        let maxTitleWidth = max(100, screenWidth - 40)
        
        return VStack(spacing: 4) {
            Text(playerManager.currentSong?.title ?? "No Song Selected")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: maxTitleWidth)
            
            Text(playerManager.currentSong?.artist ?? "")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: maxTitleWidth)
        }
        .frame(maxWidth: screenWidth)
    }
    
    // Prominent Timestamp Badge displayed directly on the spinning disk page
    private var prominentTimestampBadge: some View {
        let totalDuration = playerManager.duration > 0 && !playerManager.duration.isNaN ? playerManager.duration : 240.0
        return HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.caption2)
                .foregroundColor(.pink)
            
            Text(formatTime(playerManager.currentTime))
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundColor(.white)
            
            Text("/")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
            
            Text(formatTime(totalDuration))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && time >= 0 else { return "00:00" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // Feature 4: Banner showing active version, quick re-roll button, and V1 Only checkbox
    // Dynamically scales with detected phone screen width, maximizing title space before shortening
    private func versionSelectorBanner(screenWidth: CGFloat) -> some View {
        Group {
            if let song = playerManager.currentSong, let version = playerManager.currentVersion {
                let availableRowWidth = max(200, screenWidth - 32) // 16pt margin from each device screen edge
                let hasMultipleVersions = song.versions.count > 1
                
                // Accessories widths:
                // Re-roll button: 28pt + 8pt spacing = 36pt (when present)
                // V1 Only button: ~78pt + 8pt spacing = 86pt
                let accessoriesWidth: CGFloat = hasMultipleVersions ? 122 : 86
                let maxVersionPillWidth = max(120, availableRowWidth - accessoriesWidth)
                
                HStack(spacing: 8) {
                    Button(action: { showingVersionSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "dice.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.pink)
                            
                            Text(version.name.isEmpty ? "Default Version" : version.name)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.85)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: maxVersionPillWidth)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Version: \(version.name)")
                    .layoutPriority(0)
                    
                    // Quick Re-roll button (Feature 4 random select)
                    if hasMultipleVersions {
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
                        .fixedSize()
                        .layoutPriority(1)
                    }
                    
                    // Small Checkbox: When turned on, only play default (first) version; when off, play random version
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        playerManager.playDefaultVersionOnly.toggle()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: playerManager.playDefaultVersionOnly ? "checkmark.square.fill" : "square")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(playerManager.playDefaultVersionOnly ? .pink : .white.opacity(0.6))
                            
                            Text("V1 Only")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(playerManager.playDefaultVersionOnly ? .white : .white.opacity(0.75))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(playerManager.playDefaultVersionOnly ? Color.pink.opacity(0.25) : Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(playerManager.playDefaultVersionOnly ? Color.pink.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .layoutPriority(1)
                }
                .frame(maxWidth: availableRowWidth)
            }
        }
    }
    
    // Feature 5 & 2: Controls row
    private func playbackControls(width: CGFloat) -> some View {
        HStack(spacing: 0) {
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
            
            Spacer()
            
            // Feature 5: Previous Song
            Button(action: { playerManager.skipToPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
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
            
            Spacer()
            
            // Feature 5: Next Song
            Button(action: { playerManager.skipToNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
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
        .frame(width: width)
    }
    
    private func bottomUtilityBar(width: CGFloat, safeBottom: CGFloat) -> some View {
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
        .frame(width: width)
        .padding(.bottom, max(safeBottom, 20) + 8)
    }
}
