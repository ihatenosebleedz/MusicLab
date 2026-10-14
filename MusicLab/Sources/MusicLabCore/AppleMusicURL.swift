import Foundation

public enum AppleMusicURLError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case invalidHost(String)
    case unsupportedResourceType(String)
    case missingIdentifier
    case missingStorefront
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided string is not a valid URL."
        case .invalidHost(let host):
            return "Host '\(host)' is not recognized as Apple Music. Expected 'music.apple.com'."
        case .unsupportedResourceType(let type):
            return "Resource type '\(type)' is not supported for import. Supported types: album, song, playlist, artist."
        case .missingIdentifier:
            return "The Apple Music URL is missing a valid resource ID."
        case .missingStorefront:
            return "The Apple Music URL is missing a storefront code (e.g. 'us')."
        }
    }
}

public enum AppleMusicResourceType: String, Codable, CaseIterable, Sendable {
    case album = "album"
    case song = "song"
    case playlist = "playlist"
    case artist = "artist"
    case musicVideo = "music-video"
    
    public var apiCatalogType: String {
        switch self {
        case .album: return "albums"
        case .song: return "songs"
        case .playlist: return "playlists"
        case .artist: return "artists"
        case .musicVideo: return "music-videos"
        }
    }
}

public struct AppleMusicURL: Equatable, Sendable {
    public let originalURL: URL
    public let storefront: String
    public let resourceType: AppleMusicResourceType
    public let slug: String?
    public let identifier: String
    public let trackIdentifier: String?
    
    public var isTrackWithinAlbum: Bool {
        resourceType == .album && trackIdentifier != nil
    }
    
    public var effectiveResourceType: AppleMusicResourceType {
        if isTrackWithinAlbum {
            return .song
        }
        return resourceType
    }
    
    public var effectiveIdentifier: String {
        if let trackId = trackIdentifier, resourceType == .album {
            return trackId
        }
        return identifier
    }
    
    public static func parse(_ urlString: String) throws -> AppleMusicURL {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AppleMusicURLError.invalidURL
        }
        return try parse(url)
    }
    
    public static func parse(_ url: URL) throws -> AppleMusicURL {
        guard let host = url.host?.lowercased(),
              host == "music.apple.com" || host.hasSuffix(".music.apple.com") else {
            throw AppleMusicURLError.invalidHost(url.host ?? "unknown")
        }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        // Expected format: [storefront, type, slug, id] or [storefront, type, id]
        guard pathComponents.count >= 2 else {
            throw AppleMusicURLError.missingStorefront
        }
        
        let storefront = pathComponents[0].lowercased()
        guard storefront.count == 2 || storefront.count == 3 else {
            throw AppleMusicURLError.missingStorefront
        }
        
        let rawType = pathComponents[1].lowercased()
        guard let resourceType = AppleMusicResourceType(rawValue: rawType) else {
            throw AppleMusicURLError.unsupportedResourceType(rawType)
        }
        
        var slug: String? = nil
        let identifier: String
        
        if pathComponents.count == 3 {
            // Format: /us/album/1781290351
            identifier = pathComponents[2]
        } else if pathComponents.count >= 4 {
            // Format: /us/album/gnx/1781290351
            slug = pathComponents[2]
            identifier = pathComponents[3]
        } else {
            throw AppleMusicURLError.missingIdentifier
        }
        
        guard !identifier.isEmpty else {
            throw AppleMusicURLError.missingIdentifier
        }
        
        // Check for ?i=1781290352 song query parameter on album URLs
        var trackIdentifier: String? = nil
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            trackIdentifier = queryItems.first(where: { $0.name.lowercased() == "i" })?.value
        }
        
        return AppleMusicURL(
            originalURL: url,
            storefront: storefront,
            resourceType: resourceType,
            slug: slug,
            identifier: identifier,
            trackIdentifier: trackIdentifier
        )
    }
}
