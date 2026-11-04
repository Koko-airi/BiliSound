import Foundation

public struct BiliVideoDetails: Codable {
    public let bvid: String
    public let cid: Int
    public let title: String
    public let uploader: String
    public let picUrl: String
    public let duration: TimeInterval
    public let pages: [BiliPage]
}

public struct BiliPage: Codable, Identifiable {
    public var id: Int { cid }
    public let cid: Int
    public let page: Int
    public let part: String
    public let duration: TimeInterval
}

public struct BiliAudioStreamInfo {
    public let qualityId: Int
    public let qualityDescription: String
    public let url: URL
    public let backupUrls: [URL]
    public let bandwidth: Int
    public let codecs: String
}

/// Bilibili Favorite Folder model representing a collection (created or collected)
public struct BiliFavFolder: Identifiable, Codable, Hashable {
    public let id: Int // media_id (mlid)
    public let fid: Int
    public let mid: Int
    public let title: String
    public let mediaCount: Int
    public let coverUrl: String?
    public let intro: String?
    public let isCollected: Bool
    
    public init(
        id: Int,
        fid: Int,
        mid: Int,
        title: String,
        mediaCount: Int,
        coverUrl: String? = nil,
        intro: String? = nil,
        isCollected: Bool = false
    ) {
        self.id = id
        self.fid = fid
        self.mid = mid
        self.title = title
        self.mediaCount = mediaCount
        self.coverUrl = coverUrl
        self.intro = intro
        self.isCollected = isCollected
    }
}

/// Bilibili Favorite Item/Resource model (video item inside a folder)
public struct BiliFavResource: Identifiable, Codable, Hashable {
    public let id: Int // aid
    public let bvid: String
    public let title: String
    public let cover: String
    public let duration: TimeInterval
    public let upperName: String
    public let upperMid: Int
    
    public init(
        id: Int,
        bvid: String,
        title: String,
        cover: String,
        duration: TimeInterval,
        upperName: String,
        upperMid: Int = 0
    ) {
        self.id = id
        self.bvid = bvid
        self.title = title
        self.cover = cover
        self.duration = duration
        self.upperName = upperName
        self.upperMid = upperMid
    }
}

public enum BiliAPIError: LocalizedError {
    case invalidURL
    case networkError(String)
    case apiError(code: Int, message: String)
    case noAudioStreamFound
    case decodingError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Bilibili URL or BV ID."
        case .networkError(let msg):
            return "Network connection error: \(msg)"
        case .apiError(let code, let msg):
            return "Bilibili API error [\(code)]: \(msg)"
        case .noAudioStreamFound:
            return "No pure audio stream found for this video."
        case .decodingError:
            return "Failed to parse Bilibili response."
        }
    }
}

/// Service to query Bilibili APIs for video metadata and extract pure audio DASH streams (Feature 1).
public final class BilibiliAPIService {
    public static let shared = BilibiliAPIService()
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Headers
    
    public static var defaultHeaders: [String: String] {
        var headers = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Referer": "https://www.bilibili.com",
            "Origin": "https://www.bilibili.com"
        ]
        let cookieStr = BiliAccountManager.currentCookieHeader()
        if !cookieStr.isEmpty {
            headers["Cookie"] = cookieStr
        }
        return headers
    }
    
    // MARK: - Fetch Video Details
    
    /// Fetches video parts, CID, title, and cover using the official player pagelist API (avoids WAF 412)
    public func fetchVideoDetails(bvid: String, pageIndex: Int = 1) async throws -> BiliVideoDetails {
        // Step 1: Use player/pagelist which is immune to WAF 412
        guard let pagelistUrl = URL(string: "https://api.bilibili.com/x/player/pagelist?bvid=\(bvid)") else {
            throw BiliAPIError.invalidURL
        }
        
        var request = URLRequest(url: pagelistUrl)
        request.httpMethod = "GET"
        for (key, value) in Self.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("https://www.bilibili.com/video/\(bvid)", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw BiliAPIError.networkError("Pagelist HTTP status \( (response as? HTTPURLResponse)?.statusCode ?? -1 )")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let pagesArray = json["data"] as? [[String: Any]],
              !pagesArray.isEmpty else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "Failed to find video parts"
            throw BiliAPIError.apiError(code: -1, message: msg)
        }
        
        var pages: [BiliPage] = []
        var resolvedTitle = "Bilibili Song"
        var firstPic = "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80"
        var totalDuration: TimeInterval = 0
        
        for item in pagesArray {
            let cid = item["cid"] as? Int ?? 0
            let page = item["page"] as? Int ?? 1
            let part = item["part"] as? String ?? ""
            let dur = item["duration"] as? TimeInterval ?? 0
            if totalDuration == 0 { totalDuration = dur }
            if resolvedTitle == "Bilibili Song" && !part.isEmpty {
                resolvedTitle = part
            }
            if let frame = item["first_frame"] as? String, !frame.isEmpty {
                firstPic = frame.replacingOccurrences(of: "http://", with: "https://")
            }
            pages.append(BiliPage(cid: cid, page: page, part: part, duration: dur))
        }
        
        let targetCid: Int
        if let targetPage = pages.first(where: { $0.page == pageIndex }) {
            targetCid = targetPage.cid
            if !targetPage.part.isEmpty { resolvedTitle = targetPage.part }
        } else if let first = pages.first {
            targetCid = first.cid
        } else {
            throw BiliAPIError.noAudioStreamFound
        }
        
        // Step 2: Try enriching title/uploader with view API if user is logged in (with graceful fallback)
        var uploader = "Bilibili Artist"
        if let viewUrl = URL(string: "https://api.bilibili.com/x/web-interface/view?bvid=\(bvid)") {
            var viewReq = URLRequest(url: viewUrl)
            for (key, value) in Self.defaultHeaders {
                viewReq.setValue(value, forHTTPHeaderField: key)
            }
            viewReq.setValue("https://www.bilibili.com/video/\(bvid)", forHTTPHeaderField: "Referer")
            if let (vData, vResp) = try? await session.data(for: viewReq),
               let vHttp = vResp as? HTTPURLResponse, vHttp.statusCode == 200,
               let vJson = try? JSONSerialization.jsonObject(with: vData) as? [String: Any],
               let vCode = vJson["code"] as? Int, vCode == 0,
               let vDataDict = vJson["data"] as? [String: Any] {
                if let fullTitle = vDataDict["title"] as? String, !fullTitle.isEmpty {
                    resolvedTitle = fullTitle
                }
                if let pic = vDataDict["pic"] as? String, !pic.isEmpty {
                    firstPic = pic.replacingOccurrences(of: "http://", with: "https://")
                }
                if let owner = vDataDict["owner"] as? [String: Any],
                   let ownerName = owner["name"] as? String, !ownerName.isEmpty {
                    uploader = ownerName
                }
            }
        }
        
        return BiliVideoDetails(
            bvid: bvid,
            cid: targetCid,
            title: resolvedTitle,
            uploader: uploader,
            picUrl: firstPic,
            duration: totalDuration,
            pages: pages
        )
    }
    
    // MARK: - Feature 1: Pure Audio Stream Extraction (No Video Loaded)
    
    /// Requests Bilibili DASH media streams and extracts pure audio stream URLs.
    /// Uses official player/playurl (without /wbi/) to avoid WAF 412 challenge.
    public func fetchAudioStream(bvid: String, cid: Int) async throws -> BiliAudioStreamInfo {
        // Use https://api.bilibili.com/x/player/playurl (fnval=16 specifies DASH audio streams)
        guard let url = URL(string: "https://api.bilibili.com/x/player/playurl?bvid=\(bvid)&cid=\(cid)&fnval=16") else {
            throw BiliAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in Self.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("https://www.bilibili.com/video/\(bvid)", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BiliAPIError.networkError("PlayURL HTTP status \(status)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BiliAPIError.decodingError
        }
        
        let code = json["code"] as? Int ?? -1
        if code != 0 {
            let msg = json["message"] as? String ?? "Unknown error"
            throw BiliAPIError.apiError(code: code, message: msg)
        }
        
        guard let dataDict = json["data"] as? [String: Any],
              let dash = dataDict["dash"] as? [String: Any],
              let audioList = dash["audio"] as? [[String: Any]],
              !audioList.isEmpty else {
            // Check if standard durl exists
            if let dataDict = json["data"] as? [String: Any],
               let durlList = dataDict["durl"] as? [[String: Any]],
               let firstDurl = durlList.first,
               let urlString = firstDurl["url"] as? String,
               let streamUrl = URL(string: urlString) {
                return BiliAudioStreamInfo(
                    qualityId: 30216,
                    qualityDescription: "Standard MP4 Audio",
                    url: streamUrl,
                    backupUrls: [],
                    bandwidth: 128000,
                    codecs: "mp4a"
                )
            }
            throw BiliAPIError.noAudioStreamFound
        }
        
        // Sort audio streams by quality ID descending (30280: 192k > 30232: 132k > 30216: 64k)
        let sortedAudios = audioList.sorted {
            ($0["id"] as? Int ?? 0) > ($1["id"] as? Int ?? 0)
        }
        
        guard let bestAudio = sortedAudios.first,
              let baseUrlString = bestAudio["baseUrl"] as? String,
              let baseUrl = URL(string: baseUrlString) else {
            throw BiliAPIError.noAudioStreamFound
        }
        
        let qualityId = bestAudio["id"] as? Int ?? 30280
        let bandwidth = bestAudio["bandwidth"] as? Int ?? 192000
        let codecs = bestAudio["codecs"] as? String ?? "mp4a.40.2"
        
        var backupUrls: [URL] = []
        if let backups = bestAudio["backupUrl"] as? [String] {
            backupUrls = backups.compactMap { URL(string: $0) }
        }
        
        let qualityDesc: String
        switch qualityId {
        case 30280: qualityDesc = "192kbps HQ Audio"
        case 30232: qualityDesc = "132kbps Standard"
        case 30216: qualityDesc = "64kbps Low Data"
        default: qualityDesc = "\(bandwidth / 1000)kbps DASH Audio"
        }
        
        return BiliAudioStreamInfo(
            qualityId: qualityId,
            qualityDescription: qualityDesc,
            url: baseUrl,
            backupUrls: backupUrls,
            bandwidth: bandwidth,
            codecs: codecs
        )
    }
    
    // MARK: - User Favorite Playlists Integration
    
    /// Fetches all favorite folders created by the user (requires login mid)
    public func fetchCreatedFavoriteFolders(mid: Int) async throws -> [BiliFavFolder] {
        guard let url = URL(string: "https://api.bilibili.com/x/v3/fav/folder/created/list-all?up_mid=\(mid)") else {
            throw BiliAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in Self.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BiliAPIError.networkError("Fetch folders HTTP status \(status)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int else {
            throw BiliAPIError.decodingError
        }
        
        if code != 0 {
            let msg = json["message"] as? String ?? "Failed to fetch favorite folders"
            throw BiliAPIError.apiError(code: code, message: msg)
        }
        
        guard let dataDict = json["data"] as? [String: Any],
              let list = dataDict["list"] as? [[String: Any]] else {
            return []
        }
        
        var folders: [BiliFavFolder] = []
        for item in list {
            guard let id = item["id"] as? Int,
                  let fid = item["fid"] as? Int,
                  let title = item["title"] as? String else { continue }
            
            let itemMid = item["mid"] as? Int ?? mid
            let mediaCount = item["media_count"] as? Int ?? 0
            let intro = item["intro"] as? String
            let cover = item["cover"] as? String
            
            let cleanCover = cover?.replacingOccurrences(of: "http://", with: "https://")
            folders.append(BiliFavFolder(
                id: id,
                fid: fid,
                mid: itemMid,
                title: title,
                mediaCount: mediaCount,
                coverUrl: cleanCover,
                intro: intro,
                isCollected: false
            ))
        }
        return folders
    }
    
    /// Fetches folders collected (subscribed) by the user
    public func fetchCollectedFavoriteFolders(mid: Int, page: Int = 1, pageSize: Int = 20) async throws -> [BiliFavFolder] {
        guard let url = URL(string: "https://api.bilibili.com/x/v3/fav/folder/collected/list?up_mid=\(mid)&pn=\(page)&ps=\(pageSize)&platform=web") else {
            throw BiliAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in Self.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataDict = json["data"] as? [String: Any],
              let list = dataDict["list"] as? [[String: Any]] else {
            return []
        }
        
        var folders: [BiliFavFolder] = []
        for item in list {
            guard let id = item["id"] as? Int,
                  let title = item["title"] as? String else { continue }
            
            let fid = item["fid"] as? Int ?? 0
            let itemMid = item["mid"] as? Int ?? 0
            let mediaCount = item["media_count"] as? Int ?? 0
            let intro = item["intro"] as? String
            let cover = item["cover"] as? String
            
            let cleanCover = cover?.replacingOccurrences(of: "http://", with: "https://")
            folders.append(BiliFavFolder(
                id: id,
                fid: fid,
                mid: itemMid,
                title: title,
                mediaCount: mediaCount,
                coverUrl: cleanCover,
                intro: intro,
                isCollected: true
            ))
        }
        return folders
    }
    
    /// Fetches items inside a specific favorite folder
    public func fetchFavoriteResources(mediaId: Int, page: Int = 1, pageSize: Int = 20) async throws -> (resources: [BiliFavResource], hasMore: Bool, folderCover: String?) {
        guard let url = URL(string: "https://api.bilibili.com/x/v3/fav/resource/list?media_id=\(mediaId)&pn=\(page)&ps=\(pageSize)&platform=web") else {
            throw BiliAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in Self.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BiliAPIError.networkError("Fetch resources HTTP status \(status)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int else {
            throw BiliAPIError.decodingError
        }
        
        if code != 0 {
            let msg = json["message"] as? String ?? "Failed to fetch playlist items"
            throw BiliAPIError.apiError(code: code, message: msg)
        }
        
        guard let dataDict = json["data"] as? [String: Any] else {
            return ([], false, nil)
        }
        
        let hasMore = dataDict["has_more"] as? Bool ?? false
        var folderCover: String? = nil
        if let info = dataDict["info"] as? [String: Any],
           let cover = info["cover"] as? String, !cover.isEmpty {
            folderCover = cover.replacingOccurrences(of: "http://", with: "https://")
        }
        
        guard let medias = dataDict["medias"] as? [[String: Any]] else {
            return ([], hasMore, folderCover)
        }
        
        var resources: [BiliFavResource] = []
        for item in medias {
            // attr == 1 means deleted or invalid
            if let attr = item["attr"] as? Int, attr != 0 {
                continue
            }
            guard let id = item["id"] as? Int,
                  let title = item["title"] as? String else { continue }
            
            let bvid = (item["bvid"] as? String) ?? (item["bv_id"] as? String) ?? ""
            guard !bvid.isEmpty else { continue }
            
            let cover = (item["cover"] as? String ?? "").replacingOccurrences(of: "http://", with: "https://")
            let duration = item["duration"] as? TimeInterval ?? 0
            
            var upperName = "Bilibili Artist"
            var upperMid = 0
            if let upper = item["upper"] as? [String: Any] {
                upperName = upper["name"] as? String ?? upperName
                upperMid = upper["mid"] as? Int ?? 0
            }
            
            resources.append(BiliFavResource(
                id: id,
                bvid: bvid,
                title: title,
                cover: cover,
                duration: duration,
                upperName: upperName,
                upperMid: upperMid
            ))
        }
        
        return (resources, hasMore, folderCover)
    }
    
    /// Imports a complete favorite folder into a local BiliSound Playlist model
    public func importFolderAsPlaylist(
        folder: BiliFavFolder,
        maxItems: Int = 100,
        progressHandler: ((_ loaded: Int, _ total: Int) -> Void)? = nil
    ) async throws -> Playlist {
        var allResources: [BiliFavResource] = []
        var page = 1
        var hasMore = true
        var resolvedCover: String? = folder.coverUrl
        
        let targetCount = min(folder.mediaCount > 0 ? folder.mediaCount : maxItems, maxItems)
        
        while hasMore && allResources.count < maxItems {
            let result = try await fetchFavoriteResources(mediaId: folder.id, page: page, pageSize: 20)
            if resolvedCover == nil || resolvedCover?.isEmpty == true {
                resolvedCover = result.folderCover
            }
            allResources.append(contentsOf: result.resources)
            progressHandler?(allResources.count, targetCount)
            
            if !result.hasMore || result.resources.isEmpty {
                break
            }
            page += 1
            
            // Respectful pacing between Bilibili pagination requests
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Convert BiliFavResources to Songs and SongVersions
        var songs: [Song] = []
        for resource in allResources {
            let version = SongVersion(
                name: "Original Video Audio",
                bvid: resource.bvid,
                uploader: resource.upperName,
                duration: resource.duration,
                audioQuality: "192kbps DASH",
                picUrl: resource.cover
            )
            
            let song = Song(
                title: resource.title,
                artist: resource.upperName,
                artworkUrl: resource.cover,
                versions: [version]
            )
            songs.append(song)
        }
        
        if resolvedCover == nil, let firstSongCover = songs.first?.artworkUrl {
            resolvedCover = firstSongCover
        }
        
        return Playlist(
            name: folder.title,
            description: folder.intro ?? "Imported from Bilibili Favorites (\(songs.count) songs)",
            coverUrl: resolvedCover,
            songs: songs
        )
    }
}
