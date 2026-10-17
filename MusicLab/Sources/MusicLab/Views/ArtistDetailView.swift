import SwiftUI
import MusicLabCore

public struct ArtistDetailView: View {
    public let artistId: String
    public let artistName: String
    @EnvironmentObject private var appState: AppState
    @State private var albums: [CatalogItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showDownloadAllWarning: Bool = false
    @State private var isDownloadingAll: Bool = false
    @State private var queuedAlbumIds: Set<String> = []

    public init(artistId: String, artistName: String) {
        self.artistId = artistId
        self.artistName = artistName
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Artist header
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(Theme.accentGradient)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("ARTIST")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.accent)

                            Text(artistName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            
                            if !albums.isEmpty {
                                Text("\(albums.count) albums available")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }

                        Spacer()
                    }

                    // Download All Button
                    if !albums.isEmpty {
                        Button {
                            showDownloadAllWarning = true
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download All (\(albums.count) Albums)")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                            .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 3)
                        }
                        .disabled(isLoading || isDownloadingAll)
                    }
                }
                .padding(.horizontal)

                // Albums section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Albums")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal)

                    if isLoading {
                        LoadingStateView(message: "Loading albums from Apple Music...")
                    } else if let errorMessage = errorMessage {
                        ErrorBannerView(title: "Error", message: errorMessage)
                    } else if albums.isEmpty {
                        EmptyStateView(
                            iconName: "music.note.list",
                            title: "No Albums Found",
                            message: "This artist has no albums available in the Apple Music catalog."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(albums) { album in
                                HStack(spacing: Spacing.md) {
                                    NavigationLink(destination: ItemDetailView(item: album)) {
                                        HStack(spacing: Spacing.md) {
                                            if let artworkUrl = album.artworkUrl, let url = URL(string: artworkUrl) {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().scaledToFill()
                                                } placeholder: {
                                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                                        .fill(Theme.accentGradient)
                                                        .frame(width: 50, height: 50)
                                                }
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                                            } else {
                                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                                    .fill(Theme.accentGradient)
                                                    .frame(width: 50, height: 50)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(album.title)
                                                    .font(.body.weight(.medium))
                                                    .foregroundStyle(Theme.textPrimary)
                                                    .lineLimit(1)

                                                Text("\(album.trackCount) tracks\(album.releaseDate.map { " • \($0.prefix(4))" } ?? "")")
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }

                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    // Quick Download Button per Album
                                    Button {
                                        queuedAlbumIds.insert(album.id)
                                        appState.submitImport(item: album)
                                    } label: {
                                        Image(systemName: queuedAlbumIds.contains(album.id) ? "checkmark.circle.fill" : "arrow.down.circle")
                                            .font(.title3)
                                            .foregroundStyle(queuedAlbumIds.contains(album.id) ? Theme.success : Theme.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, Spacing.xs)

                                    NavigationLink(destination: ItemDetailView(item: album)) {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)

                                if album.id != albums.last?.id {
                                    Divider()
                                        .padding(.leading, 64)
                                }
                            }
                        }
                        .cardSurface(cornerRadius: CornerRadius.md)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle(artistName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Download All Albums?", isPresented: $showDownloadAllWarning) {
            Button("Download All (\(albums.count) Albums)", role: .none) {
                downloadAllAlbums()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will queue \(albums.count) albums for \(artistName). Depending on how much music this artist has, this might take a while to download and convert.")
        }
        .task {
            await loadArtistAlbums()
        }
    }

    private func downloadAllAlbums() {
        guard !albums.isEmpty else { return }
        isDownloadingAll = true
        for album in albums {
            queuedAlbumIds.insert(album.id)
        }
        appState.submitBatchImports(items: albums)
        appState.selectedTab = .queue
        if appState.artistPromptItem != nil {
            appState.artistPromptItem = nil
        }
        isDownloadingAll = false
    }

    private func loadArtistAlbums() async {
        isLoading = true
        errorMessage = nil
        do {
            let results = try await appState.musicClient.fetchArtistAlbums(artistId: artistId)
            await MainActor.run {
                albums = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}