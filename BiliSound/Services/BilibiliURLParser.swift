import Foundation

/// Utility to parse and extract Bilibili BV IDs and page indices from strings, URLs, and b23.tv short links
public struct BilibiliURLParser {
    
    public struct ParsedResult: Equatable {
        public let bvid: String
        public let pageIndex: Int
        
        public init(bvid: String, pageIndex: Int = 1) {
            self.bvid = bvid
            self.pageIndex = pageIndex
        }
    }
    
    /// Regular expression matching standard Bilibili BV IDs (BV1 followed by 9 alphanumeric chars)
    private static let bvRegex = try? NSRegularExpression(pattern: "(BV1[0-9a-zA-Z]{9})", options: .caseInsensitive)
    
    /// Regular expression matching b23.tv short links (e.g. b23.tv/xyz, https://b23.tv/xyz)
    private static let b23Regex = try? NSRegularExpression(
        pattern: "(https?:\\/\\/)?(www\\.)?b23\\.tv\\/([a-zA-Z0-9_-]+)",
        options: .caseInsensitive
    )
    
    /// Synchronously parses user input if it contains a direct BV ID (full URL or raw BV)
    public static func parse(input: String) -> ParsedResult? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard let match = bvRegex?.firstMatch(in: trimmed, options: [], range: range),
              let bvRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }
        
        let bvid = String(trimmed[bvRange])
        
        // Extract page parameter `p=X` if present in URL
        var pageIndex = 1
        if let url = URL(string: trimmed),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pQuery = components.queryItems?.first(where: { $0.name == "p" })?.value,
           let parsedP = Int(pQuery), parsedP > 0 {
            pageIndex = parsedP
        }
        
        return ParsedResult(bvid: bvid, pageIndex: pageIndex)
    }
    
    /// Asynchronously parses user input. If a direct BV ID is present, returns immediately;
    /// if a b23.tv short link is detected, resolves the HTTP 302 redirect to extract the destination BV ID.
    public static func parseAsync(input: String) async -> ParsedResult? {
        // 1. Fast path: Direct BV ID in text
        if let direct = parse(input: input) {
            return direct
        }
        
        // 2. Detect b23.tv short link in input text (e.g. pasted with Chinese share title text)
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard let match = b23Regex?.firstMatch(in: trimmed, options: [], range: range),
              let matchedRange = Range(match.range, in: trimmed) else {
            return nil
        }
        
        var shortLinkString = String(trimmed[matchedRange])
        if !shortLinkString.lowercased().hasPrefix("http://") && !shortLinkString.lowercased().hasPrefix("https://") {
            shortLinkString = "https://" + shortLinkString
        }
        
        guard let shortUrl = URL(string: shortLinkString) else { return nil }
        
        // Check for explicit p=X in original input
        var extractedPage = 1
        if let components = URLComponents(string: trimmed),
           let pQuery = components.queryItems?.first(where: { $0.name == "p" })?.value,
           let pVal = Int(pQuery), pVal > 0 {
            extractedPage = pVal
        }
        
        // 3. Resolve the redirect via lightweight URLSession
        if let redirectedResult = await resolveRedirect(url: shortUrl) {
            let finalPage = redirectedResult.pageIndex > 1 ? redirectedResult.pageIndex : extractedPage
            return ParsedResult(bvid: redirectedResult.bvid, pageIndex: finalPage)
        }
        
        return nil
    }
    
    /// Resolves an HTTP redirect destination without downloading the target webpage
    private static func resolveRedirect(url: URL) async -> ParsedResult? {
        let delegate = RedirectCapturingDelegate()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await session.data(for: request)
            if let destUrl = delegate.redirectedURL ?? (response as? HTTPURLResponse)?.url {
                return parse(input: destUrl.absoluteString)
            }
        } catch {
            // If the delegate cancelled redirection to save bandwidth, redirectedURL is already captured
            if let destUrl = delegate.redirectedURL {
                return parse(input: destUrl.absoluteString)
            }
        }
        
        return nil
    }
    
    /// Validates whether a string is a valid BV ID
    public static func isValidBVID(_ text: String) -> Bool {
        return parse(input: text) != nil
    }
}

// MARK: - Redirect Capturing Delegate

private final class RedirectCapturingDelegate: NSObject, URLSessionTaskDelegate {
    var redirectedURL: URL?
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let reqUrl = request.url {
            self.redirectedURL = reqUrl
        } else if let location = response.allHeaderFields["Location"] as? String,
                  let locUrl = URL(string: location) {
            self.redirectedURL = locUrl
        }
        // Cancel the task once redirect location is captured to avoid downloading full HTML
        completionHandler(nil)
    }
}
