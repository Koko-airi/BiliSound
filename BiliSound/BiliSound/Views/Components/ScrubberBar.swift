import SwiftUI

/// Feature 5: Interactive Scrubber with bounded track, centered thumb positioning,
/// and live formatted "current min:sec / total min:sec" indicators.
public struct ScrubberBar: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragTime: TimeInterval = 0
    
    public init(
        currentTime: TimeInterval,
        duration: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self.currentTime = currentTime
        self.duration = duration
        self.onSeek = onSeek
    }
    
    private var displayTime: TimeInterval {
        isDragging ? dragTime : currentTime
    }
    
    /// Progress ratio strictly clamped between 0.0 and 1.0
    private var progressRatio: Double {
        guard duration > 0, !duration.isNaN else { return 0.0 }
        let rawRatio = displayTime / duration
        return min(max(rawRatio, 0.0), 1.0)
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let totalWidth = max(geo.size.width, 1.0)
                let totalHeight = geo.size.height
                let thumbDiameter: CGFloat = isDragging ? 18 : 12
                
                // Knob center smoothly travels between (thumbDiameter/2) and (totalWidth - thumbDiameter/2)
                // This guarantees the knob is 100% visible inside container bounds at ANY playback second (0s to end).
                let thumbTravelDistance = max(0, totalWidth - thumbDiameter)
                let thumbCenterX = (thumbDiameter / 2) + (CGFloat(progressRatio) * thumbTravelDistance)
                let activeTrackWidth = max(0, min(thumbCenterX, totalWidth))
                
                ZStack(alignment: .leading) {
                    // Inactive background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: totalWidth, height: isDragging ? 6 : 4)
                        .position(x: totalWidth / 2, y: totalHeight / 2)
                    
                    // Active filled progress track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: activeTrackWidth, height: isDragging ? 6 : 4)
                        .position(x: activeTrackWidth / 2, y: totalHeight / 2)
                    
                    // Scrubber thumb knob - always centered at thumbCenterX, strictly within visible screen
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .position(x: thumbCenterX, y: totalHeight / 2)
                }
                .frame(width: totalWidth, height: totalHeight, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard totalWidth > 0 else { return }
                            isDragging = true
                            let percent = min(max(value.location.x / totalWidth, 0.0), 1.0)
                            dragTime = percent * max(0, duration)
                        }
                        .onEnded { value in
                            guard totalWidth > 0 else { return }
                            let percent = min(max(value.location.x / totalWidth, 0.0), 1.0)
                            let targetTime = percent * max(0, duration)
                            onSeek(targetTime)
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)
            
            // Time Labels: "current min:sec / total min:sec" and remaining "-min:sec"
            HStack {
                HStack(spacing: 4) {
                    Text(formatTime(displayTime))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white)
                    Text("/")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                    Text(formatTime(duration))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                
                Spacer()
                
                let remaining = max(0, duration - displayTime)
                Text("-" + formatTime(remaining))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && time >= 0 else { return "00:00" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

