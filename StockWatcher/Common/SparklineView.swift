import SwiftUI

/// A compact daily price sparkline — line + soft area fill with a dashed
/// baseline at the session open, like the Apple Stocks widget. Colored green
/// (up) or coral (down) from the day's net direction, with a soft glow. Shared
/// by the widget rows and the in-app watchlist so the two match.
struct MiniSparkline: View {
    let values: [Double]
    let up: Bool

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let range = max(hi - lo, 0.0001)
            let dx = size.width / CGFloat(values.count - 1)
            func point(_ i: Int) -> CGPoint {
                CGPoint(x: CGFloat(i) * dx,
                        y: size.height - CGFloat((values[i] - lo) / range) * size.height)
            }

            var line = Path()
            line.move(to: point(0))
            for i in 1..<values.count { line.addLine(to: point(i)) }

            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()

            let color = up ? Pantone.emerald : Pantone.livingCoral

            // Area fill (fades downward).
            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [color.opacity(0.32), color.opacity(0.02)]),
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)))

            // Dashed baseline at the session open.
            let baseY = size.height - CGFloat((values[0] - lo) / range) * size.height
            var base = Path()
            base.move(to: CGPoint(x: 0, y: baseY))
            base.addLine(to: CGPoint(x: size.width, y: baseY))
            ctx.stroke(base, with: .color(Pantone.ultimateGray.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))

            // Line, with a soft glow for depth.
            var glow = ctx
            glow.addFilter(.shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 1))
            glow.stroke(line, with: .color(color),
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
        }
    }
}
