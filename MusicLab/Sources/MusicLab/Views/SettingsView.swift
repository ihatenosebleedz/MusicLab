import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingToken: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section: Gentoo Backend Connection
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Backend URL (Tailscale or LAN)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        TextField("http://gentoo.tail29a9cb.ts.net:3000", text: $appState.serverConfig.backendUrl)
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
                    
                    // Connection Status & Test Button
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status:")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Text(appState.serverStatusMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appState.isServerOnline ? Theme.success : Theme.warning)
                        }
                        
                        Spacer()
                        
                        Button {
                            appState.testServerConnection()
                        } label: {
                            if appState.isCheckingServer {
                                ProgressView()
                                    .tint(Theme.accent)
                            } else {
                                Text("Test Connection")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(Theme.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        .disabled(appState.isCheckingServer)
                    }
                    .padding(.vertical, 2)
                    
                } header: {
                    Text("Backend Server")
                } footer: {
                    Text("The backend runs on your Gentoo host (nbz), orchestrates amdl, and serves REST requests over Tailscale or LAN.")
                }
                
                // Section: Navidrome Music Server
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Navidrome Server URL")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        TextField("https://gentoo.tail29a9cb.ts.net:4533", text: $appState.serverConfig.navidromeUrl)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Navidrome Server")
                } footer: {
                    Text("Navidrome 0.64.2 monitors /mnt/media/Music. The app verifies that completed downloads are indexed in OpenSubsonic.")
                }
                
                // Section: System Architecture Info
                Section("Infrastructure Summary") {
                    LabeledContent("Downloader CLI", value: "amdl (Gentoo)")
                    LabeledContent("Download Destination", value: "/mnt/media/Music")
                    LabeledContent("Sidecar Files", value: "Cover Art + .lrc Lyrics")
                    LabeledContent("Verification Mode", value: "OpenSubsonic Polling")
                    LabeledContent("Network Mode", value: "Tailscale + LAN (0.0.0.0)")
                }
                
                // Section: App Metadata
                Section("About") {
                    LabeledContent("App Name", value: "Music Lab")
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Toolchain", value: "xtool (Linux / Darwin SDK 27.1)")
                    
                    Button("Save Configuration") {
                        appState.saveConfig()
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
