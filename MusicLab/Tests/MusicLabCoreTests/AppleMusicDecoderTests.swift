import XCTest
import Foundation
@testable import MusicLabCore

final class AppleMusicDecoderTests: XCTestCase {
    let sampleSearchJson = """
    {
      "results": {
        "albums": {
          "href": "/v1/catalog/us/search?term=gnx&types=albums",
          "data": [
            {
              "id": "1781290351",
              "type": "albums",
              "href": "/v1/catalog/us/albums/1781290351",
              "attributes": {
                "name": "GNX",
                "artistName": "Kendrick Lamar",
                "albumName": "GNX",
                "releaseDate": "2024-11-22",
                "trackCount": 12,
                "genreNames": ["Hip-Hop/Rap"],
                "url": "https://music.apple.com/us/album/gnx/1781290351",
                "artwork": {
                  "width": 3000,
                  "height": 3000,
                  "url": "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/31/5a/8f/315a8fb4-e503-455c-b172-e56c5e88e89f/24UM1IM41846.rgb.jpg/{w}x{h}bb.jpg"
                }
              },
              "relationships": {
                "tracks": {
                  "data": [
                    {
                      "id": "1781290352",
                      "type": "songs",
                      "attributes": {
                        "name": "wacced out murals",
                        "artistName": "Kendrick Lamar",
                        "trackNumber": 1,
                        "durationInMillis": 331000,
                        "contentRating": "explicit"
                      }
                    }
                  ]
                }
              }
            }
          ]
        },
        "songs": {
          "data": [
            {
              "id": "1732646280",
              "type": "songs",
              "attributes": {
                "name": "360",
                "artistName": "Charli xcx",
                "albumName": "BRAT",
                "durationInMillis": 133000,
                "contentRating": "explicit",
                "url": "https://music.apple.com/us/album/360/1732646278?i=1732646280",
                "artwork": {
                  "url": "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/21/d9/6a/21d96ad8-12c8-8988-cb9d-d6ee65bebb4a/5054197949313.jpg/{w}x{h}bb.jpg"
                }
              }
            }
          ]
        }
      }
    }
    """
    
    func testDecodeSearchResponse() throws {
        let data = sampleSearchJson.data(using: .utf8)!
        let client = AppleMusicClient()
        let items = try client.parseSearchResponse(data)
        
        XCTAssertEqual(items.count, 2)
        
        // Album verification
        let album = items.first { $0.type == .album }
        XCTAssertNotNil(album)
        XCTAssertEqual(album?.title, "GNX")
        XCTAssertEqual(album?.artistName, "Kendrick Lamar")
        XCTAssertEqual(album?.trackCount, 12)
        XCTAssertEqual(album?.tracks.count, 1)
        XCTAssertEqual(album?.tracks.first?.title, "wacced out murals")
        XCTAssertEqual(album?.tracks.first?.trackNumber, 1)
        XCTAssertEqual(album?.tracks.first?.isExplicit, true)
        XCTAssertEqual(album?.tracks.first?.formattedDuration, "5:31")
        XCTAssertTrue(album?.artworkUrl?.contains("600x600bb.jpg") == true)
        
        // Song verification
        let song = items.first { $0.type == .song }
        XCTAssertNotNil(song)
        XCTAssertEqual(song?.title, "360")
        XCTAssertEqual(song?.artistName, "Charli xcx")
        XCTAssertEqual(song?.albumName, "BRAT")
    }
    
    func testArtworkFormatting() {
        let artwork = AMArtwork(url: "https://example.com/art/{w}x{h}bb.{f}")
        let formatted = artwork.formattedUrl(width: 800, height: 800)
        XCTAssertEqual(formatted, "https://example.com/art/800x800bb.jpg")
    }
}
