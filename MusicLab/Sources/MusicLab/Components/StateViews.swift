import SwiftUI

public struct EmptyStateView: View {
    public let iconName: String
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (() -> Void)?
    
    public init(
        iconName: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, Spacing.xs)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .foregroundStyle(.white)
                        .tintedGlass(Theme.accent.opacity(0.85), in: Capsule())
                }
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct LoadingStateView: View {
    public let message: String
    
    public init(message: String = "Loading...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Theme.accent)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ErrorBannerView: View {
    public let title: String
    public let message: String
    public let retryAction: (() -> Void)?
    
    public init(
        title: String = "Connection Error",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.error)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer()
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Retry")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .tintedGlass(Theme.error.opacity(0.3), in: Capsule())
                }
            }
        }
        .padding(Spacing.md)
        .tintedGlass(Theme.error.opacity(0.4), in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }
}

public struct BackendUnavailableCard: View {
    public let serverUrl: String
    public let onSettingsTapped: () -> Void
    
    public init(serverUrl: String, onSettingsTapped: @escaping () -> Void) {
        self.serverUrl = serverUrl
        self.onSettingsTapped = onSettingsTapped
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "server.rack")
                    .foregroundStyle(Theme.warning)
                
                Text("Backend Host Offline")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                
                Spacer()
                
                Text("Offline")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.warning)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .tintedGlass(Theme.warning.opacity(0.4), in: Capsule())
            }
            
            Text("Cannot reach Gentoo downloader backend at \(serverUrl). Check Tailscale connectivity or verify settings.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            
            Button(action: onSettingsTapped) {
                HStack(spacing: Spacing.xs) {
                    Text("Configure Connection")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .tintedGlass(Theme.warning.opacity(0.4), in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }
}
