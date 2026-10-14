import SwiftUI
import MusicLabCore

public struct StatusBadgeView: View {
    public let state: JobState
    
    public init(state: JobState) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: state.iconName)
                .font(.system(size: 11, weight: .semibold))
            
            Text(state.displayName)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .foregroundStyle(state.color)
        .background(state.color.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(state.color.opacity(0.3), lineWidth: 1)
        )
    }
}
