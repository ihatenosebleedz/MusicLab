import Foundation

#if !os(Linux)
public actor AppleMusicClient {
    private var cachedToken: String?
    private var tokenExpiry: Date?
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Web Token Management
    
    /// Retrieves a public anonymous web token directly from Apple Music web assets.
    /// This is the same token mechanism used by amdl and web players, requiring zero developer secrets.
    public func fetchWebToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let token = cachedToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        
        guard let mainUrl = URL(string: "https://music.apple.com") else {
            throw AppleMusicURLError.invalidURL
        }
        
        var mainReq = URLRequest(url: mainUrl)
        mainReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        let (htmlData, _) = try await session.data(for: mainReq)
        guard let html = String(data: htmlData, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        // Find index JS script reference: /assets/index~...js
        guard let jsPathMatch = html.range(of: #"/assets/index~[^/"]+\.js"#, options: .regularExpression) else {
            throw URLError(.resourceUnavailable)
        }
        let jsPath = String(html[jsPathMatch])
        
        guard let jsUrl = URL(string: "https://music.apple.com\(jsPath)") else {
            throw AppleMusicURLError.invalidURL
        }
        
        let (jsData, _) = try await session.data(from: jsUrl)
        guard let jsContent = String(data: jsData, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        // Extract JWT token: eyJ...
        guard let jwtMatch = jsContent.range(of: #"eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+"#, options: .regularExpression) else {
            throw URLError(.userAuthenticationRequired)
        }
        let token = String(jsContent[jwtMatch])
        
        self.cachedToken = token
        // Cache token for 24 hours
        self.tokenExpiry = Date().addingTimeInterval(24 * 3600)
        return token
    }
    
    // MARK: - Catalog Search
    
    public func search(
        query: String,
        types: [AppleMusicResourceType] = [.album, .song],
        storefront: String = "us",
        limit: Int = 20
    ) async throws -> [CatalogItem] {
        let token = try await fetchWebToken()
        
        var components = URLComponents(string: "https://amp-api.music.apple.com/v1/catalog/\(storefront)/search")!
        let typesParam = types.map(\.apiCatalogType).joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "types", value: typesParam),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "l", value: "en-US")
        ]
        
        guard let url = components.url else {
            throw AppleMusicURLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://music.apple.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            // Token expired; force refresh and retry once
            let newToken = try await fetchWebToken(forceRefresh: true)
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, _) = try await session.data(for: request)
            return try parseSearchResponse(retryData)
        }
        
        return try parseSearchResponse(data)
    }
    
    // MARK: - Parsing Helpers
    
    nonisolated public func parseSearchResponse(_ data: Data) throws -> [CatalogItem] {
        return try AppleMusicParsing.parseSearchResponse(data)
    }
    
    nonisolated public func convertResourceToCatalogItem(_ resource: AMResource, type: CatalogType) -> CatalogItem {
        return AppleMusicParsing.convertResourceToCatalogItem(resource, type: type)
    }
}
#else
// Linux environment (no FoundationNetworking dependency to avoid Void Linux curl symbol mismatch)
public struct AppleMusicClient: Sendable {
    public init() {}
    
    public func parseSearchResponse(_ data: Data) throws -> [CatalogItem] {
        return try AppleMusicParsing.parseSearchResponse(data)
    }
    
    public func convertResourceToCatalogItem(_ resource: AMResource, type: CatalogType) -> CatalogItem {
        return AppleMusicParsing.convertResourceToCatalogItem(resource, type: type)
    }
}
#endif

public enum AppleMusicParsing {
    public static func parseSearchResponse(_ data: Data) throws -> [CatalogItem] {
        let response = try JSONDecoder().decode(AMSearchResponse.self, from: data)
        var results: [CatalogItem] = []
        
        if let albums = response.results.albums?.data {
            for item in albums {
                results.append(convertResourceToCatalogItem(item, type: .album))
            }
        }
        
        if let songs = response.results.songs?.data {
            for item in songs {
                results.append(convertResourceToCatalogItem(item, type: .song))
            }
        }
        
        if let playlists = response.results.playlists?.data {
            for item in playlists {
                results.append(convertResourceToCatalogItem(item, type: .playlist))
            }
        }
        
        return results
    }
    
    public static func convertResourceToCatalogItem(_ resource: AMResource, type: CatalogType) -> CatalogItem {
        let attrs = resource.attributes
        let artworkUrl = attrs.artwork?.formattedUrl(width: 600, height: 600)
        
        var trackItems: [TrackItem] = []
        if let tracksData = resource.relationships?.tracks?.data {
            for track in tracksData {
                let trackAttrs = track.attributes
                let durationSec = (trackAttrs.durationInMillis ?? 0) / 1000
                let isExplicit = trackAttrs.contentRating == "explicit"
                trackItems.append(TrackItem(
                    id: track.id,
                    trackNumber: trackAttrs.trackNumber ?? (trackItems.count + 1),
                    title: trackAttrs.name,
                    artistName: trackAttrs.artistName ?? attrs.artistName ?? "Unknown Artist",
                    durationSeconds: durationSec,
                    isExplicit: isExplicit
                ))
            }
        }
        
        return CatalogItem(
            id: resource.id,
            type: type,
            title: attrs.name,
            artistName: attrs.artistName ?? "Unknown Artist",
            albumName: attrs.albumName,
            releaseDate: attrs.releaseDate,
            artworkUrl: artworkUrl,
            trackCount: attrs.trackCount ?? trackItems.count,
            appleMusicUrl: attrs.url ?? "https://music.apple.com",
            genre: attrs.genreNames?.first,
            tracks: trackItems
        )
    }
}
