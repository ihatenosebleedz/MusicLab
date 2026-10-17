import Foundation

public enum MusicLabDeepLink: Equatable, Sendable {
    case importURL(String)

    public static func parse(_ url: URL) -> MusicLabDeepLink? {
        guard let scheme = url.scheme?.lowercased(), scheme == "musiclab" else {
            return nil
        }
        
        // 1. Standard query parameter: musiclab://import?url=... or musiclab://open?url=...
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItem = components.queryItems?.first(where: { $0.name.lowercased() == "url" }),
           let value = queryItem.value?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return .importURL(cleanTargetURL(value))
        }
        
        // 2. Direct formats without standard query parameter, e.g.:
        // musiclab://music.apple.com/...
        // musiclab://https://music.apple.com/...
        // musiclab://import/https://music.apple.com/...
        let raw = url.absoluteString
        let prefix = "\(scheme)://"
        guard raw.lowercased().hasPrefix(prefix) else { return nil }
        var remainder = String(raw.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If remainder starts with "import?" or "open?", handle unescaped query string
        if remainder.lowercased().hasPrefix("import?") || remainder.lowercased().hasPrefix("open?") {
            if let qIdx = remainder.firstIndex(of: "?") {
                let queryPart = remainder[remainder.index(after: qIdx)...]
                for item in queryPart.split(separator: "&") {
                    let parts = item.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 && parts[0].lowercased() == "url" {
                        let decoded = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                        if !decoded.isEmpty {
                            return .importURL(cleanTargetURL(decoded))
                        }
                    }
                }
            }
        }
        
        // Strip leading "import/" or "open/" if present
        if remainder.lowercased().hasPrefix("import/") {
            remainder = String(remainder.dropFirst("import/".count))
        } else if remainder.lowercased().hasPrefix("open/") {
            remainder = String(remainder.dropFirst("open/".count))
        }
        
        if remainder.lowercased().hasPrefix("http://") || remainder.lowercased().hasPrefix("https://") {
            return .importURL(cleanTargetURL(remainder))
        } else if remainder.lowercased().hasPrefix("music.apple.com") {
            return .importURL(cleanTargetURL("https://" + remainder))
        }
        
        return nil
    }
    
    /// Cleans target string: if text has leading/trailing fluff or whitespace, extracts the URL.
    private static func cleanTargetURL(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "https://music.apple.com", options: .caseInsensitive) {
            let candidate = String(trimmed[range.lowerBound...])
            if let spaceIdx = candidate.firstIndex(where: { $0.isWhitespace }) {
                return String(candidate[..<spaceIdx])
            }
            return candidate
        }
        if let range = trimmed.range(of: "http://music.apple.com", options: .caseInsensitive) {
            let candidate = String(trimmed[range.lowerBound...])
            if let spaceIdx = candidate.firstIndex(where: { $0.isWhitespace }) {
                return String(candidate[..<spaceIdx])
            }
            return candidate
        }
        return trimmed
    }
}
