import SwiftUI

public struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                SearchView()
                    .tabItem {
                        Label(AppTab.search.title, systemImage: AppTab.search.iconName)
                    }
                    .tag(AppTab.search)
                
                QueueView()
                    .tabItem {
                        Label(AppTab.queue.title, systemImage: AppTab.queue.iconName)
                    }
                    .badge(appState.activeJobsCount > 0 ? appState.activeJobsCount : 0)
                    .tag(AppTab.queue)
                
                LibraryView()
                    .tabItem {
                        Label(AppTab.library.title, systemImage: AppTab.library.iconName)
                    }
                    .tag(AppTab.library)
                
                SettingsView()
                    .tabItem {
                        Label(AppTab.settings.title, systemImage: AppTab.settings.iconName)
                    }
                    .tag(AppTab.settings)
            }
            .tint(Theme.accent)
            
            // Floating toast notification overlay
            if let toast = appState.importFeedbackToast {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: toastIcon)
                        .foregroundStyle(toastColor)
                    
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .cardSurface(cornerRadius: CornerRadius.pill)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $appState.artistPromptItem) { artist in
            NavigationStack {
                ArtistDetailView(artistId: artist.id, artistName: artist.name)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                appState.artistPromptItem = nil
                            }
                        }
                    }
            }
        }
        .sensoryFeedback(trigger: appState.importFeedbackToast) { _, newValue in
            guard newValue != nil else { return nil }
            switch appState.importFeedbackKind {
            case .success: return .success
            case .error: return .error
            case .info: return .impact(weight: .light)
            }
        }
    }

    private var toastIcon: String {
        switch appState.importFeedbackKind {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var toastColor: Color {
        switch appState.importFeedbackKind {
        case .success: return Theme.success
        case .error: return Theme.error
        case .info: return Theme.info
        }
    }
}
