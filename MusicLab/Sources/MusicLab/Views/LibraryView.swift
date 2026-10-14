import SwiftUI
import MusicLabCore

public struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    private var verifiedJobs: [Job] {
        appState.jobs.filter { $0.state == .completed }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Navidrome Server Status Card
                    MusicCard {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "music.note.house.fill")
                                .font(.title)
                                .foregroundStyle(Theme.accent)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Navidrome Music Library")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                
                                Text(appState.serverConfig.navidromeUrl)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Theme.success)
                                    .frame(width: 8, height: 8)
                                Text("Ready")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.success)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(Theme.success.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        Divider()
                            .padding(.vertical, Spacing.xs)
                        
                        HStack {
                            Text("Auto-discovery active on /mnt/media/Music")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                            
                            Spacer()
                            
                            if let navidromeUrl = URL(string: appState.serverConfig.navidromeUrl) {
                                Link(destination: navidromeUrl) {
                                    HStack(spacing: 2) {
                                        Text("Open Web UI")
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Verified Items List
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Verified Imports (\(verifiedJobs.count))")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal)
                        
                        if verifiedJobs.isEmpty {
                            EmptyStateView(
                                iconName: "music.note.list",
                                title: "No Imports Verified Yet",
                                message: "When download jobs complete and are verified in Navidrome, they will appear here.",
                                actionTitle: "Go to Discover",
                                action: {
                                    appState.selectedTab = .discover
                                }
                            )
                        } else {
                            VStack(spacing: Spacing.sm) {
                                ForEach(verifiedJobs) { job in
                                    NavigationLink(destination: JobDetailView(job: job)) {
                                        MusicCard {
                                            HStack(spacing: Spacing.md) {
                                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                                    .fill(Theme.accentGradient)
                                                    .frame(width: 50, height: 50)
                                                    .overlay(
                                                        Image(systemName: "checkmark.shield.fill")
                                                            .foregroundStyle(.white)
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(job.name)
                                                        .font(.body.weight(.semibold))
                                                        .foregroundStyle(Theme.textPrimary)
                                                        .lineLimit(1)
                                                    
                                                    HStack(spacing: Spacing.xs) {
                                                        Text("Verified in Navidrome")
                                                            .font(.caption)
                                                            .foregroundStyle(Theme.success)
                                                        
                                                        if let matches = job.navidrome?.matches, matches > 0 {
                                                            Text("• \(matches) tracks")
                                                                .font(.caption)
                                                                .foregroundStyle(Theme.textSecondary)
                                                        }
                                                    }
                                                    
                                                    if let finished = job.finishedAt {
                                                        Text("Completed \(finished.formatted(date: .abbreviated, time: .shortened))")
                                                            .font(.caption2)
                                                            .foregroundStyle(Theme.textTertiary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.textTertiary)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Library")
        }
    }
}
