import SwiftUI

/// Glassmorphism styled button wrapper for music controls
public struct GlassButton<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    var size: CGFloat = 48
    
    public init(size: CGFloat = 48, action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.size = size
        self.action = action
        self.content = content
    }
    
    public var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                content()
            }
        }
        .buttonStyle(.plain)
    }
}
