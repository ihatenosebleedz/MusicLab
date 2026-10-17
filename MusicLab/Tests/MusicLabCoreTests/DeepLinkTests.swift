import XCTest
@testable import MusicLabCore

final class DeepLinkTests: XCTestCase {
    func testParseQueryParamURL() {
        let raw = "musiclab://import?url=https://music.apple.com/us/album/gnx/1781290351"
        guard let url = URL(string: raw), let link = MusicLabDeepLink.parse(url) else {
            XCTFail("Failed to parse deep link")
            return
        }
        XCTAssertEqual(link, .importURL("https://music.apple.com/us/album/gnx/1781290351"))
    }
    
    func testParseURLEncodedQueryParam() {
        let raw = "musiclab://import?url=https%3A%2F%2Fmusic.apple.com%2Fus%2Falbum%2Fgnx%2F1781290351%3Fi%3D1781290352"
        guard let url = URL(string: raw), let link = MusicLabDeepLink.parse(url) else {
            XCTFail("Failed to parse encoded deep link")
            return
        }
        XCTAssertEqual(link, .importURL("https://music.apple.com/us/album/gnx/1781290351?i=1781290352"))
    }
    
    func testParseDirectAppleMusicHost() {
        let raw = "musiclab://music.apple.com/us/album/gnx/1781290351"
        guard let url = URL(string: raw), let link = MusicLabDeepLink.parse(url) else {
            XCTFail("Failed to parse direct host deep link")
            return
        }
        XCTAssertEqual(link, .importURL("https://music.apple.com/us/album/gnx/1781290351"))
    }
    
    func testParseDirectHttpsInScheme() {
        let raw = "musiclab://https://music.apple.com/us/playlist/todays-hits/pl.f4d106fed2bd41149aaacabb233eb5eb"
        guard let url = URL(string: raw), let link = MusicLabDeepLink.parse(url) else {
            XCTFail("Failed to parse direct https scheme deep link")
            return
        }
        XCTAssertEqual(link, .importURL("https://music.apple.com/us/playlist/todays-hits/pl.f4d106fed2bd41149aaacabb233eb5eb"))
    }
    
    func testCleanExtractedURLWithFluffText() {
        let raw = "musiclab://import?url=Listen%20to%20this%20track:%20https://music.apple.com/us/song/luther/1781290352%20on%20Apple%20Music"
        guard let url = URL(string: raw), let link = MusicLabDeepLink.parse(url) else {
            XCTFail("Failed to parse deep link with text")
            return
        }
        XCTAssertEqual(link, .importURL("https://music.apple.com/us/song/luther/1781290352"))
    }
    
    func testRejectsNonMusicLabScheme() {
        let raw = "https://music.apple.com/us/album/gnx/1781290351"
        guard let url = URL(string: raw) else { return }
        XCTAssertNil(MusicLabDeepLink.parse(url))
    }
    
    func testRejectsEmptyQueryParam() {
        let raw = "musiclab://import?url="
        guard let url = URL(string: raw) else { return }
        XCTAssertNil(MusicLabDeepLink.parse(url))
    }
}
