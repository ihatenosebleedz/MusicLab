import SwiftUI

public struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                DiscoverView()
                    .tabItem {
                        Label(AppTab.discover.title, systemImage: AppTab.discover.iconName)
                    }
                    .tag(AppTab.discover)
                
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
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                    
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .shadow(radius: 8)
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
