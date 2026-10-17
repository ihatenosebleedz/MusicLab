import SwiftUI

/// First-run setup. Collects backend + Navidrome connection details and only
/// advances once the backend is verified reachable.
public struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingToken: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header
                VStack(spacing: Spacing.md) {
                    AppLogoView(size: 84)
                    
                    Text("Welcome to Music Lab")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text("Connect to your backend to search Apple Music and import into Navidrome.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }
                .padding(.top, Spacing.xl)
                
                // Connection fields
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    field(label: "Backend URL (Tailscale or LAN)") {
                        TextField("http://your-backend-host:3001", text: $appState.serverConfig.backendUrl)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("API Bearer Token")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Button {
                                isShowingToken.toggle()
                            } label: {
                                Image(systemName: isShowingToken ? "eye.slash" : "eye")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        
                        if isShowingToken {
                            TextField("Enter 32+ character bearer token", text: $appState.serverConfig.bearerToken)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Enter 32+ character bearer token", text: $appState.serverConfig.bearerToken)
                        }
                    }
                    
                    field(label: "Navidrome URL (optional)") {
                        TextField("https://your-navidrome-host:4533", text: $appState.serverConfig.navidromeUrl)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    
                    // Status
                    HStack(spacing: Spacing.sm) {
                        if appState.isCheckingServer {
                            ProgressView().tint(Theme.info)
                            Text("Checking connection…")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.info)
                        } else if appState.isServerOnline {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                            Text(appState.serverStatusMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.success)
                        } else {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Theme.textSecondary)
                            Text(appState.serverStatusMessage)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
                .padding(Spacing.lg)
                .cardSurface(cornerRadius: CornerRadius.lg)
                .padding(.horizontal, Spacing.lg)
                
                // Actions
                VStack(spacing: Spacing.sm) {
                    Button {
                        appState.testAndCompleteOnboarding()
                    } label: {
                        Text(appState.isCheckingServer ? "Testing…" : "Test & Continue")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .tintedGlass(Theme.accent.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                    }
                    .disabled(appState.isCheckingServer || appState.serverConfig.backendUrl.isEmpty || appState.serverConfig.bearerToken.isEmpty)
                    .opacity(appState.serverConfig.backendUrl.isEmpty || appState.serverConfig.bearerToken.isEmpty ? 0.5 : 1)
                    
                    Button {
                        appState.skipOnboarding()
                    } label: {
                        Text("Set up later in Settings")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
    
    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}
