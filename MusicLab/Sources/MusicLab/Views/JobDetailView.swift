import SwiftUI

public struct JobDetailView: View {
    public let job: Job
    @EnvironmentObject private var appState: AppState
    @State private var isShowingLogs: Bool = false
    
    public init(job: Job) {
        self.job = job
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header Card
                MusicCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(job.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                            
                            Text(job.type.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        StatusBadgeView(state: job.state)
                    }
                    
                    if let hint = job.progressHint {
                        Text(hint)
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal)
                
                // Pipeline Progress
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Pipeline Stage")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal)
                    
                    MusicCard {
                        StageLadderView(job: job)
                    }
                    .padding(.horizontal)
                }
                
                // Navidrome Verification Status
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Navidrome Library Verification")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal)
                    
                    MusicCard {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: job.navidrome?.verified == true ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                .font(.title2)
                                .foregroundStyle(job.navidrome?.verified == true ? Theme.success : Theme.info)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.navidrome?.verified == true ? "Verified in Navidrome" : "Auto-discovery in progress")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                
                                Text(job.navidrome?.verified == true
                                     ? "Tracks indexed and playable on port 4533"
                                     : "Navidrome polls /mnt/media/Music; awaiting OpenSubsonic index")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Output Files (AddedTrack[])
                if !job.addedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Output Files (\(job.addedTracks.count))")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(job.addedTracks, id: \.path) { track in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    
                                    Text(track.path)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Theme.textTertiary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if track.path != job.addedTracks.last?.path {
                                    Divider()
                                }
                            }
                        }
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .padding(.horizontal)
                    }
                }
                
                // Raw Process Output / Logs
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    DisclosureGroup("Execution Logs & Output", isExpanded: $isShowingLogs) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            if let stdout = job.stdoutTail, !stdout.isEmpty {
                                Text("stdout:")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.textSecondary)
                                Text(stdout)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xs))
                            }
                            
                            if let stderr = job.stderrTail, !stderr.isEmpty {
                                Text("stderr:")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.error)
                                Text(stderr)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xs))
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .padding(.horizontal)
                }
                
                // Job Actions
                HStack(spacing: Spacing.md) {
                    if job.state.isActive {
                        Button {
                            appState.cancelJob(id: job.id)
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel Job")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .foregroundStyle(Theme.error)
                            .background(Theme.error.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }
                    } else if job.state == .failed {
                        Button {
                            appState.retryJob(id: job.id)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry Job")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .foregroundStyle(.white)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
