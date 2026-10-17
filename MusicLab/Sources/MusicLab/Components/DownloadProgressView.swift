import SwiftUI
import MusicLabCore

/// Live download progress: a percentage bar plus completed/total, throughput
/// and ETA. Renders nothing when the job has no progress data yet.
public struct DownloadProgressView: View {
    public let job: Job

    public init(job: Job) {
        self.job = job
    }

    private var hasData: Bool {
        job.progressPercent != nil || job.speedText != nil || job.etaText != nil
    }

    public var body: some View {
        if hasData {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let percent = job.progressPercent {
                    ProgressView(value: percent, total: 100)
                        .tint(Theme.accent)
                        .animation(.easeOut(duration: 0.5), value: percent)
                }

                HStack(spacing: Spacing.xs) {
                    if let completed = job.progressCompleted,
                       let total = job.progressTotal, total > 0 {
                        Text("\(min(completed, total))/\(total)")
                            .fontWeight(.semibold)
                    } else if let percent = job.progressPercent {
                        Text("\(Int(percent.rounded()))%")
                            .fontWeight(.semibold)
                    }

                    if let speed = job.speedText {
                        separator
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(speed)
                    }

                    if let eta = job.etaText {
                        separator
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .bold))
                        Text(eta)
                    }

                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Download progress")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if let completed = job.progressCompleted,
           let total = job.progressTotal, total > 0 {
            parts.append("\(min(completed, total)) of \(total) tracks")
        } else if let percent = job.progressPercent {
            parts.append("\(Int(percent.rounded())) percent")
        }
        if let speed = job.speedText {
            parts.append(speed)
        }
        if let eta = job.etaText {
            parts.append("\(eta) remaining")
        }
        return parts.joined(separator: ", ")
    }

    private var separator: some View {
        Text("•").font(.caption2).foregroundStyle(Theme.textTertiary)
    }
}
