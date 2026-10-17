import SwiftUI

/// A user-selectable accent theme. Each case supplies both the single-color accent
/// (used by `.tint()` / icon-like controls) and the gradient used by `.fill()`.
public enum AccentOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case musicRed
    case pride
    case blue
    case green
    case purple
    case orange
    case indigo

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .musicRed: return "Music Red"
        case .pride:    return "Pride"
        case .blue:     return "Blue"
        case .green:    return "Green"
        case .purple:   return "Purple"
        case .orange:   return "Orange"
        case .indigo:   return "Indigo"
        }
    }

    public var color: Color {
        switch self {
        case .musicRed: return Color(red: 0.980, green: 0.160, blue: 0.280)  // Apple Music red
        case .pride:    return Color(red: 0.894, green: 0.012, blue: 0.012)  // #E40303
        case .blue:     return Color(red: 0.000, green: 0.478, blue: 1.000)  // #007AFF
        case .green:    return Color(red: 0.204, green: 0.780, blue: 0.349)  // #34C759
        case .purple:   return Color(red: 0.686, green: 0.322, blue: 0.871)  // #AF52DE
        case .orange:   return Color(red: 1.000, green: 0.584, blue: 0.000)  // #FF9500
        case .indigo:   return Color(red: 0.345, green: 0.337, blue: 0.839)  // #5856D6
        }
    }

    public var gradient: LinearGradient {
        switch self {
        case .musicRed:
            return LinearGradient(
                colors: [Color(red: 0.980, green: 0.160, blue: 0.280),
                         Color(red: 0.850, green: 0.100, blue: 0.450)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pride:
            return LinearGradient(
                colors: [Color(red: 0.894, green: 0.012, blue: 0.012),  // #E40303
                         Color(red: 1.000, green: 0.549, blue: 0.000),  // #FF8C00
                         Color(red: 1.000, green: 0.929, blue: 0.000),  // #FFED00
                         Color(red: 0.000, green: 0.502, blue: 0.149),  // #008026
                         Color(red: 0.141, green: 0.251, blue: 0.557),  // #24408E
                         Color(red: 0.451, green: 0.161, blue: 0.510)], // #732982
                startPoint: .top, endPoint: .bottom)
        case .blue:
            return LinearGradient(
                colors: [Color(red: 0.000, green: 0.478, blue: 1.000),
                         Color(red: 0.039, green: 0.518, blue: 1.000)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green:
            return LinearGradient(
                colors: [Color(red: 0.204, green: 0.780, blue: 0.349),
                         Color(red: 0.000, green: 0.780, blue: 0.753)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple:
            return LinearGradient(
                colors: [Color(red: 0.686, green: 0.322, blue: 0.871),
                         Color(red: 0.369, green: 0.361, blue: 0.902)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orange:
            return LinearGradient(
                colors: [Color(red: 1.000, green: 0.584, blue: 0.000),
                         Color(red: 1.000, green: 0.420, blue: 0.000)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigo:
            return LinearGradient(
                colors: [Color(red: 0.345, green: 0.337, blue: 0.839),
                         Color(red: 0.369, green: 0.361, blue: 0.902)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

public enum Theme {
    /// Currently selected accent. Written on the main actor from `AppState.setAccent`
    /// and only ever read on the main actor (view bodies / `JobState.color`).
    /// Marked `nonisolated(unsafe)` because Swift cannot verify that constraint statically.
    nonisolated(unsafe) public static var currentAccent: AccentOption = .musicRed

    public static var accent: Color { currentAccent.color }
    public static var accentGradient: LinearGradient { currentAccent.gradient }
    
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
    /// Hairline used on clean card surfaces.
    public static let cardBorder = Color.primary.opacity(0.07)

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

// MARK: - Surface & tint modifiers

/// A clean, flat card surface: subtle fill + hairline border. Used instead of
/// glass on content surfaces so the accent colour stays the focal point.
public struct CardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 0.5)
            )
    }
}

/// Applies a tinted surface background (badges, chips, buttons).
public struct TintedSurfaceModifier<S: Shape>: ViewModifier {
    var tint: Color
    var shape: S

    public init(tint: Color, shape: S) {
        self.tint = tint
        self.shape = shape
    }

    public func body(content: Content) -> some View {
        content.background(tint, in: shape)
    }
}

public extension View {
    /// Clean flat card background (replaces the old glass card).
    func cardSurface(cornerRadius: CGFloat = CornerRadius.md) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Applies a color-tinted, flat background (badges / chips / buttons).
    func tintedGlass(_ tint: Color, in shape: some Shape) -> some View {
        modifier(TintedSurfaceModifier(tint: tint, shape: shape))
    }
}
