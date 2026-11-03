import SwiftUI

/// Feature 5: Interactive Scrubber with leading alignment, non-animating gesture tracking,
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
    
    private var effectiveDuration: TimeInterval {
        duration > 0 && !duration.isNaN ? duration : 240.0
    }
    
    private var displayTime: TimeInterval {
        isDragging ? dragTime : currentTime
    }
    
    /// Progress ratio strictly clamped between 0.0 and 1.0
    private var progressRatio: Double {
        guard effectiveDuration > 0 else { return 0.0 }
        let rawRatio = displayTime / effectiveDuration
        return min(max(rawRatio, 0.0), 1.0)
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let totalWidth = max(geo.size.width, 1.0)
                let thumbDiameter: CGFloat = 14
                let usableTravel = max(0, totalWidth - thumbDiameter)
                let thumbOffset = CGFloat(progressRatio) * usableTravel
                let activeTrackWidth = (thumbDiameter / 2) + thumbOffset
                
                // Using ZStack(alignment: .leading) with offset instead of .position()
                // to completely eliminate SwiftUI AnimatablePair timeline collision assertions.
                ZStack(alignment: .leading) {
                    // Full background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                    
                    // Active progress track from beginning (0) to thumb knob center
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(thumbDiameter / 2, min(activeTrackWidth, totalWidth)), height: 4)
                    
                    // Scrubber thumb knob - smoothly moves from leading edge (0) to trailing edge (totalWidth - thumbDiameter)
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .scaleEffect(isDragging ? 1.25 : 1.0)
                        .offset(x: thumbOffset)
                }
                .frame(width: totalWidth, height: geo.size.height, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard totalWidth > 0 else { return }
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                isDragging = true
                                let percent = min(max(value.location.x / totalWidth, 0.0), 1.0)
                                dragTime = percent * effectiveDuration
                            }
                        }
                        .onEnded { value in
                            guard totalWidth > 0 else { return }
                            let percent = min(max(value.location.x / totalWidth, 0.0), 1.0)
                            let targetTime = percent * effectiveDuration
                            onSeek(targetTime)
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 20)
            
            // Sub-bar time labels: "current min:sec" on left, "total min:sec" & remaining on right
            HStack {
                Text(formatTime(displayTime))
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(formatTime(effectiveDuration))
                        .font(.footnote.monospacedDigit().weight(.medium))
                        .foregroundColor(.white.opacity(0.75))
                    
                    let remaining = max(0, effectiveDuration - displayTime)
                    Text("(-\(formatTime(remaining)))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                }
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

