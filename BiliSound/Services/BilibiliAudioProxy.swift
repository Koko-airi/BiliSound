import Foundation
import AVFoundation
import UIKit
import SwiftUI
import ImageIO

/// Handles custom HTTP headers (Referer, User-Agent, Cookie) required by Bilibili CDN to prevent HTTP 403 Forbidden.
public final class BilibiliAudioAssetFactory: NSObject, AVAssetResourceLoaderDelegate {
    public static let shared = BilibiliAudioAssetFactory()
    
    private var pendingRequests = [AVAssetResourceLoadingRequest]()
    private let session: URLSession
    
    public override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        super.init()
    }
    
    /// Creates an AVURLAsset configured with the required Bilibili CDN headers.
    @MainActor public func createAsset(for streamUrl: URL, bvid: String) -> AVURLAsset {
        var headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Referer": "https://www.bilibili.com/video/\(bvid)",
            "Origin": "https://www.bilibili.com"
        ]
        
        let cookies = BiliAccountManager.currentCookieHeader()
        if !cookies.isEmpty {
            headers["Cookie"] = cookies
        }
        
        let options: [String: Any] = [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ]
        
        let asset = AVURLAsset(url: streamUrl, options: options)
        return asset
    }
}

// MARK: - Bilibili Image CDN Optimizer & Downsampler

public enum BiliImageOptimizer {
    /// Formats an image URL to request a lightweight thumbnail directly from Bilibili CDN
    public static func thumbnailUrl(for originalUrlString: String?, targetPixelSize: Int = 160) -> URL? {
        guard let originalUrlString = originalUrlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !originalUrlString.isEmpty,
              let url = URL(string: originalUrlString) else {
            return nil
        }
        
        let host = url.host ?? ""
        if host.contains("hdslb.com") || host.contains("biliapi.net") {
            let path = originalUrlString
            if path.contains("@") {
                return url
            }
            // Append Bilibili CDN server-side thumbnail resize parameters
            let optimized = "\(path)@\(targetPixelSize)w_\(targetPixelSize)h_1c.jpg"
            if let optimizedUrl = URL(string: optimized) {
                return optimizedUrl
            }
        }
        return url
    }
    
    /// Downsamples raw image data directly at decode time using ImageIO, avoiding full-resolution RAM allocation
    public static func downsample(imageData: Data, to pointSize: CGSize, scale: CGFloat = 3.0) -> UIImage? {
        let maxPixelSize = max(pointSize.width, pointSize.height) * scale
        
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return nil
        }
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}

// MARK: - Memory-Capped In-Memory Thumbnail Cache

@MainActor
public final class BiliThumbnailCache {
    public static let shared = BiliThumbnailCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        // Enforce strict 20 MB ceiling for in-memory thumbnail bitmaps
        cache.totalCostLimit = 20 * 1024 * 1024
        cache.countLimit = 150
    }
    
    public func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    public func setImage(_ image: UIImage, for url: URL, cost: Int) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - Memory-Efficient Cached Thumbnail View

public struct CachedThumbnailView<Placeholder: View>: View {
    let urlString: String?
    let targetSize: CGSize
    let placeholder: Placeholder
    
    @State private var loadedImage: UIImage?
    
    public init(
        urlString: String?,
        targetSize: CGSize = CGSize(width: 48, height: 48),
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.urlString = urlString
        self.targetSize = targetSize
        self.placeholder = placeholder()
    }
    
    public var body: some View {
        Group {
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let pixelSize = Int(max(targetSize.width, targetSize.height) * 3)
        guard let url = BiliImageOptimizer.thumbnailUrl(for: urlString, targetPixelSize: pixelSize) else {
            return
        }
        
        // 1. Check in-memory cache
        if let cached = await BiliThumbnailCache.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        
        // 2. Fetch data (hits URLCache on disk if already present)
        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            
            // 3. Decode & downsample off the main thread
            let downsampled = await Task.detached(priority: .userInitiated) {
                BiliImageOptimizer.downsample(imageData: data, to: targetSize, scale: 3.0)
            }.value
            
            guard let image = downsampled else { return }
            
            // 4. Cache in memory with cost
            let cost = Int(targetSize.width * 3 * targetSize.height * 3 * 4)
            await BiliThumbnailCache.shared.setImage(image, for: url, cost: cost)
            
            self.loadedImage = image
        } catch {
            // Placeholder remains visible on failure
        }
    }
}
