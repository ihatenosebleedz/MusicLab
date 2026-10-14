import Foundation

public enum JobState: String, Codable, CaseIterable, Identifiable, Sendable {
    case queued = "queued"
    case resolving = "resolving"
    case downloading = "downloading"
    case processing = "processing"
    case waitingForNavidrome = "waiting_for_navidrome"
    case verifying = "verifying"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .resolving: return "Resolving URL"
        case .downloading: return "Downloading"
        case .processing: return "Processing Audio"
        case .waitingForNavidrome: return "Waiting for Navidrome"
        case .verifying: return "Verifying in Library"
        case .completed: return "Verified & Complete"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    public var iconName: String {
        switch self {
        case .queued: return "clock"
        case .resolving: return "network"
        case .downloading: return "arrow.down.circle"
        case .processing: return "gearshape.2"
        case .waitingForNavidrome: return "arrow.triangle.2.circlepath"
        case .verifying: return "checkmark.shield"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    
    public var isActive: Bool {
        switch self {
        case .queued, .resolving, .downloading, .processing, .waitingForNavidrome, .verifying:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }
}

public enum JobStage: String, Codable, Sendable {
    case resolving = "resolving"
    case fetching = "fetching"
    case converting = "converting"
    case tagging = "tagging"
    case moving = "moving"
    case verifying = "verifying"
    case done = "done"
    case error = "error"
    
    public var displayName: String {
        switch self {
        case .resolving: return "Resolving Metadata"
        case .fetching: return "Downloading Audio"
        case .converting: return "Transcoding"
        case .tagging: return "Tagging & Lyrics"
        case .moving: return "Placing in Music Folder"
        case .verifying: return "Checking Navidrome"
        case .done: return "Finished"
        case .error: return "Error"
        }
    }
    
    public var stepIndex: Int {
        switch self {
        case .resolving: return 0
        case .fetching: return 1
        case .converting: return 2
        case .tagging: return 2
        case .moving: return 3
        case .verifying: return 4
        case .done: return 5
        case .error: return 0
        }
    }
}

public struct JobAddedTrack: Codable, Hashable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let path: String
    
    public init(title: String, artist: String, album: String, path: String) {
        self.title = title
        self.artist = artist
        self.album = album
        self.path = path
    }
}

public struct JobNavidromeStatus: Codable, Hashable, Sendable {
    public let verified: Bool
    public let checkedAt: Date?
    public let matches: Int
    
    public init(verified: Bool, checkedAt: Date? = nil, matches: Int = 0) {
        self.verified = verified
        self.checkedAt = checkedAt
        self.matches = matches
    }
}

public struct JobErrorDetail: Codable, Hashable, Sendable {
    public let code: String
    public let message: String
    public let details: String?
    
    public init(code: String, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

public struct Job: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let type: String
    public let url: String
    public let name: String
    public var state: JobState
    public var stage: JobStage?
    public var progressHint: String?
    public let createdAt: Date
    public var updatedAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var exitCode: Int?
    public var stdoutTail: String?
    public var stderrTail: String?
    public var addedTracks: [JobAddedTrack]
    public var navidrome: JobNavidromeStatus?
    public var error: JobErrorDetail?
    
    public init(
        id: String = UUID().uuidString,
        type: String,
        url: String,
        name: String,
        state: JobState,
        stage: JobStage? = nil,
        progressHint: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        exitCode: Int? = nil,
        stdoutTail: String? = nil,
        stderrTail: String? = nil,
        addedTracks: [JobAddedTrack] = [],
        navidrome: JobNavidromeStatus? = nil,
        error: JobErrorDetail? = nil
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.name = name
        self.state = state
        self.stage = stage
        self.progressHint = progressHint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.stdoutTail = stdoutTail
        self.stderrTail = stderrTail
        self.addedTracks = addedTracks
        self.navidrome = navidrome
        self.error = error
    }
}
