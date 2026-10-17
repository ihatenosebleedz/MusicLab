import SwiftUI
import MusicLabCore

public struct JobDetailView: View {
    public let job: Job
    @EnvironmentObject private var appState: AppState
    @State private var isShowingLogs: Bool = false
    @State private var logEntries: [BackendLogEntry] = []
    @State private var isLoadingLogs: Bool = false
    @State private var logsError: String? = nil
    
    public init(job: Job) {
        self.job = job
    }

    /// The freshest copy of this job from the polled queue, so the detail view
    /// reflects live progress instead of the snapshot captured at navigation.
    private var currentJob: Job {
        appState.jobs.first(where: { $0.id == job.id }) ?? job
    }

    public var body: some View {
        let job = currentJob
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
                    
                    if job.state.isActive && (job.progressPercent != nil || job.speedText != nil) {
                        DownloadProgressView(job: job)
                            .padding(.top, Spacing.xs)
                    } else if let hint = job.progressHint {
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
                    
                    // Detailed Timing & Progress
                    MusicCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            LabeledContent("Created", value: job.createdAt.formatted(date: .abbreviated, time: .shortened))
                            if let started = job.startedAt {
                                LabeledContent("Started", value: started.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let finished = job.finishedAt {
                                LabeledContent("Finished", value: finished.formatted(date: .abbreviated, time: .shortened))
                                if let started = job.startedAt {
                                    let duration = finished.timeIntervalSince(started)
                                    LabeledContent("Duration", value: String(format: "%.1fs", duration))
                                }
                            }
                            if let hint = job.progressHint {
                                LabeledContent("Progress", value: hint)
                            }
                            LabeledContent("Added Tracks", value: "\(job.addedTracks.count)")
                            if let exitCode = job.exitCode {
                                LabeledContent("Exit Code", value: "\(exitCode)")
                            }
                        }
                        .font(.caption)
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
                                     ? "Tracks indexed and playable in your library"
                                     : "Navidrome polls your music folder; awaiting index cycle")
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
                        .cardSurface(cornerRadius: CornerRadius.md)
                        .padding(.horizontal)
                    }
                }
                
                // Execution Logs (fetched from the backend)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    DisclosureGroup("Execution Logs & Output (Detailed)", isExpanded: $isShowingLogs) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            if isLoadingLogs {
                                HStack(spacing: Spacing.sm) {
                                    ProgressView().tint(Theme.accent)
                                    Text("Loading logs…")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            } else if let logsError {
                                Text(logsError)
                                    .font(.caption)
                                    .foregroundStyle(Theme.error)
                            } else if !logEntries.isEmpty {
                                HStack {
                                    Spacer()
                                    Button {
                                        Task { await loadLogs() }
                                    } label: {
                                        Label("Refresh", systemImage: "arrow.clockwise")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(Theme.accent)
                                }
                                ForEach(Array(logEntries.enumerated()), id: \.offset) { _, entry in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        Text(entry.source.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(sourceColor(entry.source))
                                            .frame(width: 56, alignment: .leading)
                                        Text(entry.line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Theme.textPrimary)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 1)
                                }
                            } else {
                                // Fallback: tails embedded in the job payload.
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
                                
                                if (job.stdoutTail ?? "").isEmpty && (job.stderrTail ?? "").isEmpty {
                                    Text(logsError ?? "No output captured for this job yet.")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding(.top, Spacing.xs)
                        .onChange(of: isShowingLogs) { _, expanded in
                            if expanded { Task { await loadLogs() } }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding()
                    .cardSurface(cornerRadius: CornerRadius.md)
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
                            .tintedGlass(Theme.error.opacity(0.35), in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
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
                            .tintedGlass(Theme.accent.opacity(0.85), in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
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
    
    private func loadLogs() async {
        guard !isLoadingLogs else { return }
        isLoadingLogs = true
        logsError = nil
        let entries = await appState.fetchJobLogs(jobId: job.id)
        logEntries = entries
        isLoadingLogs = false
        if entries.isEmpty && !appState.isServerOnline {
            logsError = "Server offline — cannot load logs."
        }
    }
    
    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "job": return Theme.info
        case "wrapper": return Theme.warning
        default: return Theme.textSecondary
        }
    }
}
