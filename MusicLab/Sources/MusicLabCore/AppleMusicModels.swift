import Foundation

// MARK: - Apple Music API Raw Response Models

public struct AMArtwork: Codable, Sendable {
    public let width: Int?
    public let height: Int?
    public let url: String
    public let bgColor: String?
    public let textColor1: String?
    
    public init(width: Int? = nil, height: Int? = nil, url: String, bgColor: String? = nil, textColor1: String? = nil) {
        self.width = width
        self.height = height
        self.url = url
        self.bgColor = bgColor
        self.textColor1 = textColor1
    }
    
    public func formattedUrl(width: Int = 600, height: Int = 600) -> String {
        return url
            .replacingOccurrences(of: "{w}", with: "\(width)")
            .replacingOccurrences(of: "{h}", with: "\(height)")
            .replacingOccurrences(of: "{f}", with: "jpg")
    }
}

public struct AMAttributes: Codable, Sendable {
    public let name: String
    public let artistName: String?
    public let albumName: String?
    public let releaseDate: String?
    public let artwork: AMArtwork?
    public let genreNames: [String]?
    public let trackNumber: Int?
    public let durationInMillis: Int?
    public let url: String?
    public let contentRating: String?
    public let trackCount: Int?
    
    public init(
        name: String,
        artistName: String? = nil,
        albumName: String? = nil,
        releaseDate: String? = nil,
        artwork: AMArtwork? = nil,
        genreNames: [String]? = nil,
        trackNumber: Int? = nil,
        durationInMillis: Int? = nil,
        url: String? = nil,
        contentRating: String? = nil,
        trackCount: Int? = nil
    ) {
        self.name = name
        self.artistName = artistName
        self.albumName = albumName
        self.releaseDate = releaseDate
        self.artwork = artwork
        self.genreNames = genreNames
        self.trackNumber = trackNumber
        self.durationInMillis = durationInMillis
        self.url = url
        self.contentRating = contentRating
        self.trackCount = trackCount
    }
}

public struct AMResource: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let href: String?
    public let attributes: AMAttributes
    public let relationships: AMRelationships?
    
    public init(id: String, type: String, href: String? = nil, attributes: AMAttributes, relationships: AMRelationships? = nil) {
        self.id = id
        self.type = type
        self.href = href
        self.attributes = attributes
        self.relationships = relationships
    }
}

public struct AMResourceCollection: Codable, Sendable {
    public let href: String?
    public let next: String?
    public let data: [AMResource]
    
    public init(href: String? = nil, next: String? = nil, data: [AMResource] = []) {
        self.href = href
        self.next = next
        self.data = data
    }
}

public struct AMRelationships: Codable, Sendable {
    public let tracks: AMResourceCollection?
    public let albums: AMResourceCollection?
    public let artists: AMResourceCollection?
    
    public init(tracks: AMResourceCollection? = nil, albums: AMResourceCollection? = nil, artists: AMResourceCollection? = nil) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
    }
}

public struct AMSearchResults: Codable, Sendable {
    public let songs: AMResourceCollection?
    public let albums: AMResourceCollection?
    public let artists: AMResourceCollection?
    public let playlists: AMResourceCollection?
    
    public init(
        songs: AMResourceCollection? = nil,
        albums: AMResourceCollection? = nil,
        artists: AMResourceCollection? = nil,
        playlists: AMResourceCollection? = nil
    ) {
        self.songs = songs
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
    }
}

public struct AMSearchResponse: Codable, Sendable {
    public let results: AMSearchResults
    
    public init(results: AMSearchResults) {
        self.results = results
    }
}

public struct AMLookupResponse: Codable, Sendable {
    public let data: [AMResource]
    
    public init(data: [AMResource]) {
        self.data = data
    }
}
