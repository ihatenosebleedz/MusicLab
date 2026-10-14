import SwiftUI
import MusicLabCore

public struct ItemDetailView: View {
    public let item: CatalogItem
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    public init(item: CatalogItem) {
        self.item = item
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Artwork & Header
                HStack(alignment: .top, spacing: Spacing.lg) {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Theme.accentGradient)
                        .frame(width: 130, height: 130)
                        .overlay(
                            Image(systemName: item.type.iconName)
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(item.type.displayName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        
                        Text(item.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        
                        Text(item.artistName)
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                        
                        if let genre = item.genre {
                            Text(genre)
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        
                        if let releaseDate = item.releaseDate {
                            Text("Released \(releaseDate)")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Primary Action Button
                Button {
                    appState.submitImport(item: item)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.headline)
                        Text("Import to Navidrome")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .foregroundStyle(.white)
                    .background(Theme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 3)
                }
                .padding(.horizontal)
                
                // Track list (if album or playlist)
                if !item.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Tracks (\(item.tracks.count))")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(item.tracks) { track in
                                HStack(spacing: Spacing.md) {
                                    Text("\(track.trackNumber)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.textSecondary)
                                        .frame(width: 24, alignment: .trailing)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: Spacing.xs) {
                                            Text(track.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(1)
                                            
                                            if track.isExplicit {
                                                Text("E")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.secondary)
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                        }
                                        
                                        Text(track.artistName)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(track.formattedDuration)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, Spacing.sm)
                                
                                if track.id != item.tracks.last?.id {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .padding(.horizontal)
                    }
                }
                
                // URL info footer
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Apple Music Reference")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    
                    Text(item.appleMusicUrl)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
