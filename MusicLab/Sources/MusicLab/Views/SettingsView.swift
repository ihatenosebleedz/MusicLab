import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingToken: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section: Backend Connection
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Backend URL (Tailscale or LAN)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        TextField("http://your-backend-host:3000", text: $appState.serverConfig.backendUrl)
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
                                    .tintedGlass(Theme.accent.opacity(0.85), in: Capsule())
                            }
                        }
                        .disabled(appState.isCheckingServer)
                    }
                    .padding(.vertical, 2)
                    
                } header: {
                    Text("Backend Server")
                } footer: {
                    Text("The backend orchestrates amdl and serves REST requests over your network connection.")
                }
                
                // Section: Download Destination
                Section {
                    if appState.destinations.isEmpty {
                        Text(appState.isServerOnline
                             ? "No destinations are configured on the server."
                             : "Connect to the backend to load destinations.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Picker("Save downloads to", selection: Binding(
                            get: { appState.selectedDestinationId },
                            set: { appState.setDestination($0) }
                        )) {
                            Text("Server default").tag(String?.none)
                            ForEach(appState.destinations) { destination in
                                Text(destination.isDefault ? "\(destination.id) (default)" : destination.id)
                                    .tag(String?.some(destination.id))
                            }
                        }
                    }
                } header: {
                    Text("Download Destination")
                } footer: {
                    Text("Choose which library on the server receives imports. \"Server default\" uses the server's configured destination.")
                }
                
                // Section: Navidrome Music Server
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Navidrome Server URL")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        TextField("https://your-navidrome-host:4533", text: $appState.serverConfig.navidromeUrl)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Navidrome Server")
                } footer: {
                    Text("Navidrome monitors your music folder. The app verifies that completed downloads are indexed in OpenSubsonic.")
                }
                
                // Section: Appearance (accent picker)
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(appState.accentOption.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.md) {
                                ForEach(AccentOption.allCases) { option in
                                    Button {
                                        appState.setAccent(option)
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(option.gradient)
                                            if appState.accentOption == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                                            }
                                        }
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle().strokeBorder(
                                                appState.accentOption == option
                                                    ? Theme.textPrimary
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(option.label)
                                    .accessibilityValue(appState.accentOption == option ? "Selected" : "")
                                }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Sets the accent used for buttons, highlights, and gradients across the app.")
                }

                // Section: Notifications
                Section {
                    Toggle("Completion Notifications", isOn: Binding(
                        get: { appState.notifyOnCompletion },
                        set: { appState.setNotifyOnCompletion($0) }
                    ))
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Sends an alert when an album, song, or playlist finishes downloading.")
                }

                // Section: System Architecture Info
                Section("Infrastructure Summary") {
                    LabeledContent("Downloader CLI", value: "amdl")
                    LabeledContent("Download Destination", value: appState.selectedDestinationLabel)
                    LabeledContent("Sidecar Files", value: "Cover Art + .lrc Lyrics")
                    LabeledContent("Verification Mode", value: "OpenSubsonic Polling")
                    LabeledContent("Network Mode", value: "LAN")
                }
                
                // Section: App Metadata
                Section {
                    HStack(spacing: Spacing.md) {
                        AppLogoView(size: 54)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Music Lab")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                    
                    LabeledContent("Toolchain", value: "xtool (Linux / Darwin SDK 27.1)")
                    
                    Button("Save Configuration") {
                        appState.saveConfig()
                    }
                    .foregroundStyle(Theme.accent)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
