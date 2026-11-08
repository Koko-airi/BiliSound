import SwiftUI

/// Animated high-res artwork display with vinyl rotation and ambient glow
public struct AnimatedArtworkView: View {
    let imageUrlString: String?
    let isPlaying: Bool
    var size: CGFloat = 280
    
    @State private var rotationDegrees: Double = 0
    
    public init(imageUrlString: String?, isPlaying: Bool, size: CGFloat = 280) {
        self.imageUrlString = imageUrlString
        self.isPlaying = isPlaying
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Ambient colorful shadow
            if let urlStr = imageUrlString, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size * 0.9, height: size * 0.9)
                            .blur(radius: 28)
                            .opacity(0.6)
                    }
                }
            }
            
            // Vinyl Record Ring Background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.1), Color(white: 0.2), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            
            // Grooves on vinyl
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                .frame(width: size * 0.88, height: size * 0.88)
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                .frame(width: size * 0.68, height: size * 0.68)
            
            // Center Album Art
            Group {
                if let urlStr = imageUrlString, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            fallbackArt
                        }
                    }
                } else {
                    fallbackArt
                }
            }
            .frame(width: size * 0.6, height: size * 0.6)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            // Center spindle hole
            .overlay(
                Circle()
                    .fill(Color.black)
                    .frame(width: size * 0.08, height: size * 0.08)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
            )
            .rotationEffect(.degrees(rotationDegrees))
        }
        .onAppear {
            if isPlaying {
                startRotation()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startRotation()
            }
        }
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationDegrees += 360
        }
    }
    
    private var fallbackArt: some View {
        ZStack {
            LinearGradient(
                colors: [.purple, .indigo, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.2))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
