import SwiftUI
import MusicLabCore

extension JobState {
    public var color: Color {
        switch self {
        case .queued: return Theme.queued
        case .resolving: return Theme.info
        case .downloading: return Theme.accent
        case .processing: return Theme.warning
        case .waitingForNavidrome: return Theme.info
        case .verifying: return Theme.info
        case .completed: return Theme.success
        case .failed: return Theme.error
        case .cancelled: return Theme.textSecondary
        }
    }
}
