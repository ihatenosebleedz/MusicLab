import SwiftUI
import MusicLabCore

public struct StageLadderView: View {
    public let job: Job
    
    private let steps: [(id: Int, title: String, icon: String)] = [
        (0, "Resolve", "magnifyingglass"),
        (1, "Download", "arrow.down"),
        (2, "Tag & Lyrics", "tag"),
        (3, "Navidrome", "arrow.triangle.2.circlepath"),
        (4, "Verified", "checkmark.shield")
    ]
    
    public init(job: Job) {
        self.job = job
    }
    
    private var activeStepIndex: Int {
        switch job.state {
        case .queued:
            return -1
        case .resolving:
            return 0
        case .downloading:
            return 1
        case .processing:
            return 2
        case .waitingForNavidrome:
            return 3
        case .verifying:
            return 3
        case .completed:
            return 4
        case .failed, .cancelled:
            return job.stage?.stepIndex ?? 0
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(steps, id: \.id) { step in
                    VStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(stepCircleColor(for: step.id))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: stepIcon(for: step.id, defaultIcon: step.icon))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(stepIconColor(for: step.id))
                            )
                        
                        Text(step.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(stepTextColor(for: step.id))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if step.id < steps.count - 1 {
                        Rectangle()
                            .fill(stepConnectorColor(for: step.id))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 14)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
    
    private func stepCircleColor(for stepIndex: Int) -> Color {
        if job.state == .failed && activeStepIndex == stepIndex {
            return Theme.error
        }
        if stepIndex < activeStepIndex || job.state == .completed {
            return Theme.success
        } else if stepIndex == activeStepIndex {
            return Theme.accent
        } else {
            return Color(uiColor: .tertiarySystemFill)
        }
    }
    
    private func stepIcon(for stepIndex: Int, defaultIcon: String) -> String {
        if job.state == .failed && activeStepIndex == stepIndex {
            return "xmark"
        }
        if stepIndex < activeStepIndex || job.state == .completed {
            return "checkmark"
        }
        return defaultIcon
    }
    
    private func stepIconColor(for stepIndex: Int) -> Color {
        if stepIndex <= activeStepIndex || job.state == .completed {
            return .white
        } else {
            return Theme.textSecondary
        }
    }
    
    private func stepTextColor(for stepIndex: Int) -> Color {
        if stepIndex == activeStepIndex {
            return Theme.accent
        } else if stepIndex < activeStepIndex || job.state == .completed {
            return Theme.textPrimary
        } else {
            return Theme.textSecondary
        }
    }
    
    private func stepConnectorColor(for stepIndex: Int) -> Color {
        if stepIndex < activeStepIndex || job.state == .completed {
            return Theme.success
        } else {
            return Color(uiColor: .tertiarySystemFill)
        }
    }
}
