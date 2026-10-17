import Foundation
import SwiftUI
import MusicLabCore

#if canImport(MusicKit)
import MusicKit

@MainActor
public final class AppleMusicAuthService: ObservableObject {
    public static let shared = AppleMusicAuthService()
    
    @Published public var authStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    
    public init() {}
    
    public func requestAccess() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        self.authStatus = status
        return status
    }
    
    public var isAuthorized: Bool {
        authStatus == .authorized
    }
    
    public func searchLibraryPlaylists(term: String) async -> [CatalogItem] {
        guard isAuthorized else { return [] }
        do {
            var request = MusicLibrarySearchRequest(term: term, types: [Playlist.self])
            request.limit = 25
            let response = try await request.response()
            return response.playlists.map { p in
                let artUrl = p.artwork?.url(width: 600, height: 600)?.absoluteString
                let appleUrl = p.url?.absoluteString ?? "https://music.apple.com/us/playlist/\(p.id.rawValue)"
                return CatalogItem(
                    id: p.id.rawValue,
                    type: .playlist,
                    title: p.name,
                    artistName: p.curatorName ?? "My Library Playlist",
                    artworkUrl: artUrl,
                    appleMusicUrl: appleUrl
                )
            }
        } catch {
            print("[MusicKit] Error searching library playlists: \(error)")
            return []
        }
    }
}
#else
@MainActor
public final class AppleMusicAuthService: ObservableObject {
    public static let shared = AppleMusicAuthService()
    public init() {}
    public var isAuthorized: Bool { false }
    public func requestAccess() async -> Bool { false }
    public func searchLibraryPlaylists(term: String) async -> [CatalogItem] { [] }
}
#endif
