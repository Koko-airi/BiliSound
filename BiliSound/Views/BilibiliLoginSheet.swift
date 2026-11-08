import SwiftUI
import WebKit

/// Sheet allowing users to log in to their Bilibili account via official Web Login (QR code, SMS, password)
/// or manual SESSDATA input to unlock VIP high-bitrate audio and avoid WAF restrictions.
@MainActor
public struct BilibiliLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var accountManager = BiliAccountManager.shared
    
    @State private var selectedTab: Int = 0
    @State private var manualSessdata: String = ""
    @State private var manualBiliJct: String = ""
    @State private var manualDedeUserId: String = ""
    @State private var manualBuvid3: String = ""
    @State private var isVerifyingManual: Bool = false
    @State private var manualError: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Login Method", selection: $selectedTab) {
                    Text("Official Web Login").tag(0)
                    Text("Manual Cookie Input").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if selectedTab == 0 {
                    webLoginSection
                } else {
                    manualInputSection
                }
            }
            .navigationTitle("Bilibili Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Web Login Section
    
    private var webLoginSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Official Bilibili Login • Supports App QR Scan & SMS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            
            BiliWebView(onCookiesCaptured: { sessdata, biliJct, dedeUserId, buvid3 in
                accountManager.saveCookies(
                    sessdata: sessdata,
                    biliJct: biliJct,
                    dedeUserId: dedeUserId,
                    buvid3: buvid3
                )
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                dismiss()
            })
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    // MARK: - Manual Input Section
    
    private var manualInputSection: some View {
        Form {
            Section(header: Text("Account Session Cookies")) {
                Text("Paste your SESSDATA cookie from bilibili.com to authenticate without webview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("SESSDATA (Required)", text: $manualSessdata)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("bili_jct / CSRF (Optional)", text: $manualBiliJct)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("DedeUserID (Optional)", text: $manualDedeUserId)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            if let err = manualError {
                Section {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Section {
                Button(action: verifyAndSaveManual) {
                    HStack {
                        Spacer()
                        if isVerifyingManual {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text("Save & Log In")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .disabled(manualSessdata.trimmingCharacters(in: .whitespaces).isEmpty || isVerifyingManual)
            }
            
            Section(header: Text("How to get SESSDATA")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Open bilibili.com in any desktop browser and log in.")
                    Text("2. Press F12 (Developer Tools) -> Application -> Cookies -> bilibili.com.")
                    Text("3. Copy the value of the 'SESSDATA' cookie and paste it above.")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private func verifyAndSaveManual() {
        let cleanSess = manualSessdata.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSess.isEmpty else { return }
        
        isVerifyingManual = true
        manualError = nil
        
        accountManager.saveCookies(
            sessdata: cleanSess,
            biliJct: manualBiliJct.trimmingCharacters(in: .whitespacesAndNewlines),
            dedeUserId: manualDedeUserId.trimmingCharacters(in: .whitespacesAndNewlines),
            buvid3: manualBuvid3.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        Task {
            await accountManager.fetchUserInfo()
            await MainActor.run {
                isVerifyingManual = false
                if accountManager.isLoggedIn {
                    dismiss()
                } else {
                    manualError = "Could not verify SESSDATA. Please check that the cookie is valid and not expired."
                }
            }
        }
    }
}

// MARK: - WKWebView Wrapper to intercept Cookies

struct BiliWebView: UIViewRepresentable {
    let onCookiesCaptured: (String, String, String, String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCookiesCaptured: onCookiesCaptured)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Load official mobile login page
        if let url = URL(string: "https://passport.bilibili.com/login") {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            webView.load(req)
        }
        
        context.coordinator.startMonitoring(cookieStore: webView.configuration.websiteDataStore.httpCookieStore)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        let onCookiesCaptured: (String, String, String, String) -> Void
        private var cookieStore: WKHTTPCookieStore?
        private var hasTriggered = false
        
        init(onCookiesCaptured: @escaping (String, String, String, String) -> Void) {
            self.onCookiesCaptured = onCookiesCaptured
        }
        
        func startMonitoring(cookieStore: WKHTTPCookieStore) {
            self.cookieStore = cookieStore
            cookieStore.add(self)
        }
        
        deinit {
            cookieStore?.remove(self)
        }
        
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            checkCookies(in: cookieStore)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
        }
        
        private func checkCookies(in store: WKHTTPCookieStore) {
            guard !hasTriggered else { return }
            
            store.getAllCookies { [weak self] cookies in
                guard let self = self, !self.hasTriggered else { return }
                
                var sessdata = ""
                var biliJct = ""
                var dedeUserId = ""
                var buvid3 = ""
                
                for c in cookies {
                    if c.name == "SESSDATA" { sessdata = c.value }
                    if c.name == "bili_jct" { biliJct = c.value }
                    if c.name == "DedeUserID" { dedeUserId = c.value }
                    if c.name == "buvid3" { buvid3 = c.value }
                }
                
                if !sessdata.isEmpty {
                    self.hasTriggered = true
                    DispatchQueue.main.async {
                        self.onCookiesCaptured(sessdata, biliJct, dedeUserId, buvid3)
                    }
                }
            }
        }
    }
}
