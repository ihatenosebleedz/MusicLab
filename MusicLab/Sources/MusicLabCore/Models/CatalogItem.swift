import Foundation

public enum CatalogType: String, Codable, CaseIterable, Identifiable, Sendable {
    case song = "song"
    case album = "album"
    case playlist = "playlist"
    case artist = "artist"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .song: return "Song"
        case .album: return "Album"
        case .playlist: return "Playlist"
        case .artist: return "Artist"
        }
    }
    
    public var iconName: String {
        switch self {
        case .song: return "music.note"
        case .album: return "square.stack"
        case .playlist: return "music.note.list"
        case .artist: return "person.crop.circle"
        }
    }
}

public struct TrackItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let trackNumber: Int
    public let title: String
    public let artistName: String
    public let durationSeconds: Int
    public let isExplicit: Bool
    
    public init(
        id: String = UUID().uuidString,
        trackNumber: Int,
        title: String,
        artistName: String,
        durationSeconds: Int,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.trackNumber = trackNumber
        self.title = title
        self.artistName = artistName
        self.durationSeconds = durationSeconds
        self.isExplicit = isExplicit
    }
    
    public var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

public struct CatalogItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let type: CatalogType
    public let title: String
    public let artistName: String
    public let albumName: String?
    public let releaseDate: String?
    public let artworkUrl: String?
    public let trackCount: Int
    public let appleMusicUrl: String
    public let genre: String?
    public let tracks: [TrackItem]
    
    public init(
        id: String = UUID().uuidString,
        type: CatalogType,
        title: String,
        artistName: String,
        albumName: String? = nil,
        releaseDate: String? = nil,
        artworkUrl: String? = nil,
        trackCount: Int = 1,
        appleMusicUrl: String,
        genre: String? = nil,
        tracks: [TrackItem] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.releaseDate = releaseDate
        self.artworkUrl = artworkUrl
        self.trackCount = trackCount
        self.appleMusicUrl = appleMusicUrl
        self.genre = genre
        self.tracks = tracks
    }
}
