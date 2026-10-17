import SwiftUI

@main
struct MusicLabApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(appState)
            .tint(appState.accentOption.color)
            // Re-key the tree when the accent changes so `Theme.accent`
            // (a static read) is re-evaluated in every descendant view.
            .id(appState.accentOption.id)
            .onOpenURL { url in
                appState.handleIncomingURL(url)
            }
        }
    }
}
