import Foundation

public struct ServerConfig: Codable, Equatable, Sendable {
    public var backendUrl: String
    public var bearerToken: String
    public var navidromeUrl: String
    public var isConnected: Bool
    public var lastChecked: Date?
    
    public init(
        backendUrl: String,
        bearerToken: String,
        navidromeUrl: String,
        isConnected: Bool,
        lastChecked: Date? = nil
    ) {
        self.backendUrl = backendUrl
        self.bearerToken = bearerToken
        self.navidromeUrl = navidromeUrl
        self.isConnected = isConnected
        self.lastChecked = lastChecked
    }
    
    public static let `default` = ServerConfig(
        backendUrl: "http://gentoo.tail29a9cb.ts.net:3000",
        bearerToken: "",
        navidromeUrl: "https://gentoo.tail29a9cb.ts.net:4533",
        isConnected: false,
        lastChecked: nil
    )
}
