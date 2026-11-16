import SwiftUI
import UIKit

/// Animated high-res artwork display with vinyl rotation and ambient glow
public struct AnimatedArtworkView: View {
    let imageUrlString: String?
    let isPlaying: Bool
    var size: CGFloat = 280
    
    public init(imageUrlString: String?, isPlaying: Bool, size: CGFloat = 280) {
        self.imageUrlString = imageUrlString
        self.isPlaying = isPlaying
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Ambient colorful shadow (downsampled to 100x100 thumbnail to eliminate memory spike)
            if let urlStr = imageUrlString {
                CachedThumbnailView(
                    urlString: urlStr,
                    targetSize: CGSize(width: 100, height: 100),
                    placeholder: { Color.clear }
                )
                .frame(width: size * 0.85, height: size * 0.85)
                .blur(radius: 20)
                .opacity(0.55)
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
            
            // Center Album Art (Continuous Hardware-Accelerated CoreAnimation Rotation)
            ContinuousRotation(isRotating: isPlaying, duration: 20) {
                ZStack {
                    CachedThumbnailView(
                        urlString: imageUrlString,
                        targetSize: CGSize(width: size * 0.6, height: size * 0.6),
                        placeholder: { fallbackArt }
                    )
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
                }
                .frame(width: size * 0.6, height: size * 0.6)
            }
            .frame(width: size * 0.6, height: size * 0.6)
        }
        .compositingGroup()
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

// MARK: - Hardware-Accelerated CoreAnimation Rotation Wrapper

/// A hardware-accelerated continuous rotation wrapper using CoreAnimation.
/// Runs directly on the GPU render server with 0% CPU overhead, preserves exact pause angle,
/// resumes seamlessly, and is completely immune to SwiftUI view transition cancellation.
public struct ContinuousRotation<Content: View>: UIViewRepresentable {
    let isRotating: Bool
    let duration: Double
    let content: Content
    
    public init(isRotating: Bool, duration: Double = 20, @ViewBuilder content: () -> Content) {
        self.isRotating = isRotating
        self.duration = duration
        self.content = content()
    }
    
    public func makeUIView(context: Context) -> RotationHostingView<Content> {
        RotationHostingView(rootView: content, duration: duration)
    }
    
    public func updateUIView(_ uiView: RotationHostingView<Content>, context: Context) {
        uiView.rootView = content
        uiView.duration = duration
        if isRotating {
            uiView.startOrResume()
        } else {
            uiView.pause()
        }
    }
}

public final class RotationHostingView<Content: View>: UIView {
    private let hostingController: UIHostingController<Content>
    private let animationKey = "ContinuousRotationAnim"
    var duration: Double
    private var isAnimationAdded = false
    
    init(rootView: Content, duration: Double) {
        self.duration = duration
        self.hostingController = UIHostingController(rootView: rootView)
        super.init(frame: .zero)
        
        backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    var rootView: Content {
        get { hostingController.rootView }
        set { hostingController.rootView = newValue }
    }
    
    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            if isAnimationAdded && layer.speed != 0.0 {
                if layer.animation(forKey: animationKey) == nil {
                    addAnimation()
                }
            }
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        if isAnimationAdded && layer.speed != 0.0 {
            if layer.animation(forKey: animationKey) == nil {
                addAnimation()
            }
        }
    }
    
    func startOrResume() {
        if !isAnimationAdded || layer.animation(forKey: animationKey) == nil {
            addAnimation()
        } else if layer.speed == 0.0 {
            let pausedTime = layer.timeOffset
            layer.speed = 1.0
            layer.timeOffset = 0.0
            layer.beginTime = 0.0
            let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            layer.beginTime = timeSincePause
        }
    }
    
    func pause() {
        guard isAnimationAdded, layer.animation(forKey: animationKey) != nil else { return }
        guard layer.speed != 0.0 else { return }
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0.0
        layer.timeOffset = pausedTime
    }
    
    private func addAnimation() {
        layer.removeAnimation(forKey: animationKey)
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2.0
        rotation.duration = duration
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        layer.add(rotation, forKey: animationKey)
        isAnimationAdded = true
        layer.speed = 1.0
    }
}
