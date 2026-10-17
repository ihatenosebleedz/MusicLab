import Foundation

public struct BackendHealthServices: Codable, Sendable {
    public struct ServiceItem: Codable, Sendable {
        public let available: Bool?
        public let healthy: Bool?
        public let openSubsonic: Bool?
    }
    public let amdl: ServiceItem?
    public let wrapperLite: ServiceItem?
    public let navidrome: ServiceItem?
}

public struct BackendHealthResponse: Codable, Sendable {
    public let status: String
    public let version: String
    public let timestamp: String
    public let services: BackendHealthServices?
}

public struct JobsListResponse: Codable, Sendable {
    public let jobs: [BackendJobSummary]
}

public struct BackendJobSummary: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let url: String
    public let name: String
    public let state: String
    public let stage: String?
    public let progressHint: String?
    public let progressPercent: Double?
    public let progressCompleted: Int?
    public let progressTotal: Int?
    public let etaSeconds: Int?
    public let speedText: String?
    public let createdAt: String
    public let updatedAt: String
    public let startedAt: String?
    public let finishedAt: String?
    public let exitCode: Int?
    public let stdoutTail: String?
    public let stderrTail: String?
    public let addedTracksCount: Int?
    public let addedTracks: [BackendTrack]?
    public let navidrome: BackendNavidromeStatus?
}

public struct BackendNavidromeStatus: Codable, Sendable {
    public let verified: Bool
    public let matches: Int
}

public struct BackendTrack: Codable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let path: String
}

public struct BackendJobDetail: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let url: String
    public let name: String
    public let state: String
    public let stage: String?
    public let progressHint: String?
    public let progressPercent: Double?
    public let progressCompleted: Int?
    public let progressTotal: Int?
    public let etaSeconds: Int?
    public let speedText: String?
    public let createdAt: String
    public let updatedAt: String
    public let startedAt: String?
    public let finishedAt: String?
    public let exitCode: Int?
    public let stdoutTail: String?
    public let stderrTail: String?
    public let addedTracks: [BackendTrack]
    public let navidrome: BackendNavidromeStatus?
}

public struct JobSubmissionRequest: Codable, Sendable {
    public let url: String
    public let name: String?
    public let destinationId: String?

    public init(url: String, name: String? = nil, destinationId: String? = nil) {
        self.url = url
        self.name = name
        self.destinationId = destinationId
    }
}

public struct JobCancelResponse: Codable, Sendable {
    public let id: String
    public let state: String
    public let cancelledAt: String?
}

// MARK: - Destinations (GET /destinations)

public struct BackendDestination: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let isDefault: Bool

    public init(id: String, isDefault: Bool = false) {
        self.id = id
        self.isDefault = isDefault
    }
}

public struct DestinationsResponse: Codable, Sendable {
    public let destinations: [BackendDestination]
    public let defaultId: String?

    public init(destinations: [BackendDestination], defaultId: String? = nil) {
        self.destinations = destinations
        self.defaultId = defaultId
    }
}

// MARK: - Logs (GET /logs)

public struct BackendLogEntry: Codable, Sendable, Hashable {
    public let source: String
    public let stream: String?
    public let jobId: String?
    public let at: String?
    public let line: String

    public init(source: String, stream: String? = nil, jobId: String? = nil, at: String? = nil, line: String) {
        self.source = source
        self.stream = stream
        self.jobId = jobId
        self.at = at
        self.line = line
    }
}

public struct LogsPage: Codable, Sendable {
    public let limit: Int
    public let offset: Int
    public let total: Int
    public let hasMore: Bool
}

public struct LogsAvailable: Codable, Sendable {
    public let backend: Bool?
    public let job: Bool?
    public let wrapper: Bool?
}

public struct LogsResponse: Codable, Sendable {
    public let logs: [BackendLogEntry]
    public let page: LogsPage
    public let available: LogsAvailable
}
