import Foundation
import AVFoundation

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
