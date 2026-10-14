import XCTest
import Foundation
@testable import MusicLabCore

final class AppleMusicURLTests: XCTestCase {
    func testParseValidAlbumURL() throws {
        let urlString = "https://music.apple.com/us/album/gnx/1781290351"
        let parsed = try AppleMusicURL.parse(urlString)
        
        XCTAssertEqual(parsed.storefront, "us")
        XCTAssertEqual(parsed.resourceType, .album)
        XCTAssertEqual(parsed.slug, "gnx")
        XCTAssertEqual(parsed.identifier, "1781290351")
        XCTAssertNil(parsed.trackIdentifier)
        XCTAssertFalse(parsed.isTrackWithinAlbum)
        XCTAssertEqual(parsed.effectiveResourceType, .album)
        XCTAssertEqual(parsed.effectiveIdentifier, "1781290351")
    }
    
    func testParseAlbumURLWithoutSlug() throws {
        let urlString = "https://music.apple.com/gb/album/1781290351"
        let parsed = try AppleMusicURL.parse(urlString)
        
        XCTAssertEqual(parsed.storefront, "gb")
        XCTAssertEqual(parsed.resourceType, .album)
        XCTAssertNil(parsed.slug)
        XCTAssertEqual(parsed.identifier, "1781290351")
    }
    
    func testParseSongWithinAlbum() throws {
        let urlString = "https://music.apple.com/us/album/brat/1732646278?i=1732646280"
        let parsed = try AppleMusicURL.parse(urlString)
        
        XCTAssertEqual(parsed.storefront, "us")
        XCTAssertEqual(parsed.resourceType, .album)
        XCTAssertEqual(parsed.identifier, "1732646278")
        XCTAssertEqual(parsed.trackIdentifier, "1732646280")
        XCTAssertTrue(parsed.isTrackWithinAlbum)
        XCTAssertEqual(parsed.effectiveResourceType, .song)
        XCTAssertEqual(parsed.effectiveIdentifier, "1732646280")
    }
    
    func testParsePlaylistURL() throws {
        let urlString = "https://music.apple.com/us/playlist/todays-hits/pl.f4d1060b52a24e49ac99f37d18e5ad63"
        let parsed = try AppleMusicURL.parse(urlString)
        
        XCTAssertEqual(parsed.storefront, "us")
        XCTAssertEqual(parsed.resourceType, .playlist)
        XCTAssertEqual(parsed.slug, "todays-hits")
        XCTAssertEqual(parsed.identifier, "pl.f4d1060b52a24e49ac99f37d18e5ad63")
        XCTAssertEqual(parsed.effectiveResourceType, .playlist)
    }
    
    func testParseArtistURL() throws {
        let urlString = "https://music.apple.com/us/artist/kendrick-lamar/368183298"
        let parsed = try AppleMusicURL.parse(urlString)
        
        XCTAssertEqual(parsed.storefront, "us")
        XCTAssertEqual(parsed.resourceType, .artist)
        XCTAssertEqual(parsed.slug, "kendrick-lamar")
        XCTAssertEqual(parsed.identifier, "368183298")
    }
    
    func testInvalidHostThrows() {
        let urlString = "https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa"
        XCTAssertThrowsError(try AppleMusicURL.parse(urlString)) { error in
            guard case AppleMusicURLError.invalidHost = error else {
                XCTFail("Expected invalidHost error, got: \(error)")
                return
            }
        }
    }
    
    func testUnsupportedTypeThrows() {
        let urlString = "https://music.apple.com/us/radio/apple-music-1/ra.987654321"
        XCTAssertThrowsError(try AppleMusicURL.parse(urlString)) { error in
            guard case AppleMusicURLError.unsupportedResourceType = error else {
                XCTFail("Expected unsupportedResourceType error, got: \(error)")
                return
            }
        }
    }
    
    func testMalformedURLThrows() {
        let urlString = "not a valid url at all"
        XCTAssertThrowsError(try AppleMusicURL.parse(urlString))
    }
}
