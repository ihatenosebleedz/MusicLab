import SwiftUI

public struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedFilter: CatalogType? = nil
    
    public init() {}
    
    private var filteredResults: [CatalogItem] {
        let allItems = MockData.sampleAlbums + MockData.sampleSongs
        var results = allItems
        
        if let filter = selectedFilter {
            results = results.filter { $0.type == filter }
        }
        
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query) ||
                $0.artistName.lowercased().contains(query)
            }
        }
        
        return results
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedFilter == nil
                        ) {
                            selectedFilter = nil
                        }
                        
                        ForEach(CatalogType.allCases) { type in
                            FilterChip(
                                title: type.displayName,
                                isSelected: selectedFilter == type
                            ) {
                                selectedFilter = type
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Spacing.sm)
                }
                .background(Theme.background)
                
                // Content area
                if searchText.isEmpty && selectedFilter == nil {
                    EmptyStateView(
                        iconName: "magnifyingglass",
                        title: "Search Apple Music",
                        message: "Search for songs, albums, and artists. Submissions will be downloaded to Navidrome."
                    )
                } else if filteredResults.isEmpty {
                    EmptyStateView(
                        iconName: "music.note.slash",
                        title: "No Results Found",
                        message: "No catalog items matched '\(searchText)'. Check spelling or search by another keyword."
                    )
                } else {
                    List {
                        ForEach(filteredResults) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                HStack(spacing: Spacing.md) {
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .fill(Theme.accentGradient)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: item.type.iconName)
                                                .foregroundStyle(.white)
                                        )
                                    
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
                                    
                                    Button {
                                        appState.submitImport(item: item)
                                    } label: {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.title2)
                                            .foregroundStyle(Theme.accent)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Search Apple Music")
            .navigationTitle("Search")
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                .background(isSelected ? Theme.accent : Color(uiColor: .tertiarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
