import Foundation

/// Utility to parse and extract Bilibili BV IDs and page indices from strings and URLs
public struct BilibiliURLParser {
    
    public struct ParsedResult: Equatable {
        public let bvid: String
        public let pageIndex: Int
    }
    
    /// Regular expression matching standard Bilibili BV IDs (BV1 followed by 9 alphanumeric chars)
    private static let bvRegex = try? NSRegularExpression(pattern: "(BV1[0-9a-zA-Z]{9})", options: .caseInsensitive)
    
    /// Parses any user input (full URL, short link, or raw BV identifier)
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
    
    /// Validates whether a string is a valid BV ID
    public static func isValidBVID(_ text: String) -> Bool {
        return parse(input: text) != nil
    }
}
