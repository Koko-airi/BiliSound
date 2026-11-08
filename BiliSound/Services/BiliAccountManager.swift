import Foundation
import Combine

/// Manages Bilibili account authentication, session cookies, and user profile.
/// Enables authenticated API access to unlock high-bitrate audio, prevent WAF rate-limiting,
/// and access user collections.
@MainActor
public final class BiliAccountManager: ObservableObject {
    public static let shared = BiliAccountManager()
    
    // MARK: - Published State
    
    @Published public private(set) var isLoggedIn: Bool = false
    @Published public private(set) var uname: String = "Not Logged In"
    @Published public private(set) var face: String? = nil
    @Published public private(set) var mid: Int? = nil
    @Published public private(set) var vipType: Int = 0
    @Published public private(set) var vipLabel: String = "Free Account"
    @Published public private(set) var sessdata: String = ""
    @Published public private(set) var biliJct: String = ""
    @Published public private(set) var dedeUserId: String = ""
    @Published public private(set) var buvid3: String = ""
    
    @Published public var isFetchingProfile: Bool = false
    @Published public var errorMessage: String? = nil
    
    // MARK: - Persistence Keys
    
    private static let kSessdata = "bili_sessdata"
    private static let kBiliJct = "bili_jct"
    private static let kDedeUserId = "bili_dede_user_id"
    private static let kBuvid3 = "bili_buvid3"
    private static let kUname = "bili_uname"
    private static let kFace = "bili_face"
    private static let kMid = "bili_mid"
    private static let kVipType = "bili_vip_type"
    
    private init() {
        loadPersistedState()
        if !sessdata.isEmpty {
            Task {
                await fetchUserInfo()
            }
        }
    }
    
    // MARK: - Cookie Header Construction
    
    /// Thread-safe nonisolated function to construct the Cookie header without MainActor constraints
    public static nonisolated func currentCookieHeader() -> String {
        let defaults = UserDefaults.standard
        let sess = defaults.string(forKey: kSessdata) ?? ""
        let jct = defaults.string(forKey: kBiliJct) ?? ""
        let dede = defaults.string(forKey: kDedeUserId) ?? ""
        let buvid = defaults.string(forKey: kBuvid3) ?? "9C300E53-8E87-7A03-7F00-F3F78070DA7A62591infoc"
        
        var cookies: [String] = []
        if !sess.isEmpty { cookies.append("SESSDATA=\(sess)") }
        if !jct.isEmpty { cookies.append("bili_jct=\(jct)") }
        if !dede.isEmpty { cookies.append("DedeUserID=\(dede)") }
        if !buvid.isEmpty { cookies.append("buvid3=\(buvid)") }
        return cookies.joined(separator: "; ")
    }
    
    /// Returns the combined Cookie string for HTTP request headers
    public var cookieHeaderString: String {
        Self.currentCookieHeader()
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        self.sessdata = defaults.string(forKey: Self.kSessdata) ?? ""
        self.biliJct = defaults.string(forKey: Self.kBiliJct) ?? ""
        self.dedeUserId = defaults.string(forKey: Self.kDedeUserId) ?? ""
        self.buvid3 = defaults.string(forKey: Self.kBuvid3) ?? ""
        self.uname = defaults.string(forKey: Self.kUname) ?? "Not Logged In"
        self.face = defaults.string(forKey: Self.kFace)
        self.mid = defaults.object(forKey: Self.kMid) as? Int
        self.vipType = defaults.integer(forKey: Self.kVipType)
        self.isLoggedIn = !self.sessdata.isEmpty
        updateVipLabel()
    }
    
    public func saveCookies(
        sessdata: String,
        biliJct: String = "",
        dedeUserId: String = "",
        buvid3: String = ""
    ) {
        let defaults = UserDefaults.standard
        self.sessdata = sessdata
        self.biliJct = biliJct
        self.dedeUserId = dedeUserId
        if !buvid3.isEmpty { self.buvid3 = buvid3 }
        self.isLoggedIn = !sessdata.isEmpty
        
        defaults.set(sessdata, forKey: Self.kSessdata)
        defaults.set(biliJct, forKey: Self.kBiliJct)
        defaults.set(dedeUserId, forKey: Self.kDedeUserId)
        defaults.set(self.buvid3, forKey: Self.kBuvid3)
        
        Task {
            await fetchUserInfo()
        }
    }
    
    // MARK: - Fetch User Profile from Bilibili
    
    public func fetchUserInfo() async {
        guard !sessdata.isEmpty else {
            self.isLoggedIn = false
            return
        }
        
        isFetchingProfile = true
        errorMessage = nil
        
        guard let url = URL(string: "https://api.bilibili.com/x/web-interface/nav") else {
            isFetchingProfile = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(cookieHeaderString, forHTTPHeaderField: "Cookie")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                isFetchingProfile = false
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let code = json["code"] as? Int else {
                isFetchingProfile = false
                return
            }
            
            if code == 0, let dataDict = json["data"] as? [String: Any] {
                self.isLoggedIn = true
                self.uname = dataDict["uname"] as? String ?? "Bilibili User"
                self.face = dataDict["face"] as? String
                self.mid = dataDict["mid"] as? Int
                
                if let vip = dataDict["vip"] as? [String: Any] {
                    self.vipType = vip["type"] as? Int ?? 0
                    if let labelDict = vip["label"] as? [String: Any],
                       let text = labelDict["text"] as? String, !text.isEmpty {
                        self.vipLabel = text
                    } else {
                        updateVipLabel()
                    }
                }
                
                let defaults = UserDefaults.standard
                defaults.set(self.uname, forKey: BiliAccountManager.kUname)
                defaults.set(self.face, forKey: BiliAccountManager.kFace)
                defaults.set(self.mid, forKey: BiliAccountManager.kMid)
                defaults.set(self.vipType, forKey: BiliAccountManager.kVipType)
            } else if code == -101 {
                // Session expired or invalid
                self.isLoggedIn = false
                self.errorMessage = "Session expired. Please log in again."
            }
        } catch {
            print("Failed to fetch Bilibili user profile: \(error)")
        }
        
        isFetchingProfile = false
    }
    
    private func updateVipLabel() {
        switch vipType {
        case 1: vipLabel = "VIP Member (月度大会员)"
        case 2: vipLabel = "Yearly VIP (年度大会员)"
        default: vipLabel = "Standard Account"
        }
    }
    
    // MARK: - Logout
    
    public func logout() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: BiliAccountManager.kSessdata)
        defaults.removeObject(forKey: BiliAccountManager.kBiliJct)
        defaults.removeObject(forKey: BiliAccountManager.kDedeUserId)
        defaults.removeObject(forKey: BiliAccountManager.kUname)
        defaults.removeObject(forKey: BiliAccountManager.kFace)
        defaults.removeObject(forKey: BiliAccountManager.kMid)
        defaults.removeObject(forKey: BiliAccountManager.kVipType)
        
        self.sessdata = ""
        self.biliJct = ""
        self.dedeUserId = ""
        self.uname = "Not Logged In"
        self.face = nil
        self.mid = nil
        self.vipType = 0
        self.vipLabel = "Free Account"
        self.isLoggedIn = false
        
        // Clear HTTPCookieStorage
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies where cookie.domain.contains("bilibili.com") {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}
