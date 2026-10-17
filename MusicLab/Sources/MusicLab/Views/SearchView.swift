import SwiftUI
import MusicLabCore

public struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""
    @State private var selectedFilter: CatalogType? = nil

    public init() {}

    private var displayedResults: [CatalogItem] {
        var results = appState.searchResults
        if let filter = selectedFilter {
            results = results.filter { $0.type == filter }
        }
        return results
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A pasted link (Apple Music share URL or any http(s) URL) is routed to
    /// import; anything else is treated as a catalog search query.
    private var isLink: Bool {
        let q = trimmedQuery.lowercased()
        return q.contains("music.apple.com") || q.hasPrefix("http://") || q.hasPrefix("https://")
    }

    private var canDownload: Bool {
        !appState.isSubmitting && isLink
    }

    private func handleSubmit() {
        guard !trimmedQuery.isEmpty else { return }
        if isLink {
            appState.submitUrlImport(url: trimmedQuery)
            query = ""
        } else {
            appState.performSearch(query: trimmedQuery, filter: selectedFilter)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Unified search / link-import field. Detects a pasted link and
                // turns into a Download action; otherwise searches live.
                HStack(spacing: Spacing.sm) {
                    Image(systemName: isLink ? "link" : "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(isLink ? Theme.accent : Theme.textTertiary)

                    TextField("Search or paste an Apple Music link", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.subheadline)
                        .submitLabel(isLink ? .go : .search)
                        .onSubmit(handleSubmit)

                    if appState.isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else if isLink {
                        Button(action: handleSubmit) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 7)
                            .background(canDownload ? Theme.accent : Theme.textTertiary.opacity(0.45), in: Capsule())
                        }
                        .disabled(!canDownload)
                    } else if !trimmedQuery.isEmpty {
                        Button {
                            query = ""
                            appState.performSearch(query: "", filter: selectedFilter)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .glassEffect(in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .background(Theme.background)

                // Filter — segmented picker (mirrors the Queue page)
                Picker("Filter", selection: $selectedFilter) {
                    Text("All").tag(CatalogType?.none)
                    ForEach(CatalogType.allCases) { type in
                        Text(type.displayName).tag(CatalogType?.some(type))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, Spacing.sm)
                .background(Theme.background)
                .onChange(of: selectedFilter) { _, newValue in
                    appState.performSearch(query: query, filter: newValue)
                }
                
                // Content area
                if appState.isSearching {
                    LoadingStateView(message: "Searching Apple Music Catalog...")
                } else if let errorMsg = appState.searchErrorMessage, displayedResults.isEmpty {
                    EmptyStateView(
                        iconName: "exclamationmark.triangle",
                        title: "Search Unavailable",
                        message: errorMsg,
                        actionTitle: "Retry",
                        action: {
                            appState.performSearch(query: query, filter: selectedFilter)
                        }
                    )
                } else if query.isEmpty && selectedFilter == nil {
                    EmptyStateView(
                        iconName: "magnifyingglass",
                        title: "Search or Paste a Link",
                        message: "Search for songs, albums, and playlists, or paste an Apple Music link to download it. Submissions land in Navidrome."
                    )
                } else if isLink {
                    EmptyStateView(
                        iconName: "arrow.down.circle",
                        title: "Ready to Download",
                        message: "Tap Download to import this link into your Navidrome library."
                    )
                } else if displayedResults.isEmpty {
                    EmptyStateView(
                        iconName: "music.note.slash",
                        title: "No Results Found",
                        message: "No catalog items matched '\(query)'. Check spelling or search by another keyword."
                    )
                } else {
                    List {
                        if let errorMsg = appState.searchErrorMessage {
                            Section {
                                ErrorBannerView(title: "Notice", message: errorMsg)
                            }
                        }
                        
                        ForEach(displayedResults) { item in
                            if item.type == .artist {
                                NavigationLink(destination: ArtistDetailView(artistId: item.id, artistName: item.title)) {
                                    SearchResultRow(item: item)
                                }
                            } else {
                                NavigationLink(destination: ItemDetailView(item: item)) {
                                    SearchResultRow(item: item)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .onChange(of: query) { _, newValue in
                // Live search: debounced per keystroke; clearing the field
                // clears results immediately (startSearch's empty branch).
                // Pasted links are not searched — they wait for Download.
                guard !isLink else { return }
                appState.performSearchDebounced(query: newValue, filter: selectedFilter)
            }
            .navigationTitle("Download")
        }
    }
}

private struct SearchResultRow: View {
    let item: CatalogItem
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            if let artworkUrl = item.artworkUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(Theme.accentGradient)
                        .overlay(Image(systemName: item.type.iconName).foregroundStyle(.white))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            } else {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Theme.accentGradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: item.type.iconName)
                            .foregroundStyle(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                
                Text(item.artistName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: Spacing.xs) {
                    Text(item.type.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    
                    if let date = item.releaseDate {
                        Text("• \(date)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            if item.type != .artist {
                Button {
                    appState.submitImport(item: item)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
