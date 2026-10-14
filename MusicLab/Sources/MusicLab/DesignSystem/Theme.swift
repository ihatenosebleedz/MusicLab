import SwiftUI

public enum Theme {
    // Primary Apple Music aesthetic accents
    public static let accent = Color(red: 0.98, green: 0.16, blue: 0.28) // Apple Music vibrant red/rose
    public static let accentGradient = LinearGradient(
        colors: [Color(red: 0.98, green: 0.16, blue: 0.28), Color(red: 0.85, green: 0.10, blue: 0.45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Status colors
    public static let success = Color.green
    public static let warning = Color.orange
    public static let error = Color.red
    public static let info = Color.blue
    public static let queued = Color.purple
    
    // Backgrounds & surfaces
    public static let background = Color(uiColor: .systemGroupedBackground)
    public static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    public static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    
    // Text colors
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color(uiColor: .tertiaryLabel)
}

public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum CornerRadius {
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let pill: CGFloat = 999
}
