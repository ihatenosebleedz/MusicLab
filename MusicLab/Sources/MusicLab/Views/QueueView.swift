import SwiftUI

public struct QueueView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedFilter: QueueFilter = .all
    
    public enum QueueFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case failed = "Failed"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    private var filteredJobs: [Job] {
        switch selectedFilter {
        case .all:
            return appState.jobs
        case .active:
            return appState.jobs.filter { $0.state.isActive }
        case .completed:
            return appState.jobs.filter { $0.state == .completed }
        case .failed:
            return appState.jobs.filter { $0.state == .failed }
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(QueueFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, Spacing.sm)
                .background(Theme.background)
                
                if filteredJobs.isEmpty {
                    EmptyStateView(
                        iconName: "arrow.down.circle",
                        title: "No Jobs in Queue",
                        message: selectedFilter == .all
                            ? "Your download queue is empty. Search for music to import."
                            : "No jobs matching filter '\(selectedFilter.rawValue)'."
                    )
                } else {
                    List {
                        ForEach(filteredJobs) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(job.name)
                                                .font(.headline)
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(1)
                                            
                                            Text(job.type.uppercased())
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        StatusBadgeView(state: job.state)
                                    }
                                    
                                    // Progress stage ladder for active and failed jobs
                                    if job.state.isActive || job.state == .failed {
                                        StageLadderView(job: job)
                                            .padding(.top, 2)
                                    }
                                    
                                    if let hint = job.progressHint {
                                        Text(hint)
                                            .font(.caption)
                                            .foregroundStyle(Theme.accent)
                                    }
                                    
                                    if job.state == .completed {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "checkmark.shield.fill")
                                                .foregroundStyle(Theme.success)
                                                .font(.caption)
                                            Text("Verified in Navidrome library")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if job.state.isActive {
                                    Button(role: .destructive) {
                                        appState.cancelJob(id: job.id)
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                } else if job.state == .failed {
                                    Button {
                                        appState.retryJob(id: job.id)
                                    } label: {
                                        Label("Retry", systemImage: "arrow.clockwise")
                                    }
                                    .tint(Theme.accent)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Theme.background)
            .navigationTitle("Download Queue")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.clearCompletedJobs()
                    } label: {
                        Text("Clear Done")
                            .font(.subheadline)
                    }
                    .disabled(appState.jobs.filter { $0.state == .completed || $0.state == .cancelled }.isEmpty)
                }
            }
        }
    }
}
