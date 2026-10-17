import XCTest
import Foundation
@testable import MusicLabCore

final class ServerConfigTests: XCTestCase {

    func testDefaultIsEmptyAndDisconnected() {
        let config = ServerConfig.default
        XCTAssertEqual(config.backendUrl, "")
        XCTAssertEqual(config.bearerToken, "")
        XCTAssertEqual(config.navidromeUrl, "")
        XCTAssertFalse(config.isConnected)
        XCTAssertNil(config.lastChecked)
    }

    func testCodableRoundTripPreservesFields() throws {
        let original = ServerConfig(
            backendUrl: "http://100.116.177.77:3001",
            bearerToken: "secret",
            navidromeUrl: "http://100.116.177.77:4533",
            isConnected: true,
            lastChecked: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDecodesConfigSavedWithStrippedToken() throws {
        // What AppState writes to UserDefaults: token blanked (kept in keychain).
        let json = """
        {"backendUrl":"http://host:3001","bearerToken":"","navidromeUrl":"","isConnected":false}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)
        XCTAssertEqual(decoded.backendUrl, "http://host:3001")
        XCTAssertEqual(decoded.bearerToken, "")
        XCTAssertNil(decoded.lastChecked)
    }
}
