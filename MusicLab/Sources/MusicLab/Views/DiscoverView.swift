import SwiftUI

public struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingUrlSheet = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Backend offline banner if applicable
                    if !appState.isServerOnline {
                        BackendUnavailableCard(
                            serverUrl: appState.serverConfig.backendUrl,
                            onSettingsTapped: {
                                appState.selectedTab = .settings
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Quick Import Action Card
                    MusicCard {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Import from Link")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                
                                Text("Paste any Apple Music album, song, or playlist URL")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                isShowingUrlSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Featured Spotlight
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Featured Releases")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.md) {
                                ForEach(MockData.sampleAlbums) { album in
                                    NavigationLink(destination: ItemDetailView(item: album)) {
                                        VStack(alignment: .leading, spacing: Spacing.xs) {
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .fill(Theme.accentGradient)
                                                .frame(width: 150, height: 150)
                                                .overlay(
                                                    Image(systemName: "music.quarternote.3")
                                                        .font(.system(size: 36))
                                                        .foregroundStyle(.white)
                                                )
                                                .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                                            
                                            Text(album.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(1)
                                            
                                            Text(album.artistName)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 150)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recommended Tracks
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Sample Tracks")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal)
                        
                        VStack(spacing: Spacing.sm) {
                            ForEach(MockData.sampleSongs) { song in
                                NavigationLink(destination: ItemDetailView(item: song)) {
                                    HStack(spacing: Spacing.md) {
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .fill(Theme.accent.opacity(0.8))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .foregroundStyle(.white)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(song.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Theme.textPrimary)
                                            
                                            Text(song.artistName)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            appState.submitImport(item: song)
                                        } label: {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.title3)
                                                .foregroundStyle(Theme.accent)
                                        }
                                    }
                                    .padding(Spacing.sm)
                                    .background(Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Discover")
            .sheet(isPresented: $isShowingUrlSheet) {
                QuickImportSheet()
            }
        }
    }
}
