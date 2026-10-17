import SwiftUI

/// A shimmering placeholder block used to indicate loading content.
public struct SkeletonView: View {
    public var cornerRadius: CGFloat
    @State private var phase: CGFloat = -1

    public init(cornerRadius: CGFloat = CornerRadius.sm) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55)
                    .offset(x: phase * geo.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
            .accessibilityHidden(true)
    }
}

/// Placeholder shaped like a queue job row.
public struct SkeletonJobRow: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                SkeletonView(cornerRadius: 4)
                    .frame(width: 168, height: 14)
                Spacer()
                SkeletonView(cornerRadius: 11)
                    .frame(width: 78, height: 22)
            }
            SkeletonView(cornerRadius: 3)
                .frame(height: 8)
                .padding(.top, 2)
            SkeletonView(cornerRadius: 3)
                .frame(width: 132, height: 8)
        }
        .padding(.vertical, Spacing.sm)
    }
}

/// Placeholder shaped like an artwork + two-line list row.
public struct SkeletonMediaRow: View {
    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.md) {
            SkeletonView(cornerRadius: CornerRadius.sm)
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonView(cornerRadius: 4).frame(width: 150, height: 13)
                SkeletonView(cornerRadius: 3).frame(width: 92, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}
