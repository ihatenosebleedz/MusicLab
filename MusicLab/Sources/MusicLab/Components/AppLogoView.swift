import SwiftUI

/// The MusicLab mark ("Drop Note"): a stem-down quarter note where the stem is
/// the arrow shaft and a chevron closes it off. Drawn in a 1024pt design space
/// so it matches the generated app icon exactly.
public struct MusicDownloadMark: View {
    public var color: Color
    public var scale: CGFloat

    public init(color: Color = .white, scale: CGFloat = 1.0) {
        self.color = color
        self.scale = scale
    }

    public var body: some View {
        Canvas { ctx, size in
            let unit = min(size.width, size.height) / 1024
            let cx = size.width / 2
            let cy = size.height / 2

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(
                    x: cx + (x - 512) * unit * scale,
                    y: cy + (y - 512) * unit * scale
                )
            }

            func stroke(_ path: Path, _ width: CGFloat) {
                ctx.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: width * unit * scale, lineCap: .round, lineJoin: .round)
                )
            }

            // Note head (outlined circle), tangent to the stem on its left.
            let headCenter = p(612, 367)
            let headRadius = 150 * unit * scale
            let head = Path(ellipseIn: CGRect(
                x: headCenter.x - headRadius,
                y: headCenter.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))
            stroke(head, 64)

            // Stem — doubles as the arrow shaft.
            var stem = Path()
            stem.move(to: p(462, 367))
            stem.addLine(to: p(462, 807))
            stroke(stem, 64)

            // Arrowhead chevron.
            var arrow = Path()
            arrow.move(to: p(262, 607))
            arrow.addLine(to: p(462, 807))
            arrow.addLine(to: p(662, 607))
            stroke(arrow, 64)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The app logo badge: the mark on the accent gradient, used in Settings and
/// onboarding.
public struct AppLogoView: View {
    public var size: CGFloat

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
            .fill(Theme.accentGradient)
            .overlay {
                MusicDownloadMark(color: .white)
            }
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: size * 0.06, y: size * 0.03)
            .frame(width: size, height: size)
    }
}
